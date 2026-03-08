# Implementation Plan: Per-User Secrets

**Branch**: `031-per-user-secrets` | **Date**: 2025-12-29 | **Spec**: [spec.md](spec.md)

## Summary

Replace the shared-key model (Feature 027) with per-user encryption keys for enhanced security isolation. Each user gets their own age keypair, enabling granular access control and revocation capabilities. Since the project is not yet in production, this is a clean replacement with no migration complexity.

**Key Changes**:

- **Before (Feature 027)**: Single `public.age` at repo root, all users share encryption key
- **After (Feature 031)**: Each user has `user/{name}/public.age`, private keys scoped per-user
- **User Creation**: New `just user-create` command with templates and key generation
- **Bitwarden Integration**: Automated private key backup to Bitwarden CLI
- **Simplified Build**: `just build <user> <host>` (system auto-detected)
- **No Migration**: Project not in use yet, direct implementation only

## Technical Context

**Language/Version**: Bash (justfile recipes), Nix 2.19+\
**Primary Dependencies**: age (encryption), agenix (Nix integration), jq (JSON manipulation)\
**Storage**: Age-encrypted JSON files (`user/{name}/secrets.age`), per-user public keys (`user/{name}/public.age`)\
**Testing**: Manual testing with `nix flake check`, build validation\
**Target Platform**: macOS (darwin), Linux (NixOS)\
**Project Type**: Infrastructure-as-code configuration repository\
**Performance Goals**: \<100ms overhead for key detection, no impact on build time\
**Constraints**: Private keys never committed, public keys always committed\
**Scale/Scope**: 3-5 users initially, scales to dozens of users

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Core Principles Compliance

**I. Declarative Configuration First**:

- ✅ Encryption keys declared in repository structure
- ✅ User configs remain declarative (public keys committed)
- ✅ Private keys distributed manually (not part of declarative state)

**II. Modularity and Reusability**:

- ✅ User templates in `user/shared/templates/` (reusable)
- ✅ Each user is self-contained module
- ✅ Per-user keys don't affect other users (isolation)

**III. Documentation-Driven Development**:

- ✅ Research document completed
- ✅ Data model documented
- ✅ Command contracts specified
- ✅ Quickstart guide provided

**IV. Purity and Reproducibility**:

- ✅ Key generation uses cryptographically secure RNG
- ✅ Encryption deterministic (same input → same output for given key)
- ✅ No network access during build

**V. Testing and Validation**:

- ✅ `nix flake check` validates syntax
- ✅ Template substitution validated before commit
- ✅ Rollback: git revert if issues occur

**VI. Cross-Platform Compatibility**:

- ✅ Works on darwin and nixos
- ✅ Age encryption cross-platform
- ✅ Platform libs updated for per-user key detection

### ✅ Architectural Standards Compliance

**Flakes as Entry Point**:

- ✅ No changes to flake structure
- ✅ Platform libs handle key detection

**Home Manager Integration**:

- ✅ secrets-module.nix updated for per-user keys
- ✅ Apps use same activation pattern (no changes needed)

**Directory Structure Standard**:

- ✅ Follows user/system split pattern
- ✅ Per-user keys colocated: `user/{name}/public.age`
- ✅ Templates in shared location: `user/shared/templates/`

### ✅ Development Standards Compliance

**Specification Management**:

- ✅ Research completed (research.md)
- ✅ Data model documented (data-model.md)
- ✅ Contracts specified (contracts/justfile-commands.md)
- ✅ Quickstart guide (quickstart.md)

**Version Control Discipline**:

- ✅ Public keys committed (safe to commit)
- ✅ Private keys NEVER committed (enforced by .gitignore)
- ✅ Conventional commits: `feat(user): add {username}`

**Code Organization**:

- ✅ Justfile commands in justfile (existing location)
- ✅ Templates in `user/shared/templates/`
- ✅ Secrets helpers in `user/shared/lib/secrets.nix` (existing)

**Configuration Module Organization**:

- ✅ User configs under 200 lines
- ✅ Templates demonstrate best practices
- ✅ Each user is single-responsibility module

**No Backward Compatibility**:

- ✅ No migration needed (project not in use)
- ✅ Clean replacement of Feature 027
- ✅ No compatibility shims required

### Gate Result: ✅ PASS

No constitutional violations. Proceed with implementation.

## Project Structure

### Documentation (this feature)

```text
specs/031-per-user-secrets/
├── plan.md              # This file
├── research.md          # Completed (per-user key analysis)
├── data-model.md        # Completed (entities and relationships)
├── quickstart.md        # Completed (user guide)
└── contracts/           # Completed
    └── justfile-commands.md  # Command specifications
```

### Source Code (repository root)

```text
user/
  shared/
    templates/           # NEW: User creation templates
      minimal.nix        # Just name/email
      developer.nix      # Common dev tools
      full.nix           # All available apps
      README.md          # Template documentation
    lib/
      secrets.nix        # UPDATED: Per-user key detection
  {username}/
    default.nix          # User configuration
    secrets.age          # Encrypted secrets
    public.age           # NEW: Per-user public key

system/shared/lib/
  secrets-module.nix     # UPDATED: Per-user key support

justfile                 # UPDATED: Add user-create, key rotation commands

.gitignore               # UPDATED: Ensure private keys ignored

# Private keys (local machine, never committed)
~/.config/agenix/
  key-{username}.txt     # Per-user private keys
```

**Structure Decision**: Single project with hierarchical user directory structure. Templates in shared location for reusability. Per-user public keys colocated with user configs for discoverability.

## Complexity Tracking

No constitutional violations requiring justification.

______________________________________________________________________

## Phase 0: Research & Design ✅ COMPLETE

### Research Completed

**Document**: [research.md](research.md)

**Key Decisions**:

1. **Per-User Keys (Not Hybrid)**:

   - Each user has their own keypair
   - No shared key option (project not in use, clean implementation)
   - Public key: `user/{name}/public.age` (committed)
   - Private key: `~/.config/agenix/key-{name}.txt` (local)

1. **Key Storage**: Colocated with user configs

   - Consistent with Feature 027's colocated design
   - Self-documenting structure
   - No central registry needed

1. **User Creation**: Interactive CLI workflow

   - `just user-create <username>` with guided prompts
   - Template selection (minimal/developer/full)
   - Automatic key generation
   - Optional git commit

1. **Templates**: Shared template directory

   - Location: `user/shared/templates/`
   - Placeholder substitution (REPLACE_USERNAME, etc.)
   - Versioned with repository

1. **Git Automation**: Interactive commit, manual push

   - Offer to commit with standardized message
   - User reviews before push
   - Prevents accidental pushes

1. **Key Distribution**: Manual with documented options

   - Password manager (recommended - most secure)
   - SSH copy (for machine-to-machine)
   - Encrypted USB (for air-gapped transfer)

1. **Simplified Build Command**: Host implies system

   - Old: `just build <user> <system> <host>`
   - New: `just build <user> <host>` (system auto-detected from host location)

1. **No Migration**: Project not in use, clean replacement only

### Design Completed

**Document**: [data-model.md](data-model.md)

**Entities**:

- EncryptionKey (per-user scope)
- User (with per-user key relationship)
- SecretField (encrypted values)
- UserTemplate (creation templates)
- KeyDetectionResult (discovery logic)

**Contracts**: [contracts/justfile-commands.md](contracts/justfile-commands.md)

**Commands Specified**:

- `just user-create <username>` - Create user with template and key
- `just secrets-init-user <username>` - Generate per-user keypair
- `just secrets-rotate-user <username>` - Rotate compromised key
- `just secrets-list-keys` - Audit all keys
- `just user-list-fields <username>` - Show user config fields
- Enhanced: `just secrets-set/edit/list` - Auto-detect key type

______________________________________________________________________

## Phase 1: Implementation

### 1.1: Update Core Infrastructure

**Files to modify**:

1. **`user/shared/lib/secrets.nix`**:

   - Add per-user key detection:
     ```nix
     getUserPublicKey = username:
       let
         userKeyPath = ../../../user/${username}/public.age;
       in
         if builtins.pathExists userKeyPath
         then builtins.readFile userKeyPath
         else throw "No public key found for user ${username}";
     ```
   - Remove shared key fallback (clean implementation)
   - Update `mkAgenixSecrets` for per-user keys

1. **`system/shared/lib/secrets-module.nix`**:

   - Update key detection for per-user only:
     ```nix
     userPublicKey = secrets.getUserPublicKey user;
     ```
   - Remove shared key logic
   - Update agenix registration

1. **`.gitignore`**:

   - Add pattern for private keys:
     ```gitignore
     # Age private keys (never commit)
     key.txt
     key-*.txt
     ```

### 1.2: Create User Templates

**Files to create**:

1. **`user/shared/templates/common.nix`** (default):

   ```nix
   {...}: {
     user = {
       name = "REPLACE_USERNAME";
       email = "REPLACE_EMAIL";
       
       # Locale defaults (customize as needed)
       languages = ["en-CA"];
       timezone = "America/Toronto";
       locale = "en_CA.UTF-8";
       
       # Essential applications
       applications = [
         "git"
         "zsh"
       ];
     };
   }
   ```

1. **`user/shared/templates/developer.nix`**:

   ```nix
   {...}: {
     user = {
       name = "REPLACE_USERNAME";
       email = "REPLACE_EMAIL";
       
       # Locale defaults (customize as needed)
       languages = ["en-CA"];
       timezone = "America/Toronto";
       locale = "en_CA.UTF-8";
       
       # Developer applications
       applications = [
         "git"
         "zsh"
         "helix"
         "ghostty"
       ];
       
       # Optional: Dock layout
       docked = [
         "zed"
         "ghostty"
         "|"
         "/Downloads"
       ];
       
       # Optional: Font configuration
       fonts = {
         defaults = {
           monospace = {
             families = ["Fira Code"];
             size = 12;
           };
         };
       };
     };
   }
   ```

1. **`user/shared/templates/README.md`**:

   - Document each template
   - Usage instructions
   - Customization guide

### 1.3: Simplify Build Commands

**File**: `justfile`

**Commands to update** (remove redundant system parameter):

The current commands require `just build <user> <system> <host>`, but since hosts are in `system/{system}/host/{hostname}/`, the system can be auto-detected.

**Add helper to detect system from host**:

```makefile
# Detect which system a host belongs to
_detect-system-for-host host:
    #!/usr/bin/env bash
    for system_dir in system/*/host/; do
      if [[ "$system_dir" == "system/shared/"* ]]; then
        continue
      fi
      if [ -d "${system_dir}{{host}}" ]; then
        basename "$(dirname "$(dirname "$system_dir")")"
        exit 0
      fi
    done
    echo "Error: Host '{{host}}' not found in any system" >&2
    exit 1
```

**Update existing commands**:

```makefile
# Old: just build <user> <system> <host>
# New: just build <user> <host>
build user host:
    @SYSTEM=$(just _detect-system-for-host {{host}})
    @just _validate-all {{user}} $SYSTEM {{host}}
    @echo "Building configuration for {{user}} on $SYSTEM with host {{host}}..."
    @just _rebuild-command $SYSTEM build {{user}} {{host}}

# Old: just install <user> <system> <host>
# New: just install <user> <host>
install user host:
    @SYSTEM=$(just _detect-system-for-host {{host}})
    @just _validate-all {{user}} $SYSTEM {{host}}
    @echo "Installing configuration for {{user}} on $SYSTEM with host {{host}}..."
    @just _rebuild-command $SYSTEM switch {{user}} {{host}}
```

### 1.4: Add Justfile Commands

**File**: `justfile`

**Commands to add**:

1. **`user-create <username>`**:
   ```makefile
   user-create username:
       #!/usr/bin/env bash
       set -euo pipefail
       
       USERNAME="{{username}}"
       USER_DIR="user/$USERNAME"
       
       # Validate username
       if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
         echo "Error: Invalid username format"
         exit 2
       fi
       
       # Check doesn't exist
       if [ -d "$USER_DIR" ]; then
         echo "Error: User already exists"
         exit 1
       fi
       
       # Interactive prompts
       read -p "Email address: " EMAIL
       read -p "Full name (optional, default: $USERNAME): " FULLNAME
       FULLNAME=${FULLNAME:-$USERNAME}
       
       echo "Available templates:"
       echo "  1) common (default)"
       echo "  2) developer"
       read -p "Select template (1/2) [1]: " TEMPLATE_NUM
       TEMPLATE_NUM=${TEMPLATE_NUM:-1}
       
       case $TEMPLATE_NUM in
         1) TEMPLATE="common" ;;
         2) TEMPLATE="developer" ;;
         *) echo "Invalid choice"; exit 4 ;;
       esac
       
       # Create user directory
       mkdir -p "$USER_DIR"
       
       # Copy and process template
       cp "user/shared/templates/${TEMPLATE}.nix" "$USER_DIR/default.nix"
       sed -i.bak "s/REPLACE_USERNAME/$USERNAME/g" "$USER_DIR/default.nix"
       sed -i.bak "s/REPLACE_EMAIL/$EMAIL/g" "$USER_DIR/default.nix"
       rm "$USER_DIR/default.nix.bak"
       
       # Add fullName if different from username
       if [ "$FULLNAME" != "$USERNAME" ]; then
         # Insert fullName after email line
         sed -i.bak "/email = /a\\
       fullName = \"$FULLNAME\";
   ```

" "$USER_DIR/default.nix"
rm "$USER_DIR/default.nix.bak"
fi

```
   # Validate no placeholders remain
   if grep -q "REPLACE_" "$USER_DIR/default.nix"; then
     echo "Error: Template substitution failed"
     exit 5
   fi
   
   # Generate keypair
   just secrets-init-user "$USERNAME"
   
   # Offer to save to Bitwarden
   echo ""
   read -p "Save private key to Bitwarden? (y/n) [n]: " SAVE_BW
   if [ "${SAVE_BW:-n}" = "y" ]; then
     just _save-key-to-bitwarden "$USERNAME"
   fi
   
   # Format
   nix fmt "$USER_DIR/default.nix"
   
   # Commit prompt
   echo ""
   echo "Changes to commit:"
   git status --short "$USER_DIR"
   echo ""
   read -p "Commit changes? (y/n) [y]: " COMMIT
   if [ "${COMMIT:-y}" = "y" ]; then
     git add "$USER_DIR"
     git commit -m "feat(user): add $USERNAME"
     echo "✓ Committed"
   fi
   
   echo ""
   echo "User '$USERNAME' created successfully!"
   echo "Next steps:"
   echo "  1. Add secrets: just secrets-set $USERNAME <field> <value>"
   echo "  2. Build: just build $USERNAME <host>"
```

````

2. **`secrets-init-user <username>`**:
```makefile
secrets-init-user username:
    #!/usr/bin/env bash
    set -euo pipefail
    
    USERNAME="{{username}}"
    USER_DIR="user/$USERNAME"
    PUBLIC_KEY="$USER_DIR/public.age"
    PRIVATE_KEY="$HOME/.config/agenix/key-$USERNAME.txt"
    
    # Validate user exists
    if [ ! -d "$USER_DIR" ]; then
      echo "Error: User directory not found"
      exit 1
    fi
    
    # Check key doesn't exist
    if [ -f "$PUBLIC_KEY" ]; then
      echo "Error: Key already exists"
      exit 2
    fi
    
    # Generate keypair
    mkdir -p "$(dirname "$PRIVATE_KEY")"
    nix shell nixpkgs#age -c age-keygen -o "$PRIVATE_KEY" 2>&1 | \
      grep "Public key:" | cut -d: -f2 | tr -d ' ' > "$PUBLIC_KEY"
    
    echo "✓ Keypair generated"
    echo "  Public:  $PUBLIC_KEY"
    echo "  Private: $PRIVATE_KEY"
    echo ""
    echo "Distribution options:"
    echo "  1. Bitwarden: just secrets-save-to-bitwarden $USERNAME"
    echo "  2. Manual copy: cat $PRIVATE_KEY | pbcopy"
    echo "  3. SSH copy: scp $PRIVATE_KEY user@machine:~/.config/agenix/"
````

3. **`secrets-rotate-user <username>`**:

   ```makefile
   secrets-rotate-user username:
       #!/usr/bin/env bash
       set -euo pipefail
       
       USERNAME="{{username}}"
       SECRET_FILE="user/$USERNAME/secrets.age"
       OLD_KEY="$HOME/.config/agenix/key-$USERNAME.txt"
       PUBLIC_KEY="user/$USERNAME/public.age"
       
       # Validate preconditions
       if [ ! -f "$SECRET_FILE" ]; then
         echo "Error: No secrets to rotate"
         exit 1
       fi
       
       if [ ! -f "$OLD_KEY" ]; then
         echo "Error: Old private key not found"
         exit 2
       fi
       
       # Backup old keys
       cp "$PUBLIC_KEY" "$PUBLIC_KEY.old"
       cp "$OLD_KEY" "$OLD_KEY.old"
       
       # Decrypt with old key
       SECRETS=$(nix shell nixpkgs#age -c age -d -i "$OLD_KEY" "$SECRET_FILE")
       
       # Generate new key
       rm "$PUBLIC_KEY" "$OLD_KEY"
       mkdir -p "$(dirname "$OLD_KEY")"
       nix shell nixpkgs#age -c age-keygen -o "$OLD_KEY" 2>&1 | \
         grep "Public key:" | cut -d: -f2 | tr -d ' ' > "$PUBLIC_KEY"
       
       # Re-encrypt
       PUBKEY=$(cat "$PUBLIC_KEY")
       echo "$SECRETS" | nix shell nixpkgs#age -c age -r "$PUBKEY" -o "$SECRET_FILE"
       
       echo "✓ Key rotated"
       echo "  Old keys backed up with .old suffix"
       echo "  New private key: $OLD_KEY"
       echo ""
       echo "Distribution options:"
       echo "  1. Bitwarden: just secrets-save-to-bitwarden $USERNAME"
       echo "  2. Manual copy: cat $OLD_KEY | pbcopy"
       echo "  3. SSH copy: scp $OLD_KEY user@machine:~/.config/agenix/"
       echo ""
       echo "After distribution, delete old key backups:"
       echo "  rm $PUBLIC_KEY.old $OLD_KEY.old"
   ```

1. **`secrets-list-keys`**:

   ```makefile
   secrets-list-keys:
       #!/usr/bin/env bash
       echo "Per-User Encryption Keys"
       echo "========================"
       echo ""
       
       for user_dir in user/*/; do
         user=$(basename "$user_dir")
         [ "$user" = "shared" ] && continue
         
         public_key="$user_dir/public.age"
         private_key="$HOME/.config/agenix/key-$user.txt"
         
         echo "$user:"
         if [ -f "$public_key" ]; then
           echo "  Public:  $public_key ✓"
           if [ -f "$private_key" ]; then
             echo "  Private: $private_key ✓"
           else
             echo "  Private: $private_key ✗ (not found)"
           fi
         else
           echo "  No key configured"
         fi
         echo ""
       done
   ```

1. **`_save-key-to-bitwarden <username>`** (internal helper):

   ```makefile
   _save-key-to-bitwarden username:
       #!/usr/bin/env bash
       set -euo pipefail
       
       USERNAME="{{username}}"
       PRIVATE_KEY="$HOME/.config/agenix/key-$USERNAME.txt"
       
       # Check if bw is installed
       if ! command -v bw &> /dev/null; then
         echo "Error: Bitwarden CLI not installed"
         echo "Install: brew install bitwarden-cli (macOS)"
         echo "         nix-shell -p bitwarden-cli (Nix)"
         exit 1
       fi
       
       # Check if logged in
       if ! bw login --check &> /dev/null; then
         echo "Logging into Bitwarden..."
         bw login
       fi
       
       # Unlock vault
       echo "Unlocking vault..."
       BW_SESSION=$(bw unlock --raw)
       export BW_SESSION
       
       # Read private key
       PRIVATE_KEY_CONTENT=$(cat "$PRIVATE_KEY")
       
       # Create secure note
       echo "Saving to Bitwarden as secure note..."
       bw get template item | \
         jq --arg name "agenix-key-$USERNAME" \
            --arg content "$PRIVATE_KEY_CONTENT" \
            '.type = 2 | .secureNote.type = 0 | .notes = $content | .name = $name' | \
         bw encode | \
         bw create item --session "$BW_SESSION" > /dev/null
       
       # Sync
       bw sync --session "$BW_SESSION" > /dev/null
       
       echo "✓ Private key saved to Bitwarden"
       echo "  Name: agenix-key-$USERNAME"
       echo ""
       echo "To retrieve on another machine:"
       echo "  bw get item agenix-key-$USERNAME | jq -r .notes > ~/.config/agenix/key-$USERNAME.txt"
       echo "  chmod 600 ~/.config/agenix/key-$USERNAME.txt"
   ```

1. **`user-list-fields <username>`**:

   ```makefile
   user-list-fields username:
       #!/usr/bin/env bash
       USERNAME="{{username}}"
       
       echo "User: $USERNAME"
       echo "Configuration: user/$USERNAME/default.nix"
       echo ""
       
       # Parse user config and highlight <secret> fields
       # (Simplified version - full implementation would use nix eval)
       echo "Fields:"
       grep -E "^\s*\w+\s*=" "user/$USERNAME/default.nix" | while read line; do
         if echo "$line" | grep -q "<secret>"; then
           echo "  $line  ← Encrypted"
         else
           echo "  $line"
         fi
       done
   ```

**Commands to update** (auto-detect per-user key):

- `secrets-set`: Use `user/{name}/public.age` automatically
- `secrets-edit`: Use `~/.config/agenix/key-{name}.txt` automatically
- `secrets-list`: Show key type per user

**New public command** (for saving existing keys to Bitwarden):

7. **`secrets-save-to-bitwarden <username>`**:
   ```makefile
   # Public command to save existing private key to Bitwarden
   secrets-save-to-bitwarden username:
       @just _save-key-to-bitwarden {{username}}
   ```

### 1.5: Update Documentation

**Files to update**:

1. **`CLAUDE.md`**:

   - Update "Secrets Management" section
   - Reference Feature 031 instead of 027
   - Update command examples

1. **`.specify/memory/constitution.md`**:

   - No changes needed (already compliant)

1. **`README.md`**:

   - Update quickstart with `just user-create`
   - Update secrets examples

______________________________________________________________________

## Phase 2: Testing & Validation

### Test Plan

1. **User Creation**:

   - ✅ Create user with minimal template
   - ✅ Create user with developer template
   - ✅ Create user with full template
   - ✅ Validate generated config syntax
   - ✅ Verify keypair generated
   - ✅ Check no REPLACE\_ placeholders remain

1. **Key Management**:

   - ✅ Generate per-user keypair
   - ✅ Rotate key
   - ✅ List all keys
   - ✅ Verify private key permissions (0600)

1. **Secret Operations**:

   - ✅ Set simple secret (email)
   - ✅ Set nested secret (sshKeys.personal)
   - ✅ Edit secrets interactively
   - ✅ List secrets

1. **Build & Activation**:

   - ✅ Build user configuration
   - ✅ Verify secrets decrypt at activation
   - ✅ Check apps receive resolved values

1. **Git Integration**:

   - ✅ Commit user creation
   - ✅ Verify public key committed
   - ✅ Verify private key NOT committed

### Validation Commands

```bash
# Test user creation
just user-create testuser

# Verify structure
ls -la user/testuser/
# Should contain: default.nix, public.age

ls -la ~/.config/agenix/
# Should contain: key-testuser.txt (permissions 0600)

# Test secrets
just secrets-set testuser email "test@example.com"
just secrets-list

# Test build
just build testuser home-macmini-m4

# Verify syntax
nix flake check

# Test git
git status
# Should show: user/testuser/default.nix, user/testuser/public.age
# Should NOT show: any key*.txt files

# Clean up
rm -rf user/testuser/
rm ~/.config/agenix/key-testuser.txt
```

______________________________________________________________________

## Phase 3: Deployment

### Deployment Steps

1. **Prepare existing users** (if any):

   ```bash
   # Remove old shared key infrastructure
   rm public.age
   rm ~/.config/agenix/key.txt

   # Regenerate users with per-user keys
   for user in cdrokar cdrolet cdronix; do
     # Backup existing config
     cp user/$user/default.nix user/$user/default.nix.bak
     
     # Generate per-user key
     just secrets-init-user $user
     
     # Re-encrypt secrets (if exist)
     if [ -f "user/$user/secrets.age" ]; then
       # Manual re-encryption with new key
       # (User must have decrypted values available)
     fi
   done
   ```

1. **Commit changes**:

   ```bash
   git add user/
   git add .gitignore
   git add justfile
   git commit -m "feat(031): implement per-user secrets"
   ```

1. **Distribute private keys**:

   - Save to password manager
   - Copy to other machines via SSH
   - Document recovery procedures

1. **Update documentation**:

   ```bash
   git add CLAUDE.md README.md
   git commit -m "docs(031): update for per-user secrets"
   ```

1. **Test on all platforms**:

   - Build on macOS (darwin)
   - Build on Linux (nixos)
   - Verify secrets decrypt correctly

### Rollback Plan

If issues occur:

```bash
# Revert the feature branch
git revert <commit-hash>

# Or reset to before feature
git reset --hard <commit-before-feature>

# Restore old shared key (if backed up)
cp public.age.bak public.age
cp ~/.config/agenix/key.txt.bak ~/.config/agenix/key.txt
```

______________________________________________________________________

## Success Criteria

- ✅ Each user has their own encryption keypair
- ✅ `just user-create` command works with all templates
- ✅ Secrets operations auto-detect per-user keys
- ✅ Build succeeds with per-user keys
- ✅ Secrets decrypt and apply at activation time
- ✅ Private keys never committed to repository
- ✅ Public keys always committed
- ✅ Documentation updated and accurate
- ✅ `nix flake check` passes
- ✅ All existing functionality preserved

______________________________________________________________________

## Timeline Estimate

- **Phase 1 (Implementation)**: 5-7 hours

  - 1.1 Core infrastructure: 1 hour
  - 1.2 Templates: 1 hour
  - 1.3 Build command simplification: 0.5 hour
  - 1.4 Justfile commands: 2-3 hours
  - 1.5 Bitwarden integration: 0.5 hour
  - 1.6 Documentation: 1 hour

- **Phase 2 (Testing)**: 2 hours

  - Manual testing all commands
  - Build validation
  - Cross-platform testing

- **Phase 3 (Deployment)**: 1 hour

  - User regeneration
  - Key distribution
  - Final validation

**Total**: 8-10 hours

______________________________________________________________________

## Notes

- No migration complexity needed (project not in use)
- Clean replacement of Feature 027's shared key model
- Templates make user creation consistent and error-free
- Per-user keys enable security isolation and granular revocation
- Git automation reduces manual work while maintaining control
