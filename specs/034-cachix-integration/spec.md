# Feature Specification: Cachix Integration

**Feature Branch**: `034-cachix-integration`\
**Created**: 2025-12-31\
**Status**: Draft (Final Architecture)\
**Input**: User request: "integrate with cachix" + cachix-deploy agent

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Binary Cache Usage (Priority: P1)

All users benefit from the default.cachix.org cache automatically. The system uses a read-only token by default, allowing anyone to download pre-built packages without configuration. Users who want to push builds can optionally configure their own authentication.

**Why this priority**: This is the core functionality - enabling fast builds through binary cache reuse. Essential for development workflow efficiency.

**Independent Test**: Run `just build`, verify packages download from default.cachix.org instead of building locally.

**Acceptance Scenarios**:

1. **Given** default.cachix.org is configured, **When** any user builds, **Then** packages are fetched from cache instead of being built locally
1. **Given** a package exists in the cache, **When** rebuilding, **Then** the build completes significantly faster than building from source
1. **Given** a package doesn't exist in cache, **When** building, **Then** the package is built locally without errors
1. **Given** a user has no cachix configuration, **When** building, **Then** they still benefit from read-only cache access

______________________________________________________________________

### User Story 2 - Optional Per-User Push (Priority: P1)

Users can optionally configure write access to push their builds to the cache. This is opt-in via user configuration and secrets. Users without write access configured can still use the cache in read-only mode.

**Why this priority**: Enables build sharing across machines for users who want it, while keeping the system simple for users who only need read access.

**Independent Test**: Configure write access for one user, build a package, verify it's pushed to cache. Build same package with different user, verify read-only access works.

**Acceptance Scenarios**:

1. **Given** a user has configured `user.cachix.authToken = "<secret>"`, **When** they build a package, **Then** it is automatically pushed to default.cachix.org
1. **Given** a user has no cachix configuration, **When** they build a package, **Then** build succeeds but no push occurs (read-only mode)
1. **Given** a package was pushed by user A, **When** user B builds, **Then** they download from cache regardless of their own push configuration
1. **Given** cache push fails (network issue), **When** building, **Then** build still succeeds with warning logged

______________________________________________________________________

### User Story 3 - Cachix Deploy Agent (Priority: P2)

A cachix-deploy agent runs as a system service, enabling remote deployment commands from the Cachix dashboard or CI/CD pipelines. The agent uses one user's credentials for authentication.

**Why this priority**: Enables GitOps-style deployments and remote system updates. Important for automation but secondary to basic caching.

**Independent Test**: Start agent service, verify it connects to Cachix and can receive deployment commands.

**Acceptance Scenarios**:

1. **Given** the agent service is running, **When** checking service status, **Then** it shows as active and connected to Cachix
1. **Given** a deployment is triggered from Cachix dashboard, **When** the agent receives it, **Then** the system applies the configuration
1. **Given** the agent token is invalid, **When** the service starts, **Then** it logs a clear authentication error

______________________________________________________________________

### User Story 4 - Build and Push (Priority: P2)

Users with write access can use `just build-and-push` to build their configuration and automatically push the result to the cache in one command. This provides a seamless workflow for sharing builds.

**Why this priority**: Darwin post-build-hook runs as nix-daemon (root) and can't access user secrets. Separate build-and-push command is the clean solution.

**Independent Test**: Run `just build-and-push username hostname`, verify build succeeds and result appears in cache.

**Acceptance Scenarios**:

1. **Given** a user has configured write access, **When** they run `just build-and-push`, **Then** the configuration builds and is automatically pushed to the cache
1. **Given** a user has no write access, **When** they run `just build-and-push`, **Then** build succeeds but push is skipped with a clear message
1. **Given** the build fails, **When** running `just build-and-push`, **Then** the push is not attempted (build failure stops execution)

______________________________________________________________________

### Edge Cases

- What happens when Cachix is unreachable? System should fall back to building locally without blocking.
- What happens when authentication token expires? Read-only token is set to never expire. Write tokens managed per-user via secrets rotation.
- What happens when pushing fails (network issues, storage quota)? Build succeeds, push failure logged as warning (manual push) or skipped silently (no auth configured).
- What happens when agent service fails? System continues to work, only remote deployments affected.
- What happens with multiple machines? All machines share the same cache, users with write access can push from any machine.
- What happens when cachix is undefined for a user? They use read-only access (system default).
- What happens when cachix is defined but no secret configured? They use read-only access (system default).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST configure default.cachix.org as a binary cache substituter
- **FR-002**: System MUST use the provided read-only token for system-wide cache access
- **FR-003**: System MUST allow users to optionally configure write access via `user.cachix`
- **FR-004**: System MUST fall back to local builds when cache is unavailable
- **FR-005**: System MUST store read-only token as hardcoded constant (no secret needed)
- **FR-006**: Users with write access MUST store their auth token in per-user secrets
- **FR-007**: System MUST provide `just build-and-push` recipe for build + automatic push
- **FR-008**: System MUST run cachix-deploy agent as a system service (darwin: launchd, nixos: systemd)
- **FR-009**: System MUST configure agent with workspace "default" and provided agent token
- **FR-010**: System MUST store agent token in one user's secrets (cdrolet by convention)
- **FR-011**: System MUST start agent service on boot and restart on failure
- **FR-012**: Users without cachix configuration MUST still benefit from read-only cache access

### Key Entities

- **System-Wide Cache Configuration**: Read-only access for everyone

  - Cache name: `default`
  - Public key: `default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=`
  - Read-only token: `eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c` (hardcoded)
  - Priority: `10` (higher than public caches)

- **Per-User Cache Configuration** (Optional): Write access for pushing

  - User field: `user.cachix.authToken = "<secret>"`
  - Secret field: `cachix.authToken` in `user/{name}/secrets.age`
  - Read-write token: `eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI0ODhkNjViNy1hMTE2LTQzNDYtYTMwNS1kYTAyZmFlN2FhZWIiLCJzY29wZXMiOiJjYWNoZSJ9.uAtsEJmBmRmt1mZErn5wo2mNWGJ7ognHSUAWstxAHHg`
  - Cache name: `default` (can optionally override to use different cache)
  - Public key: Must match if overriding cache name

- **Cachix Deploy Agent**: System service for remote deployments

  - Workspace: `default`
  - Agent token: `eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzVlYWFkMC0yMTBjLTQxNjQtOWE5My04NjQ0Y2NmZDk5ZjgiLCJzY29wZXMiOiJhZ2VudCJ9.PCwuiCMPSb-cVpVzGCyglME6bBpHZ_DURaQe43okL8g`
  - Service: `cachix-deploy-agent` (launchd/systemd)
  - Auto-start: Yes
  - Restart policy: Always
  - Token storage: One user's secrets (cdrolet by convention)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All users benefit from default.cachix.org read-only access without configuration
- **SC-002**: Build times improve by 50-90% when packages are in cache
- **SC-003**: Users with configured write access can build and push via `just build-and-push`
- **SC-004**: Cachix-deploy agent runs as a system service and shows connected status
- **SC-005**: Remote deployments work from Cachix dashboard
- **SC-006**: Configuration failures provide clear error messages
- **SC-007**: Documentation in CLAUDE.md explains cachix configuration options
- **SC-008**: Users without cachix configuration still benefit from cache (read-only)

## Technical Notes

**Cache Details**:

- Name: default
- URL: https://default.cachix.org
- Public Key: default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=
- Read-only Token (hardcoded): eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c
- Read-write Token (per-user secret): eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI0ODhkNjViNy1hMTE2LTQzNDYtYTMwNS1kYTAyZmFlN2FhZWIiLCJzY29wZXMiOiJjYWNoZSJ9.uAtsEJmBmRmt1mZErn5wo2mNWGJ7ognHSUAWstxAHHg

**Agent Details**:

- Workspace: default
- Token (stored in cdrolet's secrets): eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzVlYWFkMC0yMTBjLTQxNjQtOWE5My04NjQ0Y2NmZDk5ZjgiLCJzY29wZXMiOiJhZ2VudCJ9.PCwuiCMPSb-cVpVzGCyglME6bBpHZ_DURaQe43okL8g
- Documentation: https://docs.cachix.org/deploy/running-an-agent/

**Authentication Architecture**:

- Read-only: Hardcoded in system settings (nix.settings.netrc-file or environment)
- Write access: Per-user netrc file generated via Home Manager activation script
- Agent: Wrapper script extracts token from user's secrets.age JSON

**Push Strategy**:

- **Darwin**: Build-and-push via `just build-and-push` (post-build-hook can't access user secrets)
- **NixOS**: Build-and-push via `just build-and-push` (consistent across platforms)
- **Automatic push**: Integrated into build workflow for users with write access

**Per-User Model**:

- Users are independent personas (not just different machines for same person)
- Each user can opt into write access independently
- System provides read-only access by default
- If `user.cachix` undefined or no secret configured, user uses read-only mode
