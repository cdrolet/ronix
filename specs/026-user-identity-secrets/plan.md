# Implementation Plan: User Identity Secrets

**Branch**: `026-user-identity-secrets` | **Date**: 2025-12-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/026-user-identity-secrets/spec.md`

## Summary

Implement the "mirror-path secret pattern" where `"<secret>"` placeholders in user configs auto-resolve to encrypted values from path-mirrored secret files. Uses freeform user schema for extensibility and keeps all secrets user-specific.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled
**Primary Dependencies**: agenix (Home Manager module), Home Manager, nix-darwin/NixOS
**Storage**: Age-encrypted JSON files at `secrets/user/{username}/default.age`
**Testing**: `nix flake check`, manual verification of git config after activation
**Target Platform**: Darwin (macOS), NixOS (Linux) - cross-platform
**Project Type**: Nix configuration repository
**Performance Goals**: Secrets decrypted within seconds during activation
**Constraints**: Age private keys must be present on deployment machines
**Scale/Scope**: 3 users, arbitrary number of secret fields per user

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration First | ✅ PASS | agenix is declarative secret management |
| II. Modularity and Reusability | ✅ PASS | Mirror-path pattern is consistent and reusable |
| III. Documentation-Driven Development | ✅ PASS | Quickstart guide provides complete documentation |
| IV. Purity and Reproducibility | ✅ PASS | Encrypted files are pure, decryption deterministic |
| V. Testing and Validation | ✅ PASS | `nix flake check` validates configuration |
| VI. Cross-Platform Compatibility | ✅ PASS | agenix works on Darwin and NixOS |
| App-Centric Organization | ✅ PASS | Apps reference `config.user.*`, no secrets in apps |
| Module Size < 200 lines | ✅ PASS | Small additions to existing modules |
| Secrets in secrets/ | ✅ PASS | Using `secrets/user/{username}/default.age` |
| secrets.nix as Single Source | ✅ PASS | Key mappings in `secrets/secrets.nix` |

**Gate Result**: ✅ PASS - No violations, proceed to implementation

## Project Structure

### Documentation (this feature)

```text
specs/026-user-identity-secrets/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Design decisions and patterns
├── data-model.md        # Entity definitions and relationships
├── quickstart.md        # User-facing guide
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Implementation tasks (from /speckit.tasks)
```

### Source Code (repository root)

```text
# Files to modify
flake.nix                              # Add agenix input
justfile                               # Add secrets-* commands
secrets/secrets.nix                    # Update with real age public keys
user/shared/lib/home-manager.nix       # Add freeformType to user options
system/darwin/lib/darwin.nix           # Add agenix module, secret resolution
system/nixos/lib/nixos.nix             # Add agenix module, secret resolution
system/shared/lib/secrets.nix          # NEW: Secret resolution helpers
system/shared/app/security/age.nix     # NEW: Optional age+agenix CLI tools

# Files to create
secrets/user/cdrokar/default.age       # Encrypted user secrets
secrets/user/cdrolet/default.age       # Encrypted user secrets
secrets/user/cdrixus/default.age       # Encrypted user secrets
docs/features/026-user-identity-secrets.md  # User documentation

# Files to update (remove plain text secrets)
user/cdrokar/default.nix               # email, fullName → "<secret>"
user/cdrolet/default.nix               # email, fullName → "<secret>"
user/cdrixus/default.nix               # email, fullName → "<secret>"
```

## Key Implementation Details

### 1. Freeform User Schema

```nix
# user/shared/lib/home-manager.nix
options.user = lib.mkOption {
  type = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      name = lib.mkOption { type = lib.types.str; };
      email = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      fullName = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      # ... other documented fields
    };
  };
};
```

### 2. Secret Resolution Helper

```nix
# system/shared/lib/secrets.nix
{
  # Check if value is a secret placeholder
  isSecret = value: value == "<secret>";
  
  # Derive secret path from user name
  getUserSecretPath = username: ../../../secrets/user/${username}/default.age;
  
  # Check if user has any secrets
  userHasSecrets = userConfig:
    lib.any isSecret (lib.collect lib.isString userConfig);
}
```

### 3. Agenix Integration in Platform Libs

```nix
# In darwin.nix / nixos.nix
imports = [
  inputs.agenix.homeManagerModules.default
];

age.identityPaths = [
  "${config.home.homeDirectory}/.config/agenix/key.txt"
];

age.secrets.userIdentity = lib.mkIf hasSecrets {
  file = secretsLib.getUserSecretPath username;
};
```

### 4. Activation Script for Secret Application

```nix
home.activation.applySecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
  if [ -f "${config.age.secrets.userIdentity.path}" ]; then
    # Read and apply secret values
    secrets=$(cat "${config.age.secrets.userIdentity.path}")
    
    # Apply to git if email/fullName are secrets
    if [ "${toString (config.user.email == "<secret>")}" = "1" ]; then
      email=$(echo "$secrets" | ${pkgs.jq}/bin/jq -r '.email')
      ${pkgs.git}/bin/git config --global user.email "$email"
    fi
    # ... similar for other fields
  fi
'';
```

## Justfile Commands

New secret management commands to add:

```just
# ============================================================================
# SECRET MANAGEMENT
# ============================================================================

# Initialize age key for secret encryption (one-time per machine)
secrets-init:
    #!/usr/bin/env bash
    key_path="$HOME/.config/agenix/key.txt"
    if [ -f "$key_path" ]; then
        echo "Age key already exists at $key_path"
        echo "Public key:"
        nix shell nixpkgs#age -c age-keygen -y "$key_path"
    else
        echo "Generating new age key..."
        mkdir -p "$(dirname "$key_path")"
        nix shell nixpkgs#age -c age-keygen -o "$key_path"
        echo ""
        echo "Key generated! Add the public key above to secrets/secrets.nix"
    fi

# Show public key for adding to secrets.nix
secrets-show-pubkey:
    #!/usr/bin/env bash
    key_path="$HOME/.config/agenix/key.txt"
    if [ -f "$key_path" ]; then
        nix shell nixpkgs#age -c age-keygen -y "$key_path"
    else
        echo "Error: No age key found at $key_path"
        echo "Run 'just secrets-init' first"
        exit 1
    fi

# Edit a user's secret file (auto-rekeys after editing)
secrets-edit user:
    @just _validate-user {{user}}
    @echo "Editing secrets for {{user}}..."
    @nix shell nixpkgs#agenix -c agenix -e secrets/user/{{user}}/default.age
    @echo "Re-encrypting all secrets..."
    @nix shell nixpkgs#agenix -c agenix -r
    @echo "Done!"

# Re-encrypt all secrets (after adding new keys to secrets.nix)
secrets-rekey:
    @echo "Re-encrypting all secrets..."
    @nix shell nixpkgs#agenix -c agenix -r
    @echo "Done!"

# List all secret files and their encryption status
secrets-list:
    #!/usr/bin/env bash
    echo "Secret files:"
    echo "============="
    for user_dir in user/*/; do
        user=$(basename "$user_dir")
        if [ "$user" = "shared" ]; then continue; fi
        secret_path="secrets/user/$user/default.age"
        if [ -f "$secret_path" ]; then
            echo "  ✓ $secret_path"
        else
            echo "  ✗ $secret_path (not created)"
        fi
    done
```

## Complexity Tracking

> No constitution violations - table not needed.
