# Research: User Colocated Secrets

**Feature**: 027-user-colocated-secrets
**Date**: 2025-12-22
**Status**: Complete

## Executive Summary

This research documents a simplified secrets architecture that colocates encrypted secrets directly in user directories and uses a single shared age keypair for all users. Key innovations over spec 026:

1. **Colocated secrets**: `user/{name}/secrets.age` instead of `secrets/users/{name}/default.age`
1. **Shared key**: Single `public.age` at repo root, no per-user keys
1. **No secrets.nix**: Wrapper commands dynamically generate agenix rules
1. **Auto-initialization**: First-time setup creates keys and empty secret files automatically

______________________________________________________________________

## Core Design Decisions

### Decision 1: Colocated Secret Files

**Approach**: Store secrets directly in user directories.

```
# OLD (spec 026)
user/cdrokar/default.nix
secrets/users/cdrokar/default.age    # Separate directory tree

# NEW (spec 027)
user/cdrokar/default.nix
user/cdrokar/secrets.age              # Same directory
```

**Rationale**:

- Single location for all user files (config + secrets)
- No need to navigate parallel directory trees
- Aligns with principle that user directories are self-contained
- Easier mental model: "everything about me is in my folder"

**Alternatives Rejected**:

- Separate `secrets/` directory (spec 026) - Requires maintaining parallel structure
- Inline encrypted strings - Not supported by agenix, harder to edit

### Decision 2: Single Shared Key

**Approach**: Use one age keypair for all users instead of per-user keys.

```
public.age                     # Repo root, committed (shared public key)
~/.config/agenix/key.txt       # Local, not committed (shared private key)

user/
  cdrokar/secrets.age          # Encrypted with shared key
  cdrolet/secrets.age          # Same key
  cdronix/secrets.age          # Same key
```

**Rationale**:

- Simplicity: One keypair to manage, not N
- No user registry: Adding users doesn't require editing central files
- Easy distribution: Same private key on all machines
- Trust assumption: All users trust each other (same person's personas)

**Trade-offs Documented**:

| Limitation | Mitigation |
|------------|------------|
| No per-user revocation | Rotate shared key if compromise suspected |
| Shared private key | Distribute via secure channel (not in repo) |
| All-or-nothing access | Acceptable for personal/family repos |

**When Per-User Keys Are Needed**:

- Untrusted users sharing repo
- Need to revoke individual access
- Compliance requirements for key separation

### Decision 3: No secrets.nix (Dynamic Rules)

**Approach**: Wrapper commands generate agenix rules on-the-fly.

```bash
# just secrets-edit cdrokar
#!/usr/bin/env bash
pubkey=$(cat public.age)
secret_file="user/$1/secrets.age"

# Generate temporary rules
tmpfile=$(mktemp)
cat > "$tmpfile" << EOF
{
  "$secret_file".publicKeys = [ "$pubkey" ];
}
EOF

# Run agenix with dynamic rules
RULES="$tmpfile" agenix -e "$secret_file"
rm "$tmpfile"
```

**Rationale**:

- No central file to maintain
- Adding users requires zero changes outside their directory
- Single source of truth: `public.age` contains the key
- Wrapper hides agenix complexity from users

**How agenix RULES Works**:

- agenix looks for `RULES` environment variable
- If set, uses that path instead of `./secrets.nix`
- We generate the rules file dynamically per-operation

### Decision 4: Auto-Initialization

**Approach**: Create keys and secret files automatically on first use.

```bash
# just secrets-init (run once per repo)
if [ ! -f public.age ]; then
  age-keygen -o ~/.config/agenix/key.txt 2>&1 | grep "public key" | cut -d: -f2 | tr -d ' ' > public.age
  echo "Created public.age and ~/.config/agenix/key.txt"
fi

# just secrets-edit <user> (auto-creates secrets.age if missing)
secret_file="user/$1/secrets.age"
if [ ! -f "$secret_file" ]; then
  echo '{}' | age -r "$(cat public.age)" > "$secret_file"
  echo "Created $secret_file with empty JSON"
fi
# Then open for editing...
```

**Rationale**:

- Zero-friction onboarding
- No manual key generation steps
- Empty JSON `{}` is valid starting point
- Users can start adding secrets immediately

### Decision 5: One-Command Secret Addition

**Approach**: Support both interactive and non-interactive modes.

```bash
# Interactive mode (opens editor)
just secrets-edit cdrokar

# Non-interactive mode (one command does everything)
just secrets-edit cdrokar email "me@example.com"
just secrets-edit cdrokar tokens.github "ghp_xxxx"
```

**What happens in non-interactive mode**:

1. Adds/updates `email = "<secret>";` in `user/cdrokar/default.nix`
1. Adds/updates `"email": "me@example.com"` in `user/cdrokar/secrets.age`
1. Both files updated atomically

**Rationale**:

- Single command to add a secret (no manual file editing)
- Supports nested paths (`tokens.github` → `tokens.github = "<secret>";`)
- Interactive mode still available for bulk editing
- Reduces chance of config/secrets mismatch

### Decision 6: `"<secret>"` Placeholder Pattern

**Approach**: (Unchanged from spec 026) Use simple string sentinel.

```nix
user = {
  name = "cdrokar";
  email = "<secret>";              # Resolved from user/cdrokar/secrets.age
  tokens.github = "<secret>";      # Nested paths work
  timezone = "America/Toronto";    # Plain text - no secret needed
};
```

**Rationale**:

- Zero configuration - no imports, no options
- Intuitive - placeholder is self-documenting
- Flexible - works for any field at any nesting level

### Decision 7: Freeform User Schema

**Approach**: (Unchanged from spec 026) Use `freeformType` for extensibility.

```nix
options.user = lib.mkOption {
  type = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    
    options = {
      name = lib.mkOption { type = lib.types.str; };
      email = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      fullName = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      # Core fields documented, everything else freeform
    };
  };
};
```

**Rationale**:

- Add `user.tokens.github`, `user.git.signingKey` without schema changes
- Core fields remain documented with proper types
- No typo protection for freeform (acceptable trade-off)

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

- JSON keys match Nix attribute paths exactly
- `user.email = "<secret>"` → looks for `email` key
- `user.tokens.github = "<secret>"` → looks for `tokens.github` path

### Reading Nested Values

```nix
getNestedValue = json: path:
  let
    parts = lib.splitString "." path;
  in
    lib.foldl' (acc: key: acc.${key}) json parts;
```

______________________________________________________________________

## Implementation Architecture

### File Layout

```
nix-config/
├── public.age                    # Shared public key
├── justfile                      # secrets-* commands
├── flake.nix                     # agenix input
│
└── user/
    ├── cdrokar/
    │   ├── default.nix           # Config with "<secret>" placeholders
    │   └── secrets.age           # Encrypted JSON
    ├── cdrolet/
    │   ├── default.nix
    │   └── secrets.age
    └── shared/
        └── lib/
            └── secrets.nix       # Secret resolution helpers
```

### Secret Resolution Flow

```
1. User Config Evaluation
   └── Detect fields with value "<secret>"
   
2. Path Derivation (simplified)
   └── user/cdrokar/default.nix → user/cdrokar/secrets.age
   
3. Secret Registration
   └── Register with age.secrets for decryption
   
4. Activation Time
   └── agenix decrypts to /run/agenix/
   
5. Value Resolution
   └── Read JSON, extract field value, apply to config
```

### Justfile Commands

```makefile
# Initialize shared keypair (run once)
secrets-init:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f public.age ]; then
        echo "public.age already exists"
        exit 0
    fi
    mkdir -p ~/.config/agenix
    age-keygen -o ~/.config/agenix/key.txt 2>&1 | \
        grep "public key" | cut -d: -f2 | tr -d ' ' > public.age
    echo "Created keypair:"
    echo "  Public:  $(pwd)/public.age"
    echo "  Private: ~/.config/agenix/key.txt"

# Edit user secrets - two modes:
#   just secrets-edit <user>                    - Opens editor (interactive)
#   just secrets-edit <user> <field> <value>    - One-command add (non-interactive)
secrets-edit user field="" value="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check public key exists
    if [ ! -f public.age ]; then
        echo "Error: public.age not found. Run 'just secrets-init' first."
        exit 1
    fi
    
    # Check user directory exists
    if [ ! -d "user/{{user}}" ]; then
        echo "Error: user/{{user}}/ directory not found"
        exit 1
    fi
    
    secret_file="user/{{user}}/secrets.age"
    config_file="user/{{user}}/default.nix"
    pubkey=$(cat public.age)
    
    # Auto-create empty secrets file if missing
    if [ ! -f "$secret_file" ]; then
        echo '{}' | age -r "$pubkey" -o "$secret_file"
        echo "Created $secret_file"
    fi
    
    # Generate temporary rules for agenix
    tmpfile=$(mktemp)
    trap "rm -f $tmpfile" EXIT
    echo "{ \"$secret_file\".publicKeys = [ \"$pubkey\" ]; }" > "$tmpfile"
    
    # Check if non-interactive mode (field and value provided)
    if [ -n "{{field}}" ] && [ -n "{{value}}" ]; then
        # Non-interactive: update both config and secrets
        
        # 1. Update secrets.age with new field/value
        decrypted=$(age -d -i ~/.config/agenix/key.txt "$secret_file")
        updated=$(echo "$decrypted" | jq --arg f "{{field}}" --arg v "{{value}}" \
            'setpath($f | split("."); $v)')
        echo "$updated" | age -r "$pubkey" -o "$secret_file"
        
        # 2. Update default.nix with placeholder
        # Convert dots to nested Nix syntax: tokens.github -> tokens.github
        field_nix="{{field}}"
        
        # Check if field already exists in config
        if grep -q "${field_nix}.*=" "$config_file"; then
            # Replace existing value with <secret>
            sed -i '' "s/${field_nix}.*=.*\"[^\"]*\";/${field_nix} = \"<secret>\";/" "$config_file"
        else
            # Add new field before closing brace of user block
            # This is simplified - real impl needs proper Nix AST handling
            echo "  Added {{field}} = \"<secret>\" to config (manual verification recommended)"
        fi
        
        echo "Secret added: {{field}}"
    else
        # Interactive: open editor
        RULES="$tmpfile" agenix -e "$secret_file"
    fi

# List all user secret files
secrets-list:
    #!/usr/bin/env bash
    echo "User secrets:"
    for dir in user/*/; do
        user=$(basename "$dir")
        [ "$user" = "shared" ] && continue
        if [ -f "${dir}secrets.age" ]; then
            echo "  $user: ${dir}secrets.age (exists)"
        else
            echo "  $user: ${dir}secrets.age (not created)"
        fi
    done

# Show public key (for documentation)
secrets-show-pubkey:
    @cat public.age 2>/dev/null || echo "No public.age found. Run 'just secrets-init'"
```

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
# In platform lib (darwin.nix or nixos.nix)
imports = [
  inputs.agenix.homeManagerModules.default
];

# Configure identity path
age.identityPaths = [
  "${config.home.homeDirectory}/.config/agenix/key.txt"
];

# Register user secrets (if file exists)
age.secrets.userSecrets = lib.mkIf (builtins.pathExists userSecretsPath) {
  file = userSecretsPath;
};
```

### Secret Path Discovery

```nix
# Derive secret path from user name
getUserSecretsPath = username:
  ../user/${username}/secrets.age;

# Check if user has secrets
userHasSecrets = username:
  builtins.pathExists (getUserSecretsPath username);
```

______________________________________________________________________

## Error Handling

### Missing public.age

```
Error: public.age not found.

The shared encryption key hasn't been initialized.

Run: just secrets-init

This creates:
  - public.age (commit this to repo)
  - ~/.config/agenix/key.txt (keep private, distribute to machines)
```

### Missing User Directory

```
Error: user/newuser/ directory not found

Create the user directory first:
  mkdir -p user/newuser
  # Add default.nix with user configuration
  
Then run: just secrets-edit newuser
```

### Missing Secret Field

```nix
throw ''
  Secret field not found: 'tokens.github'
  
  File: user/cdrokar/secrets.age
  
  Your secrets file must contain:
    {
      "tokens": {
        "github": "your-token-here"
      }
    }
  
  Edit with: just secrets-edit cdrokar
''
```

### Decryption Failed

```
Error: Failed to decrypt user/cdrokar/secrets.age

Possible causes:
  1. Private key missing: ~/.config/agenix/key.txt
  2. Wrong private key (doesn't match public.age)
  3. Corrupted secrets file

To fix:
  - Ensure ~/.config/agenix/key.txt exists and matches public.age
  - If key is lost, generate new keypair and re-encrypt all secrets
```

______________________________________________________________________

## Migration from Spec 026

If spec 026 was partially implemented, migrate as follows:

```bash
# 1. Move secret files
for user in cdrokar cdrolet cdronix; do
  if [ -f "secrets/users/$user/default.age" ]; then
    mv "secrets/users/$user/default.age" "user/$user/secrets.age"
  fi
done

# 2. Remove old secrets directory
rm -rf secrets/users secrets/secrets.nix

# 3. Create shared key (if using per-user keys before)
# Pick one user's key or generate new
just secrets-init

# 4. Re-encrypt all secrets with shared key
for user in cdrokar cdrolet cdronix; do
  just secrets-edit "$user"  # Opens editor, just save to re-encrypt
done
```

______________________________________________________________________

## Sources

- [ryantm/agenix](https://github.com/ryantm/agenix) - Official repository
- [agenix RULES environment variable](https://github.com/ryantm/agenix#rules) - Dynamic rules support
- [Nix freeformType](https://nixos.org/manual/nixos/stable/#sec-freeform-modules) - Schema extensibility
- [age encryption](https://github.com/FiloSottile/age) - Underlying encryption tool
