# Feature Specification: Multi-Provider Repository Support

**Feature Branch**: `038-multi-provider-repositories`\
**Created**: 2026-01-04\
**Status**: Draft\
**Input**: User description: "change 032-user-git-repos so user.repositories can be used to other remote repository providers than git (such as s3, proton-drive, etc..) . this mean the schema is not specific to git-repo anymore and should be part of user-schema. git-repo will simply rend the entries and only threat the ones that applied to git while ignoring the others"

## User Scenarios & Testing

### User Story 1 - Git Repository Synchronization (Priority: P1)

User configures git repositories in their user configuration and the system automatically clones/updates them during activation, maintaining existing git-repos functionality.

**Why this priority**: Core functionality that already exists - must maintain backward compatibility and ensure existing users aren't disrupted.

**Independent Test**: Can be fully tested by configuring git repositories in user config and verifying they are cloned/updated during system activation, delivers existing git-repos feature value.

**Acceptance Scenarios**:

1. **Given** user has git repositories configured with URLs, **When** system activates, **Then** repositories are cloned to specified paths
1. **Given** user has existing cloned repositories, **When** system activates with updated config, **Then** repositories are updated via git pull
1. **Given** user removes a repository from config, **When** system activates, **Then** the repository remains on disk (no deletion)

______________________________________________________________________

### User Story 2 - S3 Bucket Synchronization (Priority: P2)

User configures S3 buckets in their repository list and the system synchronizes files from S3 to local directories during activation.

**Why this priority**: First new provider implementation that validates the multi-provider architecture, enables cloud backup/sync use case.

**Independent Test**: Can be tested independently by configuring S3 bucket URLs and verifying files are downloaded to local paths using s3 sync tools.

**Acceptance Scenarios**:

1. **Given** user has S3 bucket configured with credentials, **When** system activates, **Then** files are synchronized from S3 to local directory
1. **Given** user has existing local files, **When** S3 bucket has updates, **Then** only changed files are downloaded
1. **Given** S3 credentials are invalid, **When** system activates, **Then** error is logged and other repositories continue processing

______________________________________________________________________

### User Story 3 - Proton Drive Synchronization (Priority: P3)

User configures Proton Drive folders in their repository list and the system synchronizes encrypted files from Proton Drive to local directories.

**Why this priority**: Demonstrates privacy-focused provider support, validates architecture with authenticated cloud storage.

**Independent Test**: Can be tested independently by configuring Proton Drive URLs and verifying encrypted files are synced using Proton Drive client tools.

**Acceptance Scenarios**:

1. **Given** user has Proton Drive folder configured with auth, **When** system activates, **Then** files are synchronized from Proton Drive to local directory
1. **Given** Proton Drive requires authentication, **When** credentials are provided via secrets, **Then** authentication succeeds and sync proceeds
1. **Given** network is unavailable, **When** system activates, **Then** Proton Drive sync is skipped with warning logged

______________________________________________________________________

### User Story 4 - Generic Provider Extensibility (Priority: P4)

Developer can add support for a new repository provider by implementing a provider-specific handler without modifying the core schema or activation logic.

**Why this priority**: Future-proofing the architecture - enables community contributions and custom providers.

**Independent Test**: Can be tested by implementing a new provider handler (e.g., Dropbox, rsync) and verifying it integrates without core changes.

**Acceptance Scenarios**:

1. **Given** a new provider type is defined, **When** user configures repository with that type, **Then** provider-specific handler is invoked
1. **Given** provider handler returns success, **When** activation completes, **Then** repository is marked as synchronized
1. **Given** provider is not recognized, **When** system encounters it, **Then** repository is skipped with warning about unknown provider

______________________________________________________________________

### Edge Cases

- What happens when a repository URL cannot be auto-detected to a known provider type?
- What happens when a repository URL is malformed or inaccessible?
- How does the system handle multiple providers requiring different authentication methods?
- What occurs when a provider handler fails mid-sync (partial download)?
- How does the system prioritize repositories when multiple providers are configured?
- What happens when the same local path is specified for repositories from different providers?
- How are provider-specific options (git branch, S3 region, etc.) handled in the unified schema?
- What happens when user specifies explicit provider type that conflicts with URL pattern?

## Requirements

### Functional Requirements

- **FR-001**: System MUST define a provider-agnostic repository schema in user-schema.nix that supports multiple repository types
- **FR-002**: System MUST automatically detect provider type from URL pattern (git URLs, s3:// URIs, proton-drive:// paths)
- **FR-003**: Schema MUST include optional explicit provider field for ambiguous URLs or custom providers
- **FR-004**: Schema MUST include fields common to all providers: URL/location, local path, authentication reference
- **FR-005**: System MUST allow provider-specific configuration options while maintaining schema consistency
- **FR-006**: Git-repos activation script MUST filter repositories by detected/specified provider type (git) and ignore non-git repositories
- **FR-007**: System MUST process repositories during user activation in a provider-aware manner
- **FR-008**: Each provider handler MUST be independently implementable without modifying core schema
- **FR-009**: System MUST log clear messages indicating which provider is handling each repository
- **FR-010**: Failed repository sync MUST NOT block other repositories from syncing
- **FR-011**: System MUST validate repository configuration at evaluation time (provider detection, required fields)
- **FR-012**: Authentication for each provider type MUST integrate with existing agenix secrets system
- **FR-013**: System MUST maintain backward compatibility with existing git-repos configurations
- **FR-014**: Provider handlers MUST be idempotent (safe to run multiple times)

### Key Entities

- **Repository**: Represents a remote data source to be synchronized locally

  - Source URL/location (from which provider type is auto-detected)
  - Optional explicit provider type (for ambiguous URLs or custom providers)
  - Local destination path
  - Authentication reference (secret key name)
  - Provider-specific options (flexible attribute set)
  - Sync strategy (clone-once, always-update, bidirectional)

- **Provider Handler**: Logic that knows how to synchronize a specific provider type

  - Provider type identifier
  - Validation function (checks required fields)
  - Sync function (performs the synchronization)
  - Authentication integration (how to use secrets)

## Success Criteria

### Measurable Outcomes

- **SC-001**: Existing git repository configurations continue to work without modification after schema migration
- **SC-002**: User can configure repositories from at least 3 different provider types (git, s3, proton-drive) in a single user config
- **SC-003**: Adding support for a new provider type requires changes to only provider-specific handler files (zero core schema changes)
- **SC-004**: Repository sync failures for one provider do not prevent other providers from syncing successfully
- **SC-005**: System successfully synchronizes 10+ repositories from mixed providers during a single activation
- **SC-006**: Clear log messages identify which provider handled each repository and whether sync succeeded or failed

## Assumptions

- Provider type can be automatically detected from URL patterns:
  - Git: URLs ending with `.git`, starting with `git@`, `https://github.com/`, `https://gitlab.com/`, etc.
  - S3: URLs starting with `s3://` or S3-compatible services (AWS, DigitalOcean Spaces, Backblaze B2, Wasabi, Hetzner Object Storage)
  - Proton Drive: URLs starting with `proton-drive://` or matching Proton Drive share link patterns
- When URL pattern is ambiguous or custom provider, user can specify explicit provider field
- Provider-specific sync tools (git, aws-cli/s3cmd, proton-drive-cli) are available in the system path or via nixpkgs
- Each provider type has a clear way to determine sync success (exit code, output parsing)
- Authentication for different providers can all be managed via agenix secrets (API keys, tokens, passwords)
- Users understand provider-specific URL/location formats when not using standard patterns
- Sync is unidirectional (remote → local) unless explicitly configured for bidirectional
- Default sync strategy is "update existing, clone if missing" for all providers
- Repository schema lives in user-schema.nix since repositories are per-user configuration
- Existing Feature 032 git-repos implementation will be refactored to become first provider handler
- Explicit provider field overrides auto-detection when both are present
