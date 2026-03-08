# Data Model: Per-User Secrets

**Feature**: 031-per-user-secrets
**Date**: 2025-12-29

## Entity Definitions

### 1. Encryption Key

Represents a cryptographic key pair used for encrypting/decrypting user secrets.

**Attributes**:

- `type`: "shared" | "per-user" - Key scope
- `publicKey`: string - Age public key (age1...)
- `publicKeyPath`: path - Location of public key file
- `privateKeyPath`: path - Location of private key file (local machine)
- `owner`: string | null - Username for per-user keys, null for shared

**States**:

- Initialized: Key pair generated, files created
- Distributed: Private key copied to target machines
- Active: Currently in use for encryption/decryption
- Rotated: Replaced by new key
- Revoked: No longer valid for new operations

**Validation Rules**:

- Public key must match age format: `age1[a-z0-9]{58}`
- Private key must have permissions 0600
- Private key must be stored in `~/.config/agenix/`
- Public key must be committed to repository
- Private key must NEVER be committed

**File Locations**:

```
# Shared key (Feature 027)
public.age                           # Public key (committed)
~/.config/agenix/key.txt             # Private key (not committed)

# Per-user key (Feature 031)
user/{username}/public.age           # Public key (committed)
~/.config/agenix/key-{username}.txt  # Private key (not committed)
```

### 2. User

Represents a user configuration with secrets management.

**Attributes**:

- `name`: string - Username (required)
- `email`: string - Email address (required)
- `fullName`: string - Full name (optional)
- `encryptionKeyType`: "shared" | "per-user" - Which key type this user uses
- `secretsPath`: path - Location of encrypted secrets file
- `configPath`: path - Location of user configuration

**Relationships**:

- HAS-ONE EncryptionKey (through encryptionKeyType)
- HAS-MANY SecretField (in secrets.age file)

**Validation Rules**:

- `name` must match pattern: `[a-z][a-z0-9-]*`
- `email` must be valid email format or "<secret>"
- User directory must exist: `user/{name}/`
- Config file must exist: `user/{name}/default.nix`

**File Structure**:

```
user/{username}/
  default.nix       # User configuration
  secrets.age       # Encrypted secrets (optional)
  public.age        # Per-user public key (optional)
```

### 3. Secret Field

Represents a single secret value within a user's encrypted secrets file.

**Attributes**:

- `path`: string - Dotted path in JSON (e.g., "email", "sshKeys.personal")
- `placeholder`: "<secret>" - Sentinel value in configuration
- `encryptedValue`: string - Actual secret value (encrypted at rest)
- `configPath`: string - Location in user config (e.g., "user.email")

**Relationships**:

- BELONGS-TO User
- ENCRYPTED-BY EncryptionKey

**Validation Rules**:

- Path must not be empty
- Path segments must match Nix attribute syntax
- Value must not contain "<secret>" placeholder when decrypted
- Nested paths must not conflict (can't have both "sshKeys" and "sshKeys.personal" as secrets)

**Storage Format** (in secrets.age):

```json
{
  "email": "user@example.com",
  "sshKeys": {
    "personal": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
    "work": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
  },
  "tokens": {
    "github": "ghp_xxx"
  }
}
```

### 4. User Template

Represents a template for creating new user configurations.

**Attributes**:

- `name`: string - Template identifier ("minimal", "developer", "full")
- `description`: string - Human-readable description
- `filePath`: path - Template file location
- `placeholders`: array[string] - Variables to substitute

**Standard Templates**:

1. **minimal**: Just name and email, empty applications
1. **developer**: Common dev tools (git, zsh, helix, ghostty)
1. **full**: All available apps, comprehensive configuration

**Template Format**:

```nix
# Placeholders for substitution
{...}: {
  user = {
    name = "REPLACE_USERNAME";
    email = "REPLACE_EMAIL";
    fullName = "REPLACE_FULLNAME";
    
    # ... template-specific configuration
  };
}
```

**Validation Rules**:

- Template must be valid Nix syntax
- All REPLACE\_\* placeholders must be defined
- After substitution, no REPLACE\_\* markers should remain

### 5. Key Detection Result

Represents the outcome of key discovery for a user.

**Attributes**:

- `keyType`: "per-user" | "shared" | "none"
- `publicKeyPath`: path | null
- `publicKey`: string | null
- `privateKeyPath`: path | null
- `error`: string | null

**Detection Logic**:

```
1. Check user/{username}/public.age exists
   → If yes: keyType = "per-user", publicKeyPath = user/{username}/public.age
   
2. Check public.age at repo root exists
   → If yes: keyType = "shared", publicKeyPath = public.age
   
3. Neither exists
   → keyType = "none", error = "No encryption key found"
```

**Private Key Detection**:

```
If keyType = "per-user":
  privateKeyPath = ~/.config/agenix/key-{username}.txt
  
If keyType = "shared":
  privateKeyPath = ~/.config/agenix/key.txt
```

## Relationships

```
┌─────────────────┐
│ EncryptionKey   │
│  - type         │
│  - publicKey    │
│  - owner        │
└────────┬────────┘
         │
         │ used by
         │
         ▼
    ┌────────────────┐
    │ User           │
    │  - name        │
    │  - email       │
    │  - keyType     │
    └────┬───────────┘
         │
         │ has many
         │
         ▼
    ┌────────────────┐
    │ SecretField    │
    │  - path        │
    │  - value       │
    └────────────────┘

┌──────────────────┐
│ UserTemplate     │
│  - name          │
│  - description   │
└──────────────────┘
         │
         │ creates
         │
         ▼
    ┌────────────────┐
    │ User           │
    └────────────────┘
```

## State Transitions

### Encryption Key Lifecycle

```
[Not Initialized] 
    │
    │ just secrets-init (shared)
    │ OR
    │ just secrets-init-user <user> (per-user)
    │
    ▼
[Initialized]
    │
    │ Distribute private key
    │
    ▼
[Active]
    │
    ├─► just secrets-rotate-shared
    │   OR
    │   just secrets-rotate-user <user>
    │   │
    │   ▼
    │ [Rotated] ──► [Revoked]
    │
    └─► Compromise detected
        │
        ▼
      [Revoked]
```

### User Creation Lifecycle

```
[Template Selected]
    │
    │ just user-create <username>
    │
    ▼
[Prompting]
    │
    │ Collect: email, fullName
    │
    ▼
[Template Processing]
    │
    │ Substitute placeholders
    │
    ▼
[Key Generation] (optional)
    │
    │ If per-user key selected
    │
    ▼
[User Created]
    │
    ├─► Save key to repo (optional)
    │
    └─► Commit changes (optional)
        │
        ▼
      [Committed]
```

### Secret Field Lifecycle

```
[Defined in Config]
    │
    │ user.field = "<secret>"
    │
    ▼
[Placeholder Set]
    │
    │ just secrets-set <user> <field> <value>
    │
    ▼
[Encrypted]
    │
    │ Activation time
    │
    ▼
[Decrypted & Applied]
    │
    ├─► Updated
    │   │
    │   └─► [Encrypted] (new value)
    │
    └─► Migrated
        │
        │ just secrets-migrate-user <user>
        │
        └─► [Re-encrypted] (new key)
```

## Data Flow

### Secret Creation Flow

```
User Input
    │
    └─► just secrets-set cdrokar email "me@example.com"
         │
         ▼
    Key Detection
         │
         ├─► user/cdrokar/public.age exists? → Use per-user key
         └─► public.age exists? → Use shared key
         │
         ▼
    Encryption
         │
         │ Read: user/cdrokar/secrets.age (if exists)
         │ Decrypt with private key
         │ Update JSON field: {"email": "me@example.com"}
         │ Re-encrypt with public key
         │ Write: user/cdrokar/secrets.age
         │
         ▼
    Config Update
         │
         │ Check: user/cdrokar/default.nix
         │ Has "email" field? Update to "<secret>"
         │ No "email" field? Prompt to add
         │
         ▼
    Complete
```

### Secret Resolution Flow (Activation Time)

```
Home Manager Activation
    │
    └─► secrets-module.nix loads
         │
         ▼
    Key Detection (Nix eval time)
         │
         ├─► user/{username}/public.age exists? → per-user
         └─► public.age exists? → shared
         │
         ▼
    Agenix Registration
         │
         │ age.secrets."user-{username}-secrets" = {
         │   file = user/{username}/secrets.age;
         │ };
         │
         ▼
    Agenix Decryption (activation time)
         │
         │ Decrypt secrets.age → /tmp/agenix/user-{username}-secrets
         │
         ▼
    App Activation Scripts
         │
         │ mkActivationScript {
         │   fields = {
         │     email = ''git config --global user.email "$EMAIL"'';
         │   };
         │ }
         │
         ├─► Detect: config.user.email == "<secret>"
         ├─► Extract: jq -r '.email' /tmp/agenix/user-{username}-secrets
         └─► Execute: git config --global user.email "me@example.com"
         │
         ▼
    Complete
```

### User Creation Flow

```
User Command
    │
    └─► just user-create myuser
         │
         ▼
    Interactive Prompts
         │
         ├─► Email: myuser@example.com (required)
         ├─► Full name: My User (optional)
         ├─► Template: developer (1/2/3/n)
         └─► Key type: per-user (shared/per-user)
         │
         ▼
    Template Processing
         │
         │ Read: user/shared/templates/developer.nix
         │ Replace: REPLACE_USERNAME → myuser
         │ Replace: REPLACE_EMAIL → myuser@example.com
         │ Replace: REPLACE_FULLNAME → My User
         │ Write: user/myuser/default.nix
         │
         ▼
    Key Generation (if per-user)
         │
         │ Generate age keypair
         │ Write public: user/myuser/public.age
         │ Write private: ~/.config/agenix/key-myuser.txt
         │
         ▼
    Git Commit (optional)
         │
         │ git add user/myuser/
         │ git commit -m "feat(user): add myuser"
         │
         ▼
    Save Key to Repo (optional)
         │
         │ Clone ssh-keys repo
         │ Copy private key
         │ Commit to ssh-keys repo
         │
         ▼
    Complete
```

### Migration Flow (Shared → Per-User)

```
User Command
    │
    └─► just secrets-migrate-user cdrokar
         │
         ▼
    Validate Preconditions
         │
         ├─► user/cdrokar/secrets.age exists?
         ├─► ~/.config/agenix/key.txt exists? (shared key)
         └─► NOT user/cdrokar/public.age (already migrated)
         │
         ▼
    Decrypt Current Secrets
         │
         │ age -d -i ~/.config/agenix/key.txt user/cdrokar/secrets.age
         │ Store in memory: {"email": "...", "sshKeys": {...}}
         │
         ▼
    Generate Per-User Key
         │
         │ age-keygen -o ~/.config/agenix/key-cdrokar.txt
         │ Extract public key → user/cdrokar/public.age
         │
         ▼
    Re-Encrypt Secrets
         │
         │ age -r <public-key> -o user/cdrokar/secrets.age
         │ Input: decrypted JSON from memory
         │
         ▼
    Commit Changes
         │
         │ git add user/cdrokar/public.age user/cdrokar/secrets.age
         │ git commit -m "feat(secrets): migrate cdrokar to per-user key"
         │
         ▼
    Complete
         │
         └─► Output: Private key location, distribution instructions
```

## Invariants

1. **Key Uniqueness**: Each user has exactly one active encryption key (either shared or per-user)
1. **Private Key Security**: Private keys NEVER committed to repository
1. **Public Key Availability**: Public keys ALWAYS committed to repository
1. **Secret Placeholder**: Config value "<secret>" ALWAYS has corresponding entry in secrets.age
1. **Path Consistency**: Secret field path in config matches JSON path in secrets.age
1. **No Conflicts**: Cannot have both "field" and "field.nested" as secret placeholders
1. **Backward Compatibility**: Existing shared key users continue to work without changes
1. **Detection Precedence**: Per-user key takes precedence over shared key if both exist

## Validation Rules Summary

### User Creation

- ✅ Username matches `[a-z][a-z0-9-]*`
- ✅ User directory doesn't already exist
- ✅ Email is valid format or "<secret>"
- ✅ Template exists in user/shared/templates/
- ✅ After substitution, no REPLACE\_\* placeholders remain
- ✅ Generated config passes `nix-instantiate --parse`

### Key Management

- ✅ Public key matches age format `age1[a-z0-9]{58}`
- ✅ Private key has permissions 0600
- ✅ Private key location: `~/.config/agenix/`
- ✅ Public key committed to repository
- ✅ Private key NOT in repository

### Secret Operations

- ✅ Field path doesn't conflict with existing paths
- ✅ JSON structure valid after update
- ✅ Encrypted file size < 1MB (sanity check)
- ✅ Decryption succeeds with correct private key
- ✅ Secret value doesn't contain "<secret>" literal

### Migration

- ✅ Source key (shared) exists and valid
- ✅ User secrets.age exists
- ✅ Target key (per-user) doesn't already exist
- ✅ Decrypted JSON structure preserved
- ✅ Re-encryption produces valid age file

## Error Scenarios

### Key Not Found

```
Error: No encryption key found for user cdrokar

Checked:
  - user/cdrokar/public.age (per-user key)
  - public.age (shared key)

Initialize keys with:
  Shared key:    just secrets-init
  Per-user key:  just secrets-init-user cdrokar
```

### Secret Field Missing

```
Error: Secret field not found: 'email'

User: cdrokar
File: user/cdrokar/secrets.age
Config: user.email = "<secret>"

Your secrets file must contain this field.

Fix with:
  just secrets-set cdrokar email "your-email@example.com"
```

### Invalid Template Substitution

```
Error: Template substitution incomplete

File: user/myuser/default.nix
Remaining placeholders:
  - REPLACE_USERNAME
  - REPLACE_EMAIL

This is a bug in the user-create command.
Please report this issue.
```

### Migration Precondition Failed

```
Error: Cannot migrate user cdrokar

Reason: User already uses per-user key
Found: user/cdrokar/public.age

Migration is only for users currently using the shared key.
```

### Key Permission Error

```
Error: Insecure key permissions

File: ~/.config/agenix/key.txt
Permissions: 0644 (should be 0600)

Fix with:
  chmod 600 ~/.config/agenix/key.txt
```
