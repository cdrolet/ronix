# Data Model: Nested Secrets Support

**Feature**: 029-nested-secrets-support
**Date**: 2025-12-26

## Entities

### 1. Nested Secret Path

A dotted string representing the path to a value in nested structures.

**Attributes**:
| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| pathString | string | Dotted notation path | `"sshKeys.personal"` |
| pathList | list[string] | Nix attribute path list | `["sshKeys", "personal"]` |
| depth | integer | Number of path segments | `2` |

**Validation Rules**:

- Path segments must not be empty
- Path must not start or end with dot
- Maximum depth: 4 levels (soft limit, can be extended)
- No array indices (e.g., `keys[0]` not supported)

**Conversions**:

```
pathString ↔ pathList
"sshKeys.personal" ↔ ["sshKeys", "personal"]
"email" ↔ ["email"]
"tokens.api.github.readonly" ↔ ["tokens", "api", "github", "readonly"]
```

### 2. Shell Variable Name

A safe shell variable name derived from a nested path.

**Attributes**:
| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| varName | string | Uppercase with underscores | `"SSHKEYS_PERSONAL"` |
| sourcePath | string | Original dotted path | `"sshKeys.personal"` |

**Transformation Rules**:

1. Replace dots with underscores
1. Convert to uppercase
1. Result must be valid POSIX variable name

**Examples**:
| Nested Path | Shell Variable |
|-------------|----------------|
| `email` | `EMAIL` |
| `sshKeys.personal` | `SSHKEYS_PERSONAL` |
| `tokens.api.github` | `TOKENS_API_GITHUB` |

### 3. User Config Attribute

A Nix attribute in `config.user.*` that may contain nested structures.

**Attributes**:
| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| path | list[string] | Attribute path from user root | `["sshKeys", "personal"]` |
| value | any | The attribute value | `"<secret>"` or `"plain-text"` |
| isSecret | boolean | Whether value is placeholder | `true` |

**State Diagram**:

```
[Plain Text] ←→ [Secret Placeholder "<secret>"]
     ↓                    ↓
  [Used as-is]    [Resolved at activation]
```

### 4. JSON Secret Structure

The encrypted JSON object in `user/{name}/secrets.age`.

**Schema** (example):

```json
{
  "email": "user@example.com",
  "fullName": "User Name",
  "sshKeys": {
    "personal": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
    "work": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
    "github": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
  },
  "tokens": {
    "github": "ghp_xxxx",
    "openai": "sk-xxxx"
  }
}
```

**Validation Rules**:

- Must be valid JSON
- Top-level must be an object (not array)
- Values must be strings or nested objects
- No arrays at any level (current limitation)
- Nested depth matches config.user structure

### 5. Field Mapping

The relationship between config path, JSON path, and shell variable.

**Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| configPath | list[string] | Nix path from config.user |
| jsonPath | string | Dotted path in JSON |
| varName | string | Shell variable name |
| applyCommand | string | Shell command to apply secret |

**Example Mappings**:
| Config Path | JSON Path | Variable | Apply Command |
|-------------|-----------|----------|---------------|
| `["email"]` | `email` | `EMAIL` | `git config user.email "$EMAIL"` |
| `["sshKeys", "personal"]` | `sshKeys.personal` | `SSHKEYS_PERSONAL` | `echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_ed25519` |
| `["tokens", "github"]` | `tokens.github` | `TOKENS_GITHUB` | `gh auth login --with-token <<< "$TOKENS_GITHUB"` |

## Relationships

```
User Config (Nix)           secrets.age (JSON)           Activation (Shell)
─────────────────           ──────────────────           ──────────────────
config.user.email     ←──→  {"email": "..."}       ──→   $EMAIL
config.user.sshKeys   ←──→  {"sshKeys": {...}}     ──→   $SSHKEYS_*
  .personal           ←──→    {"personal": "..."}  ──→   $SSHKEYS_PERSONAL
  .work               ←──→    {"work": "..."}      ──→   $SSHKEYS_WORK
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Evaluation Time                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  user/cdrokar/default.nix                                          │
│  ┌─────────────────────────────┐                                   │
│  │ user = {                    │                                   │
│  │   sshKeys.personal = "<secret>";                                │
│  │ };                          │                                   │
│  └─────────────────────────────┘                                   │
│              │                                                      │
│              ▼                                                      │
│  ┌─────────────────────────────┐                                   │
│  │ secrets.isSecret detects    │                                   │
│  │ "<secret>" at nested path   │                                   │
│  └─────────────────────────────┘                                   │
│              │                                                      │
│              ▼                                                      │
│  ┌─────────────────────────────┐                                   │
│  │ mkActivationScript builds   │                                   │
│  │ shell script with jq        │                                   │
│  │ extraction commands         │                                   │
│  └─────────────────────────────┘                                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                          Activation Time                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. agenix decrypts secrets.age to /run/agenix/...                 │
│                                                                     │
│  2. Activation script runs:                                         │
│     ┌─────────────────────────────────────────────────────────┐    │
│     │ SSHKEYS_PERSONAL=$(jq -r                                │    │
│     │   'getpath("sshKeys.personal" | split(".")) // empty'   │    │
│     │   "$SECRETS_FILE")                                      │    │
│     │                                                         │    │
│     │ echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_ed25519           │    │
│     └─────────────────────────────────────────────────────────┘    │
│                                                                     │
│  3. Secret deployed to final location                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Backward Compatibility

The nested secret model is a superset of the flat secret model:

| Aspect | Flat (Feature 027) | Nested (Feature 029) |
|--------|-------------------|---------------------|
| Config | `email = "<secret>"` | `email = "<secret>"` (unchanged) |
| JSON | `{"email": "..."}` | `{"email": "..."}` (unchanged) |
| Path | `"email"` | `"email"` (same format) |
| Variable | `$EMAIL` | `$EMAIL` (unchanged) |

**Key Insight**: Flat paths are just nested paths with depth=1. No migration needed.
