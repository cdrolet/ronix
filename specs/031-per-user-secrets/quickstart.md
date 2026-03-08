# Quickstart: Per-User Secrets

**Feature**: 031-per-user-secrets
**Date**: 2025-12-29

This guide shows how to use per-user encryption keys for enhanced security isolation.

______________________________________________________________________

## Overview

**What changed from Feature 027**:

- Feature 027 (old): Single shared key for all users
- Feature 031 (new): Each user has their own encryption key
- **No migration needed**: Project not in production yet, direct implementation

**Benefits**:

- ✅ Security isolation: Each user can only decrypt their own secrets
- ✅ Granular revocation: Revoke one user without affecting others
- ✅ Better for multi-user environments

______________________________________________________________________

## Quick Start

### 1. Create a New User

```bash
just user-create alice
```

**Interactive prompts**:

```
Email address: alice@example.com
Full name (optional, default: alice): Alice Smith
Use template? (yes/no) [yes]: yes
Select template (1/2) [1]: 2
Save private key to Bitwarden? (y/n) [n]: n
```

**Result**:

- Creates `user/alice/default.nix` from template
- Generates per-user keypair
- Public key: `user/alice/public.age` (committed to repo)
- Private key: `~/.config/agenix/key-alice.txt` (local only)

### 2. Add Secrets

```bash
# Simple fields
just secrets-set alice email "alice@example.com"

# Nested fields (SSH keys, tokens, etc.)
just secrets-set alice sshKeys.personal "$(cat ~/.ssh/id_ed25519)"
just secrets-set alice sshKeys.work "$(cat ~/.ssh/id_ed25519_work)"
just secrets-set alice tokens.github "ghp_xxx"
```

**Result**:

- Secrets encrypted in `user/alice/secrets.age`
- Config file updated with `<secret>` placeholders

### 3. Build and Install

```bash
just build alice home-macmini-m4
just install alice home-macmini-m4
```

**Note**: The system (darwin/nixos) is auto-detected from the host location (`system/{system}/host/{hostname}/`).

**At activation time**:

- Secrets decrypted using private key
- Values injected into applications
- SSH keys deployed, git configured, etc.

______________________________________________________________________

## Common Tasks

### View User's Secrets (requires private key)

```bash
just secrets-edit alice
```

Opens editor with decrypted JSON. Save to re-encrypt.

### List All Secrets for a User

```bash
just secrets-list
```

Output:

```
User secrets (colocated in user directories):
==============================================

  ✓ alice: user/alice/secrets.age (per-user key)
      - email: [encrypted]
      - sshKeys.personal: [encrypted]
      - sshKeys.work: [encrypted]
      - tokens.github: [encrypted]
```

### Distribute Private Key to Other Machines

**Option 1: Bitwarden CLI (recommended - automated)**

```bash
# On source machine - save to Bitwarden during user creation
just user-create alice
# When prompted: "Save private key to Bitwarden? (y/n)" → y

# Or save an existing key
just secrets-save-to-bitwarden alice

# On target machine - retrieve from Bitwarden
bw login  # Login once
export BW_SESSION=$(bw unlock --raw)
bw get item agenix-key-alice | jq -r .notes > ~/.config/agenix/key-alice.txt
chmod 600 ~/.config/agenix/key-alice.txt
```

**Option 2: Password Manager (manual)**

```bash
# On source machine
cat ~/.config/agenix/key-alice.txt | pbcopy  # macOS
cat ~/.config/agenix/key-alice.txt | xclip -selection clipboard  # Linux

# Store in password manager (1Password, Bitwarden, etc.)

# On target machine
# Paste from password manager into:
mkdir -p ~/.config/agenix
# paste content
chmod 600 ~/.config/agenix/key-alice.txt
```

**Option 3: SSH Copy**

```bash
# From source machine to target
scp ~/.config/agenix/key-alice.txt alice@target-machine:~/.config/agenix/
ssh alice@target-machine chmod 600 ~/.config/agenix/key-alice.txt
```

**Why not git?**: Storing private keys in git (even private repos) is **not recommended**:

- Keys persist in git history even if deleted
- GitHub account compromise exposes all keys
- Risk of accidentally making repo public
- Against security best practices

### Rotate a Compromised Key

```bash
just secrets-rotate-user alice
```

This will:

1. Decrypt secrets with old key
1. Generate new keypair
1. Re-encrypt secrets with new key
1. Backup old keys (`.old` suffix)

Then distribute the new private key to all machines.

______________________________________________________________________

## User Templates

Two templates available in `user/shared/templates/`:

### Common Template (default)

- Essential apps: git, zsh
- Basic locale configuration
- Minimal setup
- Use for most users

### Developer Template

- Developer apps: git, zsh, helix, ghostty
- Dock layout and font configuration
- Use for software developers

______________________________________________________________________

## Architecture

### Directory Structure

```
user/
  alice/
    default.nix       # User configuration with <secret> placeholders
    secrets.age       # Encrypted secrets (per-user key)
    public.age        # Alice's public key (committed)
  bob/
    default.nix
    secrets.age
    public.age        # Bob's public key (committed)
  shared/
    templates/        # User creation templates
      minimal.nix
      developer.nix
      full.nix

# Private keys (local machine only, never committed)
~/.config/agenix/
  key-alice.txt       # Alice's private key
  key-bob.txt         # Bob's private key
```

### How It Works

**1. User Creation**:

```
just user-create alice
  ↓
Generate keypair with age-keygen
  ↓
Save public key → user/alice/public.age (committed)
Save private key → ~/.config/agenix/key-alice.txt (local only)
  ↓
Create config from template
```

**2. Adding Secrets**:

```
just secrets-set alice email "alice@example.com"
  ↓
Read user/alice/secrets.age (if exists), decrypt
  ↓
Update JSON: {"email": "alice@example.com"}
  ↓
Encrypt with user/alice/public.age
  ↓
Write user/alice/secrets.age
  ↓
Update user/alice/default.nix: email = "<secret>"
```

**3. Activation (Build/Install)**:

```
nix build/darwin-rebuild switch
  ↓
secrets-module.nix registers:
  age.secrets."user-alice-secrets" = {
    file = user/alice/secrets.age;
  }
  ↓
agenix decrypts with ~/.config/agenix/key-alice.txt
  ↓
Writes to /run/agenix/user-alice-secrets
  ↓
App activation scripts read and apply secrets:
  git config --global user.email "alice@example.com"
  cp ssh-key ~/.ssh/id_ed25519
```

______________________________________________________________________

## Security Best Practices

### Private Key Storage

**DO**:

- ✅ Store in `~/.config/agenix/` with permissions 0600
- ✅ Use password manager for backup
- ✅ Encrypt if storing on USB or cloud
- ✅ Use SSH for machine-to-machine transfer

**DON'T**:

- ❌ Commit to git repository
- ❌ Send via unencrypted email
- ❌ Store in unencrypted cloud sync (Dropbox, iCloud)
- ❌ Share via messaging apps

### Key Rotation

Rotate keys when:

- Key may have been compromised
- User leaves the organization
- Compliance requirements (e.g., every 90 days)
- As a precaution after security incident

```bash
just secrets-rotate-user alice
```

### Access Control

Each user can only decrypt their own secrets:

- Alice has `~/.config/agenix/key-alice.txt` → can decrypt `user/alice/secrets.age`
- Bob has `~/.config/agenix/key-bob.txt` → can decrypt `user/bob/secrets.age`
- Alice cannot decrypt Bob's secrets (and vice versa)

______________________________________________________________________

## Troubleshooting

### Error: No encryption key found

```
Error: No encryption key found for user alice

Initialize key with:
  just secrets-init-user alice
```

**Solution**:

```bash
just secrets-init-user alice
```

### Error: Permission denied (secrets.age)

```
Error: age: failed to decrypt: incorrect passphrase
```

**Cause**: Wrong private key or corrupted key file

**Solution**:

1. Verify key exists: `ls -la ~/.config/agenix/key-alice.txt`
1. Check permissions: `chmod 600 ~/.config/agenix/key-alice.txt`
1. If key is lost, regenerate: `just secrets-rotate-user alice`

### Error: Private key not found

```
Error: Private key not found
Location: ~/.config/agenix/key-alice.txt
```

**Solution**: Restore from backup (password manager, SSH key repo, etc.)

```bash
# From password manager
# Paste into: ~/.config/agenix/key-alice.txt
chmod 600 ~/.config/agenix/key-alice.txt

# OR from git repository
git clone git@github.com:alice/ssh-keys-private.git ~/ssh-keys
cp ~/ssh-keys/agenix-key.txt ~/.config/agenix/key-alice.txt
chmod 600 ~/.config/agenix/key-alice.txt
```

### Secret not resolving at activation time

**Symptoms**: Config has `email = "<secret>"` but git still shows wrong email

**Debug steps**:

1. Check secrets file exists: `ls user/alice/secrets.age`
1. Check field exists in secrets: `just secrets-edit alice`
1. Verify private key: `ls -la ~/.config/agenix/key-alice.txt`
1. Check activation logs: `journalctl -u home-manager-$USER.service` (Linux) or system logs (macOS)

______________________________________________________________________

## Examples

### Example 1: Developer User with SSH Keys

```bash
# Create user
just user-create alice
# Template: developer
# Creates config with git, zsh, helix, etc.

# Add SSH keys
just secrets-set alice sshKeys.github "$(cat ~/.ssh/id_ed25519)"
just secrets-set alice sshKeys.gitlab "$(cat ~/.ssh/id_ed25519_gitlab)"

# Add tokens
just secrets-set alice tokens.github "ghp_xxx"
just secrets-set alice tokens.gitlab "glpat-xxx"

# Reference in config (already has <secret> placeholders)
# user/alice/default.nix contains:
#   sshKeys.github = "<secret>";
#   tokens.github = "<secret>";

# Build and install
just build alice home-macmini-m4
just install alice home-macmini-m4
```

### Example 2: Minimal User for Testing

```bash
# Create user
just user-create testuser
# Template: minimal

# Add only email
just secrets-set testuser email "test@example.com"

# Build
just build testuser home-macmini-m4
```

### Example 3: Full-Featured User

```bash
# Create user
just user-create poweruser
# Template: full
# Imports all available applications

# Add all secrets
just secrets-set poweruser email "power@example.com"
just secrets-set poweruser sshKeys.personal "$(cat ~/.ssh/id_ed25519)"
just secrets-set poweruser tokens.github "ghp_xxx"
just secrets-set poweruser tokens.openai "sk-xxx"

# Build and install
just build poweruser home-macmini-m4
just install poweruser home-macmini-m4
```

______________________________________________________________________

## Comparison with Feature 027

| Aspect | Feature 027 (Shared Key) | Feature 031 (Per-User Keys) |
|--------|--------------------------|------------------------------|
| **Encryption Key** | Single shared `public.age` | Per-user `user/{name}/public.age` |
| **Private Key** | `~/.config/agenix/key.txt` | `~/.config/agenix/key-{name}.txt` |
| **Security Isolation** | None (all users share key) | Full (each user has own key) |
| **Revocation** | Must re-encrypt everything | Revoke individual user |
| **Key Distribution** | Simple (same key everywhere) | Per-user (each needs their key) |
| **Best For** | Single user, trusted family | Multi-user, compliance needs |
| **User Creation** | Manual file creation | `just user-create` with templates |

______________________________________________________________________

## Next Steps

After setting up per-user secrets:

1. **Add more users**: `just user-create <username>`
1. **Customize configuration**: Edit `user/<username>/default.nix`
1. **Add applications**: Update `applications = [...]` array
1. **Configure secrets**: `just secrets-set <user> <field> <value>`
1. **Build and test**: `just build <user> <system> <host>`
1. **Deploy**: `just install <user> <system> <host>`

For detailed command reference, see `contracts/justfile-commands.md`.
