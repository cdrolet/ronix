# Research: User Identity Secrets

**Feature**: 026-user-identity-secrets
**Date**: 2025-12-21
**Status**: Complete

## Executive Summary

This research documents the "mirror-path secret pattern" - a user-friendly approach where `"<secret>"` placeholders auto-resolve to encrypted values from path-mirrored secret files. Secrets are user-specific; apps reference `config.user.*` and never contain secrets directly.

______________________________________________________________________

## Core Design Decisions

### Decision 1: `"<secret>"` Placeholder Pattern

**Approach**: Use a simple string sentinel that triggers secret resolution.

```nix
# user/cdrokar/default.nix
user = {
  name = "cdrokar";
  email = "<secret>";           # Resolved from secrets/user/cdrokar/default.age
  fullName = "<secret>";        # Same file, different field
  tokens.github = "<secret>";   # Nested paths work too
  timezone = "America/Toronto"; # Plain text - no secret needed
};
```

**Rationale**:

- Zero configuration - no imports, no options, no paths
- Intuitive - the placeholder is self-documenting
- Flexible - works for any field at any nesting level

**Alternatives Rejected**:

- `lib.secret "email"` - Requires importing helpers
- `{ _secret = true; field = "email"; }` - Verbose, not user-friendly
- Separate `user.secrets.email` namespace - Duplicates structure

### Decision 2: Mirror-Path Secret Files

**Approach**: Secret file paths mirror source file paths exactly.

```
user/cdrokar/default.nix    →  secrets/user/cdrokar/default.age
user/cdrolet/default.nix    →  secrets/user/cdrolet/default.age
```

**Rationale**:

- Predictable - no configuration needed
- Discoverable - path is obvious from source location
- Consistent - same pattern everywhere

**Implementation**:

```nix
# Derive secret path from source path
getSecretPath = sourcePath:
  let
    # user/cdrokar/default.nix → secrets/user/cdrokar/default.age
    relative = lib.removePrefix (toString ./.) (toString sourcePath);
    withoutExt = lib.removeSuffix ".nix" relative;
  in
    ./secrets + withoutExt + ".age";
```

### Decision 3: Secrets Are User-Specific Only

**Approach**: All secrets live in user configs. Apps reference `config.user.*`.

```nix
# system/shared/app/dev/git.nix - NO secrets here
programs.git = {
  userName = config.user.fullName;      # From user config
  userEmail = config.user.email;        # From user config (may be secret)
  signing.key = config.user.git.signingKey;  # From user config
};

# user/cdrokar/default.nix - Secrets here
user = {
  email = "<secret>";
  fullName = "<secret>";
  git.signingKey = "<secret>";
};
```

**Rationale**:

- Secrets are personal - they belong to users, not apps
- Apps are shared - same git.nix for all users
- Single location - all secrets in `secrets/user/{username}/default.age`
- Simpler mental model - "my secrets are in my user directory"

**Why No System Secrets?**

| Supposed System Secret | Actually Belongs To |
|------------------------|---------------------|
| Git signing key | User (personal key) |
| API tokens | User (personal credentials) |
| VPN config | User (personal access) |
| SSH keys | User (personal identity) |

### Decision 4: Freeform User Schema

**Approach**: Use `freeformType` to allow arbitrary user fields without schema changes.

```nix
# user/shared/lib/home-manager.nix
options.user = lib.mkOption {
  type = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    
    options = {
      # Required field
      name = lib.mkOption { type = lib.types.str; };
      
      # Documented optional fields
      email = lib.mkOption { 
        type = lib.types.nullOr lib.types.str; 
        default = null; 
      };
      fullName = lib.mkOption { 
        type = lib.types.nullOr lib.types.str; 
        default = null; 
      };
      # ... other documented fields
      
      # Everything else: freeform (git.*, tokens.*, etc.)
    };
  };
};
```

**Rationale**:

- Extensible - add any field without touching schema
- Documented - core fields still have proper types and descriptions
- Flexible - nested paths work naturally

**Trade-offs**:

- No typo protection for freeform fields
- Undocumented fields don't appear in `man home-configuration.nix`

### Decision 5: Auto-Discovery of User Secret Paths

**Approach**: Derive expected secret paths from user directory structure.

```nix
# Auto-discover users and their secret paths
discoverUserSecretPaths = let
  userDir = ../user;
  entries = builtins.readDir userDir;
  users = lib.filterAttrs (n: v: v == "directory" && n != "shared") entries;
in
  lib.mapAttrs (name: _: {
    secretPath = ../secrets/user/${name}/default.age;
    exists = builtins.pathExists ../secrets/user/${name}/default.age;
  }) users;
```

**Rationale**:

- Zero manual registration
- New user directories automatically establish expected secret paths
- Can warn about missing secret files without failing

______________________________________________________________________

## Secret File Format

### JSON Structure

```json
{
  "email": "cdrokar@pm.me",
  "fullName": "Charles Drokar",
  "git": {
    "signingKey": "ABC123..."
  },
  "tokens": {
    "github": "ghp_...",
    "openai": "sk-..."
  }
}
```

**Field Name Matching**:

- JSON keys must match Nix attribute paths
- `user.email = "<secret>"` → looks for `email` key
- `user.tokens.github = "<secret>"` → looks for `tokens.github` path

### Reading Nested Values

```nix
# Helper to extract nested value from JSON
getNestedValue = json: path:
  let
    parts = lib.splitString "." path;
  in
    lib.foldl' (acc: key: acc.${key}) json parts;

# Usage
secrets = builtins.fromJSON (builtins.readFile decryptedPath);
githubToken = getNestedValue secrets "tokens.github";
```

______________________________________________________________________

## Implementation Architecture

### Secret Resolution Flow

```
1. User Config Evaluation
   └── Detect fields with value "<secret>"
   
2. Path Derivation
   └── user/cdrokar/default.nix → secrets/user/cdrokar/default.age
   
3. Secret Registration
   └── Register with age.secrets for decryption
   
4. Activation Time
   └── agenix decrypts to /run/agenix/ or user path
   
5. Value Resolution
   └── Read JSON, extract field value, apply to config
```

### Challenge: Evaluation vs Activation Time

Nix evaluates at build time, but secrets decrypt at activation time.

**Solution Options**:

1. **Activation Script Approach**:

   ```nix
   home.activation.applySecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
     if [ -f "${config.age.secrets.userIdentity.path}" ]; then
       email=$(${pkgs.jq}/bin/jq -r '.email' "${config.age.secrets.userIdentity.path}")
       ${pkgs.git}/bin/git config --global user.email "$email"
     fi
   '';
   ```

1. **Template File Approach**:

   ```nix
   # Generate config files that read from secret path at runtime
   home.file.".gitconfig".text = ''
     [user]
     email = $(cat ${config.age.secrets.userIdentity.path} | jq -r .email)
   '';
   ```

1. **Environment Variable Approach**:

   ```nix
   # Set env vars from secrets
   home.sessionVariables = {
     GIT_AUTHOR_EMAIL = "$(jq -r .email ${config.age.secrets.userIdentity.path})";
   };
   ```

**Recommended**: Activation script approach for most cases - it's explicit and debuggable.

______________________________________________________________________

## Agenix Integration

### Flake Input

```nix
inputs = {
  agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### Home Manager Module

```nix
# In platform lib
imports = [
  inputs.agenix.homeManagerModules.default
];

# Secret configuration
age.identityPaths = [
  "${config.home.homeDirectory}/.config/agenix/key.txt"
];

age.secrets.userIdentity = lib.mkIf hasSecrets {
  file = secretPath;
};
```

### secrets.nix Configuration

```nix
let
  cdrokar = "age1...";  # Public key
  cdrolet = "age1...";
  cdrixus = "age1...";
in {
  "user/cdrokar/default.age".publicKeys = [ cdrokar ];
  "user/cdrolet/default.age".publicKeys = [ cdrolet ];
  "user/cdrixus/default.age".publicKeys = [ cdrixus ];
}
```

______________________________________________________________________

## Error Handling

### Missing Secret File

```nix
# When "<secret>" is used but file doesn't exist
throw ''
  Secret file not found: secrets/user/cdrokar/default.age
  
  You used "<secret>" for field 'email' but the secret file doesn't exist.
  
  To create it:
    1. Generate age key: age-keygen -o ~/.config/agenix/key.txt
    2. Add public key to secrets/secrets.nix
    3. Create secret: agenix -e secrets/user/cdrokar/default.age
''
```

### Missing Field in Secret

```nix
# When secret file exists but doesn't contain the field
throw ''
  Secret field not found: 'tokens.github' in secrets/user/cdrokar/default.age
  
  Your secret file must contain this JSON structure:
    {
      "tokens": {
        "github": "your-token-here"
      }
    }
''
```

______________________________________________________________________

## Sources

- [ryantm/agenix](https://github.com/ryantm/agenix) - Official repository
- [Using Agenix with Home Manager](https://www.mitchellhanberg.com/using-agenix-with-home-manager/)
- [Nix freeformType documentation](https://nixos.org/manual/nixos/stable/#sec-freeform-modules)
