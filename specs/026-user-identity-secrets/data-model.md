# Data Model: User Identity Secrets

**Feature**: 026-user-identity-secrets
**Date**: 2025-12-21

## Entities

### Secret Placeholder

The sentinel string that triggers secret resolution.

| Field | Type | Value | Description |
|-------|------|-------|-------------|
| value | String | `"<secret>"` | Literal string used in user configs |

### Age Key Pair

Cryptographic key pair for encrypting/decrypting secrets.

| Field | Type | Description |
|-------|------|-------------|
| publicKey | String | Age public key (`age1...`) stored in secrets.nix |
| privateKeyPath | Path | `~/.config/agenix/key.txt` |
| owner | String | Username who owns this key pair |

### Secret File

Encrypted JSON file containing user secret values.

| Field | Type | Description |
|-------|------|-------------|
| sourcePath | Path | Corresponding user config (`user/{username}/default.nix`) |
| secretPath | Path | Encrypted file (`secrets/user/{username}/default.age`) |
| content | JSON | Decrypted content with field values |
| authorizedKeys | [String] | Age public keys that can decrypt |

### User Config (Freeform)

User configuration with documented and freeform fields.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | String | Yes | Username (must match system) |
| email | String? | No | Email or `"<secret>"` |
| fullName | String? | No | Display name or `"<secret>"` |
| timezone | String? | No | IANA timezone |
| locale | String? | No | POSIX locale |
| languages | [String]? | No | Language preferences |
| keyboardLayout | [String]? | No | Keyboard layouts |
| applications | [String]? | No | App list |
| docked | [String] | No | Dock items |
| **(freeform)** | Any | No | Any additional fields (e.g., `git.*`, `tokens.*`) |

## Path Mirroring

### Mapping Rules

```
Source Path                      →  Secret Path
─────────────────────────────────────────────────────────────
user/cdrokar/default.nix         →  secrets/user/cdrokar/default.age
user/cdrolet/default.nix         →  secrets/user/cdrolet/default.age
user/cdrixus/default.nix         →  secrets/user/cdrixus/default.age
```

### Derivation Function

```nix
deriveSecretPath = sourcePath:
  let
    relative = lib.removePrefix "user/" sourcePath;
    withoutExt = lib.removeSuffix ".nix" relative;
  in
    "secrets/user/${withoutExt}.age";
```

## Secret File Format

### JSON Structure

```json
{
  "email": "user@example.com",
  "fullName": "User Name",
  "git": {
    "signingKey": "ABC123..."
  },
  "tokens": {
    "github": "ghp_...",
    "openai": "sk-...",
    "anthropic": "sk-ant-..."
  }
}
```

### Field Path Mapping

| User Config Path | JSON Path | Example Value |
|------------------|-----------|---------------|
| `user.email` | `email` | `"user@example.com"` |
| `user.fullName` | `fullName` | `"User Name"` |
| `user.git.signingKey` | `git.signingKey` | `"ABC123..."` |
| `user.tokens.github` | `tokens.github` | `"ghp_..."` |

## secrets.nix Structure

```nix
let
  # User public keys
  cdrokar = "age1abc...";
  cdrolet = "age1def...";
  cdrixus = "age1ghi...";
in {
  # Each user's secrets are only decryptable by them
  "user/cdrokar/default.age".publicKeys = [ cdrokar ];
  "user/cdrolet/default.age".publicKeys = [ cdrolet ];
  "user/cdrixus/default.age".publicKeys = [ cdrixus ];
}
```

## State Diagram

### Secret Resolution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER CONFIG EVALUATION                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ Scan for "<secret>" │
                    │    placeholders     │
                    └─────────┬───────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
    ┌─────────────────┐             ┌─────────────────┐
    │ No "<secret>"   │             │ Has "<secret>"  │
    │ placeholders    │             │ placeholders    │
    └────────┬────────┘             └────────┬────────┘
             │                               │
             ▼                               ▼
    ┌─────────────────┐             ┌─────────────────┐
    │ Use plain text  │             │ Derive secret   │
    │ values directly │             │ path from source│
    └─────────────────┘             └────────┬────────┘
                                             │
                                             ▼
                                    ┌─────────────────┐
                                    │ Register with   │
                                    │ age.secrets     │
                                    └────────┬────────┘
                                             │
                                             ▼
                              ┌──────────────────────────┐
                              │    ACTIVATION TIME       │
                              └──────────────────────────┘
                                             │
                                             ▼
                                    ┌─────────────────┐
                                    │ agenix decrypts │
                                    │ to runtime path │
                                    └────────┬────────┘
                                             │
                                             ▼
                                    ┌─────────────────┐
                                    │ Read JSON, get  │
                                    │ field values    │
                                    └────────┬────────┘
                                             │
                                             ▼
                                    ┌─────────────────┐
                                    │ Apply to apps   │
                                    │ (git, etc.)     │
                                    └─────────────────┘
```

### User Directory Discovery

```
┌─────────────────┐
│   user/         │
│   ├── cdrokar/  │──────► expects: secrets/user/cdrokar/default.age
│   ├── cdrolet/  │──────► expects: secrets/user/cdrolet/default.age
│   ├── cdrixus/  │──────► expects: secrets/user/cdrixus/default.age
│   └── shared/   │──────► (ignored - not a user)
└─────────────────┘
```

## Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER CONFIG                               │
│  user/cdrokar/default.nix                                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ user = {                                                 │    │
│  │   name = "cdrokar";           ← plain text              │    │
│  │   email = "<secret>";         ← triggers lookup         │    │
│  │   fullName = "<secret>";      ← triggers lookup         │    │
│  │   tokens.github = "<secret>"; ← triggers lookup         │    │
│  │   timezone = "America/Toronto"; ← plain text            │    │
│  │ }                                                        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ mirrors to
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        SECRET FILE                               │
│  secrets/user/cdrokar/default.age (decrypted)                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ {                                                        │    │
│  │   "email": "cdrokar@pm.me",                             │    │
│  │   "fullName": "Charles Drokar",                         │    │
│  │   "tokens": {                                           │    │
│  │     "github": "ghp_..."                                 │    │
│  │   }                                                      │    │
│  │ }                                                        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ authorized by
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      secrets/secrets.nix                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ "user/cdrokar/default.age".publicKeys = [ cdrokar ];    │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ decrypted by
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AGE PRIVATE KEY                             │
│  ~/.config/agenix/key.txt                                       │
└─────────────────────────────────────────────────────────────────┘
```

## Freeform Schema Type

```nix
# user/shared/lib/home-manager.nix
options.user = lib.mkOption {
  type = lib.types.submodule {
    # Allow ANY attribute without schema changes
    freeformType = lib.types.attrsOf lib.types.anything;
    
    # Documented fields with proper types
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Username (must match system user)";
      };
      
      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Email address. Use '<secret>' for encrypted value.";
      };
      
      fullName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Full display name. Use '<secret>' for encrypted value.";
      };
      
      # ... other documented fields (timezone, locale, etc.)
    };
  };
};
```
