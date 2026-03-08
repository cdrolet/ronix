# Feature Specification: User Colocated Secrets

**Feature Branch**: `027-user-colocated-secrets`
**Created**: 2025-12-22
**Status**: Draft
**Input**: User description: "since secrets mimic users repo, we should instead move the secret under the user dir itself and get rid of secret structure"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Colocated Secret Files (Priority: P1)

As a user, I want my secrets stored directly in my user directory so that all my configuration is in one place and I don't need to navigate a parallel directory structure.

**Why this priority**: This is the core simplification - secrets live with user configs, not separately.

**Independent Test**: Run `just secrets-edit cdrokar`, add secrets, use `"<secret>"` in `user/cdrokar/default.nix`, verify it resolves correctly.

**Acceptance Scenarios**:

1. **Given** a user config at `user/cdrokar/default.nix` with `email = "<secret>"`, **When** I rebuild, **Then** the system looks for `user/cdrokar/secrets.age`
1. **Given** a new user directory `user/newuser/`, **When** I add `"<secret>"` placeholders, **Then** system expects `user/newuser/secrets.age` (colocated, not in separate secrets dir)
1. **Given** the user directory structure, **When** listing expected secret paths, **Then** they are adjacent: `user/X/default.nix` uses `user/X/secrets.age`

______________________________________________________________________

### User Story 2 - Shared Key Simplicity (Priority: P1)

As a repository maintainer, I want a single shared encryption key for all users so that I only manage one keypair and don't need per-user key infrastructure.

**Why this priority**: Maximum simplicity - one key at repo root, all users trust each other.

**Independent Test**: Verify `public.age` exists at repo root, all `user/*/secrets.age` files are encrypted with this single key.

**Acceptance Scenarios**:

1. **Given** `public.age` at repository root, **When** I run `just secrets-edit cdrokar`, **Then** the wrapper uses this shared key for encryption
1. **Given** multiple users with secrets, **When** checking encryption, **Then** all use the same public key from `public.age`
1. **Given** a new user added to the repo, **When** they create secrets, **Then** no new key generation is needed

______________________________________________________________________

### User Story 3 - Auto-Initialize Secrets Infrastructure (Priority: P1)

As a first-time user, I want the system to automatically set up the shared key and my secrets file on first use so that I don't need to manually configure encryption.

**Why this priority**: Zero-friction onboarding - just run one command and start adding secrets.

**Independent Test**: On fresh repo without `public.age`, run `just secrets-init`, verify keypair is created. Then run `just secrets-edit newuser`, verify `secrets.age` is created.

**Acceptance Scenarios**:

1. **Given** no `public.age` exists at repo root, **When** I run `just secrets-init`, **Then** system generates an age keypair
1. **Given** `just secrets-init` completes, **Then** `public.age` is created at repo root with the public key
1. **Given** `just secrets-init` completes, **Then** private key is stored at `~/.config/agenix/key.txt`
1. **Given** no `secrets.age` exists for a user, **When** I run `just secrets-edit <user>`, **Then** system creates `user/<user>/secrets.age` with empty JSON template `{}`

______________________________________________________________________

### User Story 7 - One-Command Secret Addition (Priority: P1)

As a user, I want to add a secret with a single command so that I don't need to manually edit both my config and secrets file.

**Why this priority**: Maximum convenience - one command updates both files atomically.

**Independent Test**: Run `just secrets-edit cdrokar email "me@example.com"`, verify both `default.nix` has `email = "<secret>";` and `secrets.age` contains the email value.

**Acceptance Scenarios**:

1. **Given** a user config without `email` field, **When** I run `just secrets-edit cdrokar email "me@example.com"`, **Then** `email = "<secret>";` is added to `default.nix` AND `"email": "me@example.com"` is added to `secrets.age`
1. **Given** a user config with `email = "old@example.com"` (plain text), **When** I run `just secrets-edit cdrokar email "new@example.com"`, **Then** the value becomes `email = "<secret>";` in config AND secret is updated
1. **Given** a nested field path, **When** I run `just secrets-edit cdrokar tokens.github "ghp_xxx"`, **Then** `tokens.github = "<secret>";` is added to config AND `{"tokens": {"github": "ghp_xxx"}}` structure is created in secrets
1. **Given** I run `just secrets-edit cdrokar` (no field/value), **Then** the editor opens for manual editing (original behavior)

______________________________________________________________________

### User Story 4 - Simple Secret Placeholder (Priority: P1)

As a user, I want to use `"<secret>"` as a placeholder for any field value so that the system automatically retrieves the encrypted value from my colocated secrets file.

**Why this priority**: This is the core user experience - simple, intuitive secret references.

**Independent Test**: Set `user.email = "<secret>"`, ensure `user/{username}/secrets.age` has email field, rebuild - git should have the correct email.

**Acceptance Scenarios**:

1. **Given** a user config with `email = "<secret>"`, **When** I rebuild, **Then** the system extracts `email` from `user/{username}/secrets.age`
1. **Given** `user.tokens.github = "<secret>"`, **When** I rebuild, **Then** the system extracts `tokens.github` from the secrets file (nested paths work)
1. **Given** any field set to `"<secret>"`, **When** the secrets file exists with that field, **Then** the decrypted value is used

______________________________________________________________________

### User Story 5 - Freeform User Fields (Priority: P1)

As a user, I want to add any field to my user config without modifying the schema definition, so I can store arbitrary secrets like API tokens.

**Why this priority**: Enables extensibility without code changes to core modules.

**Independent Test**: Add `user.tokens.openai = "<secret>"` without any schema changes, verify it works.

**Acceptance Scenarios**:

1. **Given** no schema definition for `user.tokens`, **When** I add `user.tokens.github = "<secret>"`, **Then** the config builds successfully
1. **Given** a deeply nested path `user.services.aws.secretKey = "<secret>"`, **When** I rebuild, **Then** the value is extracted from the secrets file
1. **Given** apps reference `config.user.tokens.github`, **When** the field exists in user config, **Then** apps receive the value (secret or plain text)

______________________________________________________________________

### User Story 6 - Graceful Plain Text Fallback (Priority: P2)

As a user, I want to mix plain text and secret values in the same config, so I can migrate gradually or keep non-sensitive data readable.

**Why this priority**: Enables gradual migration and flexibility.

**Independent Test**: Use plain text for timezone, `"<secret>"` for email - both should work.

**Acceptance Scenarios**:

1. **Given** `email = "<secret>"` and `timezone = "America/Toronto"`, **When** I rebuild, **Then** email comes from secrets file, timezone from plain text
1. **Given** a user with no secrets file, **When** all fields are plain text, **Then** build succeeds without any secret infrastructure
1. **Given** `"<secret>"` used but secrets file missing, **When** I rebuild, **Then** clear error message indicates which file is expected

______________________________________________________________________

### Edge Cases

- What happens when `"<secret>"` is used but `secrets.age` doesn't exist? (Clear error with expected path: `user/{username}/secrets.age`)
- What if secrets file exists but doesn't contain the referenced field? (Error listing missing field)
- What if a field is `"<secret>"` but private key is unavailable? (Decryption error at activation time)
- What about nested fields like `user.git.signingKey`? (JSON supports nesting: `{"git": {"signingKey": "..."}}`)
- What if user has no secrets at all? (No `secrets.age` file needed; plain text config works)
- What if `public.age` is missing at repo root? (Error prompting to run `just secrets-init`)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST store user secrets at `user/{username}/secrets.age` (colocated with user config)
- **FR-002**: System MUST use a single shared public key at `public.age` in repository root
- **FR-003**: System MUST use a single shared private key at `~/.config/agenix/key.txt`
- **FR-004**: System MUST NOT require a central `secrets.nix` file
- **FR-005**: System MUST NOT use a separate `secrets/` directory structure
- **FR-006**: Wrapper commands MUST dynamically generate agenix rules from `public.age`
- **FR-007**: System MUST auto-initialize shared keypair via `just secrets-init` command
- **FR-008**: System MUST auto-create `secrets.age` with empty JSON when user runs `just secrets-edit` for first time
- **FR-016**: `just secrets-edit <user> <field> <value>` MUST add `field = "<secret>";` to user's `default.nix` AND add field/value to `secrets.age`
- **FR-017**: `just secrets-edit <user>` (no field/value) MUST open editor for manual secrets editing
- **FR-018**: Nested field paths (e.g., `tokens.github`) MUST be supported in one-command mode
- **FR-009**: System MUST support `"<secret>"` placeholder string for any user config field
- **FR-010**: User schema MUST use freeformType to allow arbitrary fields without schema changes
- **FR-011**: Core user fields (name, email, fullName, timezone, locale) MUST remain documented with proper types
- **FR-012**: Applications MUST reference `config.user.*` for all user-specific values
- **FR-013**: System MUST support both `"<secret>"` and plain text values in the same config file
- **FR-014**: System MUST fail with clear error message when secrets file or field is missing
- **FR-015**: Secret files MUST use JSON format with field names matching user config attribute paths

### Key Entities

- **User Directory**: Self-contained configuration at `user/{username}/` including `default.nix` and optionally `secrets.age`
- **Secrets File**: Encrypted JSON at `user/{username}/secrets.age` containing secret field values
- **Shared Public Key**: Age public key at repository root `public.age` used for all encryption
- **Shared Private Key**: Age private key at `~/.config/agenix/key.txt` used for all decryption
- **Secret Placeholder**: The string `"<secret>"` used in user configs to indicate encrypted value

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add secrets with just `field = "<secret>"` - no path configuration needed
- **SC-002**: All user secrets files exist in their respective `user/{name}/` directories
- **SC-003**: Only one public key file exists (`public.age` at repo root)
- **SC-004**: No `secrets.nix` file exists in the repository
- **SC-005**: No `secrets/` directory exists in the repository
- **SC-006**: Adding new secret fields requires zero schema changes (freeform works)
- **SC-007**: Mixed plain text and secrets work in the same config file
- **SC-008**: First-time setup requires: `just secrets-init` (once), then `just secrets-edit <user> <field> <value>`
- **SC-010**: Adding a secret requires single command: `just secrets-edit <user> <field> <value>` (updates both config and secrets)
- **SC-009**: Adding a new user with secrets requires zero edits to any file outside their `user/` directory

## Design Decision: Shared Key Model

This repository uses a **single shared encryption key** for all user secrets. This is a deliberate simplification based on the trust model of this repository.

### How It Works

```
public.age                    # Shared public key (repo root, committed)
~/.config/agenix/key.txt      # Shared private key (local, not committed)

user/
  cdrokar/
    default.nix               # User config
    secrets.age               # Encrypted with shared key
  cdrolet/
    default.nix
    secrets.age               # Same shared key
```

### Why This Pattern

| Benefit | Description |
|---------|-------------|
| Simplicity | One keypair to manage, not N |
| No user registry | Adding users doesn't require editing central files |
| Easy onboarding | Same private key works for all users |
| Less infrastructure | No per-user key generation or distribution |

### Limitations (Documented Trade-offs)

| Limitation | Implication |
|------------|-------------|
| No per-user revocation | Cannot revoke one user's access without rotating the shared key |
| Shared private key | All machines need the same `~/.config/agenix/key.txt` |
| All-or-nothing access | Anyone with the private key can decrypt all user secrets |
| Single point of compromise | If key leaks, all secrets are exposed |

### When to Consider Per-User Keys

This shared-key model is appropriate when:

- All users trust each other (same person, family, close team)
- All machines are controlled by trusted parties
- Revoking individual user access is not a requirement

If your use case requires:

- Revoking individual user access
- Untrusted users sharing the same repo
- Strict access control per user

...then you should implement per-user keys with `user/{name}/public.age` instead. This would require modifying the wrapper commands to read per-user keys.

## Assumptions

- This feature supersedes spec 026's directory structure
- All users in this repository trust each other
- The shared private key is distributed to all authorized machines out-of-band
- Platform-specific secrets (if needed later) would use the same shared key
- agenix is the secrets management tool
- Wrapper commands handle all agenix complexity (user never runs raw `agenix` commands)
