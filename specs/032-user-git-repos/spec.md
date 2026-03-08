# Feature Specification: User Git Repository Configuration

**Feature Branch**: `032-user-git-repos`\
**Created**: 2025-12-30\
**Status**: Draft\
**Input**: User description: "in user configuration, I want a new option section for git repositories, each repo ssh or url will be cloned under a specified path during the build. when repo clone path is not specified, it's cloned under the root path in the section itself. when root path is not specified, they are all cloned under the user home folder"

**Clarification**: Git repositories must be cloned during activation (not build), after git is installed as part of user applications and after credentials are in place.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Clone Single Repository with Default Location (Priority: P1)

A user wants to clone a git repository (e.g., their dotfiles or a project) to their home folder during system activation without manually specifying paths.

**Why this priority**: This is the simplest and most common use case - users need basic repository cloning functionality. It delivers immediate value and serves as the foundation for more complex scenarios.

**Independent Test**: Can be fully tested by configuring a single repository URL in user config with git in the applications list, running the activation, and verifying the repository exists in the user's home folder.

**Acceptance Scenarios**:

1. **Given** a user configuration with git in applications list and one git repository URL with no paths specified, **When** the system activation runs, **Then** the repository is cloned to the user's home folder
1. **Given** a repository URL using SSH format and SSH credentials configured, **When** activation runs, **Then** the repository is successfully cloned using SSH authentication
1. **Given** a repository URL using HTTPS format, **When** activation runs, **Then** the repository is successfully cloned using HTTPS
1. **Given** git is not in the user's applications list, **When** activation runs, **Then** repository cloning is skipped (no error)

______________________________________________________________________

### User Story 2 - Clone Multiple Repositories with Section Root Path (Priority: P2)

A user wants to organize multiple repositories under a common parent directory (e.g., `~/projects/`) without specifying the full path for each repository individually.

**Why this priority**: This addresses organizational needs for users managing multiple repositories. It reduces configuration verbosity and provides logical grouping, which is valuable for developers and power users.

**Independent Test**: Can be tested by configuring multiple repositories with a section-level root path, running activation, and verifying all repositories exist under the specified root directory.

**Acceptance Scenarios**:

1. **Given** a user configuration with a root path set to `~/projects/` and three repository URLs, **When** activation runs, **Then** all three repositories are cloned under `~/projects/`
1. **Given** a root path that doesn't exist yet, **When** activation runs, **Then** the system creates the root path directory before cloning
1. **Given** repositories with the same name from different sources, **When** cloned to the same root path, **Then** each repository is distinguishable (by full repository path or unique naming)

______________________________________________________________________

### User Story 3 - Clone Repositories with Individual Custom Paths (Priority: P2)

A user wants fine-grained control over where specific repositories are cloned, overriding both section-level and default paths for specific repositories.

**Why this priority**: This provides maximum flexibility for advanced use cases where users need specific repositories in specific locations (e.g., system configuration repos, work projects in `~/work/`, personal in `~/personal/`).

**Independent Test**: Can be tested by configuring repositories with individual custom paths, running activation, and verifying each repository exists at its specified location, ignoring section root and default paths.

**Acceptance Scenarios**:

1. **Given** a repository with a custom path specified, **When** activation runs, **Then** the repository is cloned to the custom path, ignoring section root path
1. **Given** a repository with a custom path and a section root path both specified, **When** activation runs, **Then** the custom path takes precedence
1. **Given** a custom path that is an absolute path, **When** activation runs, **Then** the repository is cloned to the absolute path exactly as specified
1. **Given** a custom path that is a relative path, **When** activation runs, **Then** the relative path is resolved from the user's home folder

______________________________________________________________________

### User Story 4 - Update and Sync Existing Repositories (Priority: P3)

A user wants previously cloned repositories to be automatically updated (pulled) during subsequent system activations, keeping their local copies in sync with remote changes.

**Why this priority**: This enhances usability by automating repository maintenance, but is less critical than initial cloning functionality. Users can manually pull updates if needed.

**Independent Test**: Can be tested by running an initial activation with repositories, making changes to the remote repositories, running a second activation, and verifying local repositories are updated.

**Acceptance Scenarios**:

1. **Given** a repository that was cloned in a previous activation, **When** a new activation runs, **Then** the existing repository is updated with the latest changes from the remote
1. **Given** a repository with local uncommitted changes, **When** activation runs, **Then** the system handles the conflict gracefully without losing local changes
1. **Given** a repository that has been deleted locally, **When** activation runs, **Then** the repository is re-cloned

______________________________________________________________________

### User Story 5 - Activation Ordering and Credential Dependency (Priority: P1)

A user configures repositories requiring SSH authentication and expects them to be cloned only after SSH credentials are deployed during activation.

**Why this priority**: This is critical for the feature to work correctly. Repository cloning must happen at the right time in the activation sequence to have access to both git and credentials.

**Independent Test**: Can be tested by configuring a private SSH repository with credentials in secrets, running activation, and verifying the repository is cloned successfully after credentials are deployed.

**Acceptance Scenarios**:

1. **Given** git is in the user's applications list and SSH credentials are configured, **When** activation runs, **Then** repositories are cloned after git installation and credential deployment complete
1. **Given** repository cloning requires SSH credentials, **When** activation attempts to clone before credentials are deployed, **Then** the activation order ensures credentials are available first
1. **Given** git is not installed, **When** activation runs with repositories configured, **Then** repository cloning is skipped without causing activation failure

______________________________________________________________________

### Edge Cases

- What happens when a repository URL is invalid or unreachable during activation?
- How does the system handle authentication failures for private repositories?
- What happens when the specified clone path is a file (not a directory)?
- How does the system handle repository name conflicts when multiple repos have the same name?
- What happens when a repository is removed from the configuration but already exists locally?
- How does the system handle repositories with submodules?
- What happens when disk space is insufficient for cloning?
- How does the system handle very large repositories (> 1GB) during activation time?
- What happens when git is added to applications list after repositories are already configured?
- What happens if credentials are updated but repositories were cloned with old credentials?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to specify git repositories in their user configuration using either SSH or HTTPS URLs
- **FR-002**: System MUST clone all configured repositories during the home-manager activation process, not during build
- **FR-003**: System MUST only attempt to clone repositories if git is included in the user's applications list
- **FR-004**: Repository cloning MUST occur after git installation and credential deployment in the activation sequence
- **FR-005**: Users MUST be able to specify an optional root path for all repositories in the configuration section
- **FR-006**: Users MUST be able to specify an optional individual path for each repository, overriding the section root path
- **FR-007**: System MUST use the following path resolution order: (1) individual repository path if specified, (2) section root path if specified, (3) user's home folder as default
- **FR-008**: System MUST create parent directories as needed before cloning repositories
- **FR-009**: System MUST handle both SSH and HTTPS repository URLs
- **FR-010**: System MUST support authentication for private repositories using SSH keys deployed during activation
- **FR-011**: System MUST gracefully handle repository cloning failures without breaking the entire activation process
- **FR-012**: System MUST provide clear error messages when repository cloning fails, including the reason for failure
- **FR-013**: System MUST detect when a repository already exists at the target path
- **FR-014**: System MUST update (pull) existing repositories to the latest version during subsequent activations
- **FR-015**: System MUST preserve local changes when updating existing repositories (use safe update strategies like fetch + merge or stash)
- **FR-016**: Users MUST be able to specify both absolute and relative paths for repository locations
- **FR-017**: Relative paths MUST be resolved relative to the user's home folder
- **FR-018**: System MUST handle repository name conflicts by using the full repository path or unique identifiers
- **FR-019**: System MUST skip repository cloning entirely if git is not in the user's applications list, without causing errors

### Key Entities

- **GitRepository**: Represents a git repository to be cloned; attributes include URL (SSH or HTTPS), optional custom clone path, authentication method reference
- **RepositorySection**: Represents the configuration section containing repositories; attributes include optional root path for all repositories, list of repository definitions
- **ClonePath**: Represents the resolved destination path for a repository; determined by path resolution rules (individual > section root > home folder default)
- **ActivationPhase**: Represents the timing of repository cloning within the activation sequence; must occur after git installation and credential deployment

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can configure and successfully clone at least one git repository using default settings (no custom paths) within a single activation
- **SC-002**: Users can configure a root path and successfully clone multiple repositories (at least 3) under that root path in a single activation
- **SC-003**: Users can override paths for individual repositories and verify each repository is cloned to its specified location (100% accuracy)
- **SC-004**: System successfully updates existing repositories during subsequent activations without losing local changes (0% data loss)
- **SC-005**: System provides actionable error messages for all failure scenarios (authentication, network, disk space) allowing users to diagnose and fix issues
- **SC-006**: Repository cloning completes within a reasonable activation time (< 5 minutes for typical use cases with 3-5 small repositories)
- **SC-007**: Users can successfully clone both public and private repositories using SSH credentials deployed during activation without additional manual configuration
- **SC-008**: Repository cloning consistently occurs after git installation and credential deployment in 100% of activation runs (correct ordering)
- **SC-009**: Users without git in their applications list can configure repositories without causing activation failures (graceful skip)

## Assumptions *(optional)*

- Git is included in the user's applications list when repositories are configured (or cloning is gracefully skipped)
- Users have appropriate SSH keys configured in their secrets for private repositories
- SSH credentials are deployed during activation before repository cloning occurs
- Network connectivity is available during the activation process
- Users have sufficient disk space for the repositories they configure
- Repository URLs are valid git repository endpoints
- The activation process has appropriate permissions to create directories and clone repositories in the target locations
- Users understand the activation sequence and that repositories are cloned during activation, not build time

## Scope *(optional)*

### In Scope

- Cloning git repositories during home-manager activation
- Activation ordering to ensure git installation and credential deployment happen first
- Configuring repository URLs (SSH and HTTPS)
- Configuring clone paths (individual, section root, default)
- Path resolution logic (individual > section root > home folder)
- Updating existing repositories during subsequent activations
- Error handling and reporting for clone failures
- Creating parent directories as needed
- Authentication using SSH keys deployed during activation
- Conditional cloning based on git being in applications list
- Integration with existing activation script pattern (similar to font repos, app secrets)

### Out of Scope

- Managing git credentials or SSH key generation (uses existing secrets system)
- Automatic conflict resolution for repositories with local changes
- Repository-specific git configurations (branches, tags, commit selection)
- Sparse checkouts or partial clones
- Git LFS (Large File Storage) support
- Repository access permissions management
- Automatic repository deletion when removed from configuration
- Git submodule initialization and updates (may be handled automatically by git clone)
- Post-clone hooks or custom scripts
- Repository mirroring or backup functionality
- Build-time repository cloning (explicitly activation-time only)

## Dependencies *(optional)*

- Git must be included in user's applications list
- SSH keys must be configured in user secrets for private repository access
- Credential deployment must complete before repository cloning in activation sequence
- Network connectivity required during activation process
- File system permissions to create directories and write files in target locations
- Existing user configuration system that supports the new repository section
- Existing activation script system (home.activation pattern used by fonts, secrets)
- Existing secrets system for SSH key deployment
