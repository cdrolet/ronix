# Data Model: User Colocated Secrets

**Feature**: 027-user-colocated-secrets
**Date**: 2025-12-22

## Overview

This document defines the data structures and relationships for the colocated secrets system.

______________________________________________________________________

## Entities

### 1. Shared Key Pair

The repository uses a single age keypair for all secret encryption/decryption.

**Public Key File** (`public.age`):

```
Location: {repo_root}/public.age
Format: Plain text, single line
Content: age public key (e.g., "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p")
Committed: Yes
```

**Private Key File** (`~/.config/agenix/key.txt`):

```
Location: ~/.config/agenix/key.txt
Format: Plain text, age secret key format
Content: AGE-SECRET-KEY-1... (single line)
Committed: No (distributed out-of-band)
```

### 2. User Secrets File

Each user may have an encrypted secrets file containing their sensitive data.

**File**: `user/{username}/secrets.age`

```
Location: user/{username}/secrets.age
Format: Age-encrypted JSON
Encryption: Uses public key from public.age
Required: No (only if user has "<secret>" placeholders)
```

**Decrypted Content Structure** (JSON):

```json
{
  "email": "string",
  "fullName": "string",
  "git": {
    "signingKey": "string"
  },
  "tokens": {
    "github": "string",
    "openai": "string"
  }
}
```

**Schema Rules**:

- Top-level keys map to `user.{key}` in Nix config
- Nested objects map to `user.{parent}.{child}` paths
- All values are strings (Nix handles type coercion)
- Empty object `{}` is valid (no secrets defined)

### 3. User Configuration

User configuration files that may contain secret placeholders.

**File**: `user/{username}/default.nix`

```nix
{ ... }:
{
  user = {
    name = "cdrokar";                    # Required, plain text
    email = "<secret>";                  # Secret placeholder
    fullName = "<secret>";               # Secret placeholder
    timezone = "America/Toronto";        # Plain text
    
    # Freeform fields (not in schema)
    tokens.github = "<secret>";          # Nested secret
    git.signingKey = "<secret>";         # Nested secret
  };
}
```

**Placeholder Syntax**:

- Literal string: `"<secret>"`
- Case sensitive
- Triggers secret resolution at activation time

### 4. User Schema (Nix Module)

The user option schema with freeform support.

**Location**: `user/shared/lib/` or platform libs

```nix
options.user = lib.mkOption {
  type = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    
    options = {
      # Required
      name = lib.mkOption {
        type = lib.types.str;
        description = "Username for the configuration";
      };
      
      # Optional with defaults
      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "User email address (can be '<secret>')";
      };
      
      fullName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "User's full name (can be '<secret>')";
      };
      
      timezone = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "User timezone";
      };
      
      locale = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "User locale";
      };
      
      # Freeform handles: tokens.*, git.*, services.*, etc.
    };
  };
};
```

______________________________________________________________________

## Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                     Repository Root                          │
├─────────────────────────────────────────────────────────────┤
│  public.age ─────────────────────────────────────────────┐  │
│       │                                                   │  │
│       │ encrypts                                          │  │
│       ▼                                                   │  │
│  ┌─────────────────────────────────────────────────────┐ │  │
│  │                    user/                             │ │  │
│  ├─────────────────────────────────────────────────────┤ │  │
│  │  cdrokar/                                           │ │  │
│  │  ├── default.nix ──── references ──► secrets.age    │ │  │
│  │  │   (email = "<secret>")           (encrypted JSON)│ │  │
│  │  └── secrets.age ◄────────────────────────────────┘ │  │
│  │                                                      │  │
│  │  cdrolet/                                           │  │
│  │  ├── default.nix ──── references ──► secrets.age   │  │
│  │  └── secrets.age                                    │  │
│  │                                                      │  │
│  │  shared/lib/                                        │  │
│  │  └── secrets.nix  (resolution helpers)              │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

Local Machine (not in repo):
┌─────────────────────────────────────────────────────────────┐
│  ~/.config/agenix/key.txt                                   │
│       │                                                      │
│       │ decrypts                                             │
│       ▼                                                      │
│  All user/*/secrets.age files                               │
└─────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## State Transitions

### Secret File Lifecycle

```
                    ┌──────────────┐
                    │  Not Exists  │
                    └──────┬───────┘
                           │
            just secrets-edit <user>
            (auto-creates empty {})
                           │
                           ▼
                    ┌──────────────┐
                    │    Empty     │
                    │     {}       │
                    └──────┬───────┘
                           │
            just secrets-edit <user>
            (user adds fields)
                           │
                           ▼
                    ┌──────────────┐
                    │  Populated   │◄─────────────┐
                    │ {email:...}  │              │
                    └──────┬───────┘              │
                           │                      │
            just secrets-edit <user>              │
            (user modifies)                       │
                           └──────────────────────┘
```

### Secret Resolution Flow

```
     Nix Evaluation                    Activation
    ┌─────────────┐                 ┌─────────────┐
    │             │                 │             │
    │ user.email  │                 │  agenix     │
    │ = "<secret>"│─────────────────│  decrypts   │
    │             │   registered    │  secrets.age│
    │             │   as age.secret │             │
    └─────────────┘                 └──────┬──────┘
                                           │
                                           ▼
                                   ┌─────────────┐
                                   │ Activation  │
                                   │   Script    │
                                   │             │
                                   │ jq .email   │
                                   │ git config  │
                                   └─────────────┘
```

______________________________________________________________________

## Validation Rules

### Public Key File

- Must exist before any `secrets-edit` operation
- Must be valid age public key format: `age1...`
- Single line, no trailing whitespace

### Secrets File (JSON)

- Must be valid JSON when decrypted
- Keys must be valid Nix attribute names (alphanumeric, underscores)
- Values must be strings
- Nested objects allowed for dotted paths (`tokens.github`)

### User Config

- `"<secret>"` must match exactly (case sensitive)
- If `"<secret>"` used, corresponding `secrets.age` must exist
- Referenced field must exist in secrets JSON

### Path Mapping

| User Config Path | JSON Path |
|------------------|-----------|
| `user.email` | `email` |
| `user.fullName` | `fullName` |
| `user.tokens.github` | `tokens.github` |
| `user.git.signingKey` | `git.signingKey` |
| `user.services.aws.key` | `services.aws.key` |

______________________________________________________________________

## Example: Complete User Setup

**user/cdrokar/default.nix**:

```nix
{ ... }:
{
  user = {
    name = "cdrokar";
    email = "<secret>";
    fullName = "<secret>";
    timezone = "America/Toronto";
    locale = "en_CA.UTF-8";
    
    git.signingKey = "<secret>";
    tokens = {
      github = "<secret>";
      openai = "<secret>";
    };
  };
}
```

**user/cdrokar/secrets.age** (decrypted):

```json
{
  "email": "cdrokar@pm.me",
  "fullName": "Charles Drokar",
  "git": {
    "signingKey": "ABCD1234..."
  },
  "tokens": {
    "github": "ghp_xxxxxxxxxxxx",
    "openai": "sk-xxxxxxxxxxxx"
  }
}
```

**Resolution at Activation**:

```
config.user.email       → "cdrokar@pm.me"
config.user.fullName    → "Charles Drokar"
config.user.timezone    → "America/Toronto" (plain text, no resolution)
config.user.git.signingKey → "ABCD1234..."
config.user.tokens.github  → "ghp_xxxxxxxxxxxx"
```
