# Feature Specification: User Identity Secrets

**Feature Branch**: `026-user-identity-secrets`
**Created**: 2025-12-21
**Status**: Draft
**Input**: User description: "Store user email and fullName as encrypted secrets using agenix"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Simple Secret Placeholder (Priority: P1)

As a user, I want to use `"<secret>"` as a placeholder for any field value so that the system automatically retrieves the encrypted value from the corresponding secret file.

**Why this priority**: This is the core user experience - simple, intuitive, zero-configuration secrets.

**Independent Test**: Set `user.email = "<secret>"`, create the corresponding secret file, rebuild - git should have the correct email.

**Acceptance Scenarios**:

1. **Given** a user config with `email = "<secret>"`, **When** I rebuild, **Then** the system looks in `secrets/user/cdrokar/default.age` for the `email` field
1. **Given** any field set to `"<secret>"`, **When** the secret file exists with that field, **Then** the decrypted value is used
1. **Given** `user.tokens.github = "<secret>"`, **When** I rebuild, **Then** the system extracts `tokens.github` from the secret file (nested paths work)

______________________________________________________________________

### User Story 2 - Mirror Path Discovery (Priority: P1)

As a user, I don't want to configure secret file paths - they should be automatically derived from the source file location.

**Why this priority**: Eliminates configuration overhead and ensures consistency.

**Independent Test**: Create `user/newuser/default.nix`, the system should expect secrets at `secrets/user/newuser/default.age`.

**Acceptance Scenarios**:

1. **Given** a user config at `user/cdrokar/default.nix`, **When** secrets are needed, **Then** system looks at `secrets/user/cdrokar/default.age`
1. **Given** a new user directory `user/newuser/`, **When** I use `"<secret>"` placeholders, **Then** system expects `secrets/user/newuser/default.age` (no manual setup)
1. **Given** the user directory structure, **When** listing expected secret paths, **Then** they mirror exactly: `user/X/Y.nix` → `secrets/user/X/Y.age`

______________________________________________________________________

### User Story 3 - Freeform User Fields (Priority: P1)

As a user, I want to add any field to my user config without modifying the schema definition, so I can store arbitrary secrets like API tokens.

**Why this priority**: Enables extensibility without code changes to core modules.

**Independent Test**: Add `user.tokens.openai = "<secret>"` without any schema changes, verify it works.

**Acceptance Scenarios**:

1. **Given** no schema definition for `user.tokens`, **When** I add `user.tokens.github = "<secret>"`, **Then** the config builds successfully
1. **Given** a deeply nested path `user.services.aws.secretKey = "<secret>"`, **When** I rebuild, **Then** the value is extracted from the secret file
1. **Given** apps reference `config.user.tokens.github`, **When** the field exists in user config, **Then** apps receive the value (secret or plain text)

______________________________________________________________________

### User Story 4 - Initialize Secrets Infrastructure (Priority: P1)

As a repository maintainer, I want to set up agenix with real age keys so that I can encrypt and decrypt user secrets.

**Why this priority**: Prerequisite for all other stories.

**Independent Test**: Generate age key, add to secrets.nix, encrypt a secret file, verify decryption works.

**Acceptance Scenarios**:

1. **Given** a fresh system, **When** I run `age-keygen -o ~/.config/agenix/key.txt`, **Then** an age key pair is created
1. **Given** age keys exist, **When** I run `agenix -e secrets/user/cdrokar/default.age`, **Then** I can edit the encrypted content
1. **Given** secrets.nix with real public keys, **When** I encrypt a secret, **Then** only authorized keys can decrypt it

______________________________________________________________________

### User Story 5 - Graceful Plain Text Fallback (Priority: P2)

As a user, I want to mix plain text and secret values in the same config, so I can migrate gradually or keep non-sensitive data readable.

**Why this priority**: Enables gradual migration and flexibility.

**Independent Test**: Use plain text for timezone, `"<secret>"` for email - both should work.

**Acceptance Scenarios**:

1. **Given** `email = "<secret>"` and `timezone = "America/Toronto"`, **When** I rebuild, **Then** email comes from secret, timezone from plain text
1. **Given** a user with no secret file, **When** all fields are plain text, **Then** build succeeds without any secret infrastructure
1. **Given** `"<secret>"` used but secret file missing, **When** I rebuild, **Then** clear error message indicates which file is missing

______________________________________________________________________

### Edge Cases

- What happens when `"<secret>"` is used but secret file doesn't exist? (Clear error with expected path)
- What if secret file exists but doesn't contain the referenced field? (Error listing missing field)
- What if a field is `"<secret>"` but age key is unavailable? (Decryption error at activation)
- What about nested fields like `user.git.signingKey`? (JSON supports nesting: `{"git": {"signingKey": "..."}}`)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST integrate agenix into the flake for secret management
- **FR-002**: System MUST support `"<secret>"` placeholder string for any user config field
- **FR-003**: System MUST auto-derive secret file path by mirroring source path: `user/X/Y.nix` → `secrets/user/X/Y.age`
- **FR-004**: System MUST auto-discover user directories and expect corresponding secret paths (no manual registration)
- **FR-005**: User schema MUST use freeformType to allow arbitrary fields without schema changes
- **FR-006**: Core user fields (name, email, fullName, timezone, locale) MUST remain documented with proper types
- **FR-007**: Applications MUST reference `config.user.*` for all user-specific values (secrets live only in user config)
- **FR-008**: System MUST support both `"<secret>"` and plain text values in the same config file
- **FR-009**: System MUST fail with clear error message when secret file or field is missing
- **FR-010**: Secret files MUST use JSON format with field names matching user config attribute paths
- **FR-011**: System MUST document the key generation and secret creation process

### Key Entities

- **Age Key Pair**: Public key (in secrets.nix) and private key (`~/.config/agenix/key.txt`)
- **Secret File**: Encrypted JSON at `secrets/user/{username}/default.age` containing secret field values
- **Secret Placeholder**: The string `"<secret>"` used in user configs to indicate encrypted value
- **secrets.nix**: Central mapping of age public keys to secret files

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add secrets with just `field = "<secret>"` - no path configuration needed
- **SC-002**: Adding a new user directory automatically establishes the expected secret path
- **SC-003**: Adding new secret fields requires zero schema changes (freeform works)
- **SC-004**: Mixed plain text and secrets work in the same config file
- **SC-005**: All three existing users (cdrokar, cdrolet, cdrixus) successfully migrated
- **SC-006**: New user onboarding: add `"<secret>"`, create `.age` file, done (3 steps)

## Prerequisites

### Required (One-Time Setup)

1. **Generate age key on each machine**:

   ```bash
   just secrets-init
   # Or manually: mkdir -p ~/.config/agenix && age-keygen -o ~/.config/agenix/key.txt
   ```

1. **Register public key in secrets.nix**:

   ```bash
   just secrets-show-pubkey
   # Copy output to secrets/secrets.nix
   ```

### Optional (Convenience)

- **Add CLI tools to user packages**: Include `pkgs.age` and `pkgs.agenix` in `home.packages` for convenient secret management without `nix shell`

## Justfile Commands

The following commands will be added for secret management:

| Command | Description |
|---------|-------------|
| `just secrets-init` | Generate age key at `~/.config/agenix/key.txt` |
| `just secrets-show-pubkey` | Display public key for secrets.nix |
| `just secrets-edit <user>` | Edit user's secret file (auto-rekeys after) |
| `just secrets-rekey` | Re-encrypt all secrets (manual, if needed) |
| `just secrets-list` | List all secret files and their status |

## Assumptions

- Secrets are user-specific (apps reference `config.user.*`, never contain secrets directly)
- One secret file per user (`secrets/user/{username}/default.age`) contains all their secrets
- Each deployment machine has access to the user's age private key
- agenix is the preferred secrets solution (already in existing infrastructure)
