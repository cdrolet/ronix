# Justfile Command Contracts

**Feature**: 031-per-user-secrets
**Date**: 2025-12-29

This document defines the command-line interface contracts for all justfile commands related to per-user secret management.

______________________________________________________________________

## Command: `user-create`

Creates a new user with interactive prompts and optional per-user encryption key.

### Syntax

```bash
just user-create <username>
```

### Parameters

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `username` | string | Yes | `[a-z][a-z0-9-]*` | Username for the new user |

### Interactive Prompts

| Prompt | Type | Default | Validation | Description |
|--------|------|---------|------------|-------------|
| Email address | string | None | Valid email or "" | User's email (required) |
| Full name | string | {username} | Any | User's full name (defaults to username) |
| Use template? | choice | "yes" | yes/no | Whether to use a template |
| Select template | choice | "common" | common/developer | Template to use (if yes to previous) |
| Save key to Bitwarden? | yes/no | "no" | yes/no | Save private key to Bitwarden vault |
| Commit changes? | yes/no | "yes" | yes/no | Commit the new user to git |

### Exit Codes

| Code | Condition |
|------|-----------|
| 0 | Success - user created |
| 1 | Username already exists |
| 2 | Invalid username format |
| 3 | Invalid email format |
| 4 | Template not found |
| 5 | Template substitution failed |
| 6 | Git commit failed |
| 7 | Bitwarden operation failed |

### Side Effects

**Filesystem**:

- Creates `user/<username>/` directory
- Creates `user/<username>/default.nix` from template
- Creates `user/<username>/public.age` (if per-user key selected)
- Creates `~/.config/agenix/key-<username>.txt` (if per-user key selected)

**Git** (if commit selected):

- Stages `user/<username>/default.nix`
- Stages `user/<username>/public.age`
- Creates commit with message: `feat(user): add <username>`

**Bitwarden** (if save to Bitwarden selected):

- Checks Bitwarden CLI is installed
- Logs in to Bitwarden (if needed)
- Unlocks vault
- Creates secure note named `agenix-key-<username>`
- Saves private key content
- Syncs to cloud

### Output Format

```
Creating user: myuser

Email address: myuser@example.com
Full name (optional, default: myuser): My User
Use template? (yes/no) [yes]: yes

Available templates:
  1) common (default)
  2) developer

Select template (1/2) [1]: 2

Generating per-user keypair...
✓ Keypair generated
  Public:  user/myuser/public.age
  Private: ~/.config/agenix/key-myuser.txt

IMPORTANT: Save the private key somewhere safe!

Save private key to Bitwarden? (y/n) [n]: y

Logging into Bitwarden...
Unlocking vault...
Saving to Bitwarden as secure note...
✓ Private key saved to Bitwarden
  Name: agenix-key-myuser

To retrieve on another machine:
  bw get item agenix-key-myuser | jq -r .notes > ~/.config/agenix/key-myuser.txt
  chmod 600 ~/.config/agenix/key-myuser.txt

Creating user configuration...
✓ User configuration created: user/myuser/default.nix

Changes to commit:
  A  user/myuser/default.nix
  A  user/myuser/public.age

Commit message:
  feat(user): add myuser

Commit changes? (y/n) [y]: y
✓ Changes committed: a1b2c3d

User 'myuser' created successfully!

Next steps:
  1. Review configuration: user/myuser/default.nix
  2. Add secrets: just secrets-set myuser <field> <value>
  3. Build and install: just build myuser <system> <host>

On other machines:
  # Retrieve from Bitwarden
  bw login
  export BW_SESSION=$(bw unlock --raw)
  bw get item agenix-key-myuser | jq -r .notes > ~/.config/agenix/key-myuser.txt
  chmod 600 ~/.config/agenix/key-myuser.txt
```

### Error Examples

**Username already exists**:

```
Error: User 'myuser' already exists
Location: user/myuser/

To recreate this user:
  1. Remove directory: rm -rf user/myuser/
  2. Run: just user-create myuser
```

**Invalid username format**:

```
Error: Invalid username 'My-User'
Username must match pattern: [a-z][a-z0-9-]*

Examples:
  ✓ myuser
  ✓ my-user
  ✓ myuser123
  ✗ MyUser (uppercase not allowed)
  ✗ my_user (underscore not allowed)
  ✗ 123user (must start with letter)
```

______________________________________________________________________

## Command: `secrets-init-user`

Generates a per-user encryption keypair.

### Syntax

```bash
just secrets-init-user <username>
```

### Parameters

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `username` | string | Yes | Existing user | Username to generate key for |

### Exit Codes

| Code | Condition |
|------|-----------|
| 0 | Success - keypair generated |
| 1 | User directory doesn't exist |
| 2 | Per-user key already exists |
| 3 | Age keygen failed |

### Side Effects

**Filesystem**:

- Creates `user/<username>/public.age`
- Creates `~/.config/agenix/key-<username>.txt` with permissions 0600

### Output Format

```
Generating per-user keypair for: cdrokar

✓ Keypair generated successfully!

  Public key:  user/cdrokar/public.age (commit this)
  Private key: ~/.config/agenix/key-cdrokar.txt (keep secret)

IMPORTANT: Save the private key somewhere safe!

Distribution options:
  1. Password manager: cat ~/.config/agenix/key-cdrokar.txt | pbcopy
  2. SSH copy: scp ~/.config/agenix/key-cdrokar.txt user@machine:~/.config/agenix/
  3. Encrypted USB: age -p -o key.age ~/.config/agenix/key-cdrokar.txt

To commit the public key:
  git add user/cdrokar/public.age
  git commit -m "feat(secrets): add per-user key for cdrokar"
```

### Error Examples

**User doesn't exist**:

```
Error: User 'nonexistent' not found
Location: user/nonexistent/ (doesn't exist)

Available users:
  - cdrokar
  - cdrolet
  - cdronix

Create user first:
  just user-create nonexistent
```

**Key already exists**:

```
Error: Per-user key already exists for 'cdrokar'
Location: user/cdrokar/public.age

To regenerate the key:
  1. Backup existing secrets: cp user/cdrokar/secrets.age user/cdrokar/secrets.age.bak
  2. Remove old key: rm user/cdrokar/public.age ~/.config/agenix/key-cdrokar.txt
  3. Generate new key: just secrets-init-user cdrokar
  4. Re-encrypt secrets: just secrets-reencrypt cdrokar
```

______________________________________________________________________

## Command: `secrets-migrate-user`

Migrates a user from shared key to per-user key.

### Syntax

```bash
just secrets-migrate-user <username>
```

### Parameters

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `username` | string | Yes | Existing user with secrets | Username to migrate |

### Exit Codes

| Code | Condition |
|------|-----------|
| 0 | Success - user migrated |
| 1 | User doesn't exist |
| 2 | User has no secrets file |
| 3 | User already uses per-user key |
| 4 | Shared private key not found |
| 5 | Decryption failed |
| 6 | Key generation failed |
| 7 | Re-encryption failed |

### Preconditions

- User directory exists: `user/<username>/`
- Secrets file exists: `user/<username>/secrets.age`
- Shared private key exists: `~/.config/agenix/key.txt`
- Per-user key does NOT exist: `user/<username>/public.age`

### Side Effects

**Filesystem**:

- Creates `user/<username>/public.age`
- Creates `~/.config/agenix/key-<username>.txt`
- Modifies `user/<username>/secrets.age` (re-encrypted with new key)

**Git** (staged, not committed):

- Stages `user/<username>/public.age`
- Stages `user/<username>/secrets.age`

### Output Format

```
Migrating cdrokar to per-user encryption key...

1. Decrypting current secrets...
   ✓ Decrypted 3 fields

2. Generating per-user keypair...
   ✓ Keypair generated

3. Re-encrypting with new key...
   ✓ Secrets re-encrypted

✓ Migration complete!

IMPORTANT: Save private key from ~/.config/agenix/key-cdrokar.txt
This key is needed to decrypt cdrokar's secrets.

Distribution options:
  1. Password manager (recommended)
  2. SSH copy to other machines
  3. Private git repository

Commit changes:
  git add user/cdrokar/public.age user/cdrokar/secrets.age
  git commit -m "feat(secrets): migrate cdrokar to per-user key"

On other machines:
  Copy ~/.config/agenix/key-cdrokar.txt to:
    ~/.config/agenix/key-cdrokar.txt
  Set permissions:
    chmod 600 ~/.config/agenix/key-cdrokar.txt
```

### Error Examples

**Already using per-user key**:

```
Error: cdrokar already uses per-user key
Found: user/cdrokar/public.age

Migration is only for users currently using the shared key.

To rotate the existing per-user key:
  just secrets-rotate-user cdrokar
```

**No secrets to migrate**:

```
Error: cdrokar has no secrets file
Location: user/cdrokar/secrets.age (doesn't exist)

Migration is only needed for users with existing secrets.

If you want to use per-user key for this user:
  just secrets-init-user cdrokar
```

______________________________________________________________________

## Command: `secrets-migrate-all`

Migrates all users to per-user keys.

### Syntax

```bash
just secrets-migrate-all
```

### Parameters

None

### Exit Codes

| Code | Condition |
|------|-----------|
| 0 | Success - all users migrated (or already per-user) |
| 1 | One or more migrations failed |

### Side Effects

**Filesystem**:

- Creates per-user keys for all shared-key users
- Re-encrypts all secrets files

**Git** (staged, not committed):

- Stages all `user/*/public.age` files
- Stages all `user/*/secrets.age` files

### Output Format

```
Migrating all users to per-user keys...

Processing cdrokar...
  ✓ Migrated to per-user key

Processing cdrolet...
  ○ Already uses per-user key (skipped)

Processing cdronix...
  ○ No secrets file (skipped)

Migration summary:
  ✓ Migrated: 1 user (cdrokar)
  ○ Skipped: 2 users (already per-user or no secrets)
  ✗ Failed: 0 users

Changes staged:
  user/cdrokar/public.age
  user/cdrokar/secrets.age

Review changes:
  git diff --cached

Commit when ready:
  git add user/
  git commit -m "feat(secrets): migrate all users to per-user keys"

IMPORTANT: Distribute private keys to users!
Each user needs their key copied to other machines:
  ~/.config/agenix/key-<username>.txt
```

______________________________________________________________________

## Command: `secrets-rollback-user`

Rolls back a user from per-user key to shared key.

### Syntax

```bash
just secrets-rollback-user <username>
```

### Parameters

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `username` | string | Yes | Existing user | Username to rollback |

### Exit Codes

| Code | Condition |
|------|-----------|
| 0 | Success - user rolled back |
| 1 | User doesn't exist |
| 2 | User doesn't use per-user key |
| 3 | Per-user private key not found |
| 4 | Shared public key not found |
| 5 | Decryption failed |
| 6 | Re-encryption failed |

### Preconditions

- User uses per-user key: `user/<username>/public.age` exists
- Per-user private key exists: `~/.config/agenix/key-<username>.txt`
- Shared public key exists: `public.age`

### Side Effects

**Filesystem**:

- Deletes `user/<username>/public.age`
- Modifies `user/<username>/secrets.age` (re-encrypted with shared key)

**Git** (staged, not committed):

- Stages deletion of `user/<username>/public.age`
- Stages `user/<username>/secrets.age`

### Output Format

```
Rolling back cdrokar to shared key...

1. Decrypting with per-user key...
   ✓ Decrypted 3 fields

2. Re-encrypting with shared key...
   ✓ Secrets re-encrypted

3. Removing per-user public key...
   ✓ Removed user/cdrokar/public.age

✓ Rollback complete!

User now uses shared key (public.age at repo root)

Commit changes:
  git add user/cdrokar/public.age user/cdrokar/secrets.age
  git commit -m "feat(secrets): rollback cdrokar to shared key"

Note: Per-user private key still exists at:
  ~/.config/agenix/key-cdrokar.txt
Delete manually if no longer needed:
  rm ~/.config/agenix/key-cdrokar.txt
```

______________________________________________________________________

## Command: `secrets-rotate-user`

Rotates a per-user encryption key.

### Syntax

```bash
just secrets-rotate-user <username>
```

### Parameters

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `username` | string | Yes | User with per-user key | Username to rotate key for |

### Exit Codes

| Code | Condition |
|------|-----------|
| 0 | Success - key rotated |
| 1 | User doesn't exist |
| 2 | User doesn't use per-user key |
| 3 | Old private key not found |
| 4 | Decryption failed |
| 5 | Key generation failed |
| 6 | Re-encryption failed |

### Preconditions

- User uses per-user key: `user/<username>/public.age` exists
- Old private key exists: `~/.config/agenix/key-<username>.txt`

### Side Effects

**Filesystem**:

- Backs up old public key: `user/<username>/public.age.old`
- Backs up old private key: `~/.config/agenix/key-<username>.txt.old`
- Creates new public key: `user/<username>/public.age`
- Creates new private key: `~/.config/agenix/key-<username>.txt`
- Re-encrypts all secrets with new key

**Git** (staged, not committed):

- Stages `user/<username>/public.age`
- Stages `user/<username>/secrets.age`

### Output Format

```
Rotating encryption key for cdrokar...

Warning: This will invalidate the old private key.
Continue? (y/n) [n]: y

1. Backing up old keys...
   ✓ Old public key: user/cdrokar/public.age.old
   ✓ Old private key: ~/.config/agenix/key-cdrokar.txt.old

2. Decrypting with old key...
   ✓ Decrypted 3 fields

3. Generating new keypair...
   ✓ New keypair generated

4. Re-encrypting with new key...
   ✓ Secrets re-encrypted

✓ Key rotation complete!

IMPORTANT: Save new private key from ~/.config/agenix/key-cdrokar.txt
This key is needed to decrypt cdrokar's secrets.

Old key backups (delete when no longer needed):
  - user/cdrokar/public.age.old
  - ~/.config/agenix/key-cdrokar.txt.old

Commit changes:
  git add user/cdrokar/public.age user/cdrokar/secrets.age
  git commit -m "feat(secrets): rotate key for cdrokar"

Distribute new key to all machines:
  Copy ~/.config/agenix/key-cdrokar.txt to other machines
  Replace old key at: ~/.config/agenix/key-cdrokar.txt
  Set permissions: chmod 600 ~/.config/agenix/key-cdrokar.txt
```

______________________________________________________________________

## Command: `secrets-list-keys`

Lists all encryption keys and their usage.

### Syntax

```bash
just secrets-list-keys
```

### Parameters

None

### Exit Codes

| Code | Condition |
|------|-----------|
| 0 | Success |

### Output Format

```
Encryption Keys
===============

Shared Key:
  Public key:  public.age
  Status:      ✓ Initialized
  Used by:     2 users (cdrolet, cdronix)

Per-User Keys:
  cdrokar:
    Public key:  user/cdrokar/public.age
    Private key: ~/.config/agenix/key-cdrokar.txt
    Status:      ✓ Initialized
    Has secrets: Yes (3 fields)

User Summary:
  Total users:         3
  Shared key users:    2 (cdrolet, cdronix)
  Per-user key users:  1 (cdrokar)
  No secrets:          0

Key Distribution:
  ✓ All users have encryption keys configured
```

______________________________________________________________________

## Command: `user-list-fields`

Lists all configured fields for a user, indicating which are secrets.

### Syntax

```bash
just user-list-fields <username>
```

### Parameters

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `username` | string | Yes | Existing user | Username to list fields for |

### Exit Codes

| Code | Condition |
|------|-----------|
| 0 | Success |
| 1 | User doesn't exist |

### Output Format

```
User: cdrokar
Configuration: user/cdrokar/default.nix
Encryption: Per-user key

Fields:
  name            = "cdrokar"
  email           = <secret>           ← Encrypted in secrets.age
  fullName        = "Charles Drokar"
  languages       = ["en-CA" "fr-CA"]
  timezone        = "America/Toronto"
  locale          = "en_CA.UTF-8"
  sshKeys.personal = <secret>           ← Encrypted in secrets.age
  sshKeys.work    = <secret>           ← Encrypted in secrets.age
  applications    = ["*"]

Secret fields: 3
  - email
  - sshKeys.personal
  - sshKeys.work

To edit secrets:
  just secrets-edit cdrokar

To view encrypted values (requires private key):
  just secrets-show cdrokar
```

______________________________________________________________________

## Modified Commands (Backward Compatible)

### `secrets-init`

**No changes** - continues to create shared key at repo root.

### `secrets-set`

**Enhanced** - Auto-detects key type:

- Checks for `user/<username>/public.age` first (per-user)
- Falls back to `public.age` (shared)
- Works transparently with both key types

### `secrets-edit`

**Enhanced** - Auto-detects key type:

- Uses appropriate private key automatically
- No user-visible changes to workflow

### `secrets-list`

**Enhanced** - Shows key type for each user:

```
User secrets (colocated in user directories):
==============================================

Shared key: public.age (initialized)

  ✓ cdrolet: user/cdrolet/secrets.age (shared key)
      - email: [encrypted]

  ✓ cdronix: user/cdronix/secrets.age (shared key)
      - email: [encrypted]

  ✓ cdrokar: user/cdrokar/secrets.age (per-user key)
      - email: [encrypted]
      - sshKeys.personal: [encrypted]
      - sshKeys.work: [encrypted]
```

______________________________________________________________________

## Command Relationships

```
User Management:
  just user-create <username>
    → Creates user directory, config, optional per-user key
    → Calls: secrets-init-user (if per-user selected)

Key Management:
  just secrets-init-user <username>
    → Generates per-user keypair
  
  just secrets-migrate-user <username>
    → Converts shared → per-user
    → Calls: secrets-init-user
  
  just secrets-migrate-all
    → Migrates all users
    → Calls: secrets-migrate-user for each user
  
  just secrets-rollback-user <username>
    → Converts per-user → shared
  
  just secrets-rotate-user <username>
    → Regenerates per-user keypair

Secret Operations (Enhanced):
  just secrets-set <user> <field> <value>
    → Auto-detects key type
  
  just secrets-edit <user>
    → Auto-detects key type
  
  just secrets-list
    → Shows key type per user

Inspection:
  just secrets-list-keys
    → Overview of all keys
  
  just user-list-fields <user>
    → Shows all fields and which are secrets
```

## Common Workflows

### Workflow: Create New User with Per-User Key

```bash
# 1. Create user (interactive)
just user-create alice

# During prompts:
# - Email: alice@example.com
# - Template: developer
# - Save to Bitwarden: yes
# - Commit: yes

# 2. Add secrets
just secrets-set alice sshKeys.personal "$(cat ~/.ssh/id_ed25519)"
just secrets-set alice tokens.github "ghp_xxx"

# 3. Build and install
just build alice home-macmini-m4
just install alice home-macmini-m4
```

### Workflow: Migrate Existing User to Per-User Key

```bash
# 1. Migrate user
just secrets-migrate-user bob

# 2. Review changes
git diff --cached

# 3. Commit
git add user/bob/
git commit -m "feat(secrets): migrate bob to per-user key"

# 4. Distribute new private key to bob's machines
# (use password manager, SSH copy, etc.)
```

### Workflow: Rotate Compromised Per-User Key

```bash
# 1. Rotate key
just secrets-rotate-user carol

# 2. Commit new public key
git add user/carol/public.age user/carol/secrets.age
git commit -m "security(secrets): rotate key for carol"

# 3. Distribute new private key
# 4. Remove old key backups when confirmed working
rm user/carol/public.age.old
rm ~/.config/agenix/key-carol.txt.old
```

### Workflow: Audit All Encryption Keys

```bash
# List all keys and usage
just secrets-list-keys

# Inspect specific user
just user-list-fields alice

# View encrypted values (requires private key)
just secrets-show alice
```
