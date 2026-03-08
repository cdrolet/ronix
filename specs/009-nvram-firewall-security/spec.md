# Feature Specification: NVRAM, Firewall, and Security Configuration

**Feature Branch**: `009-nvram-firewall-security`\
**Created**: 2025-10-28\
**Status**: Approved\
**Input**: User description: "do unresolved-migration items: 1,3 and 4"

**Clarifications**: 1A (default firewall behavior), 2B (per-host hostname), 3C (fixed boot-args)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - System Firewall Protection (Priority: P1)

As a security-conscious user, I want my macOS system firewall enabled and configured for stealth mode during system configuration so that my system is protected from unauthorized network access immediately after deployment without requiring manual security configuration.

**Why this priority**: System firewall is the first line of defense against network threats. Without automated configuration, systems remain vulnerable during the window between deployment and manual security setup. This is the highest priority as it directly protects against external threats.

**Independent Test**: Can be fully tested by running `darwin-rebuild switch`, then verifying firewall settings with `sudo defaults read /Library/Preferences/com.apple.alf` and confirming the system is protected from unauthorized access attempts while in stealth mode.

**Acceptance Scenarios**:

1. **Given** a new nix-darwin system deployment, **When** `darwin-rebuild switch` is executed, **Then** the system firewall must be enabled (globalstate=1)
1. **Given** a configured system, **When** checking firewall settings, **Then** stealth mode must be enabled (stealthenabled=1) to prevent port scanning
1. **Given** firewall logging preferences, **When** the configuration is applied, **Then** logging must be disabled (loggingenabled=0) to avoid log noise
1. **Given** an existing system with firewall already configured, **When** `darwin-rebuild switch` is run again, **Then** no changes should be made (idempotent behavior)
1. **Given** a user manually changes firewall settings, **When** `darwin-rebuild switch` is run, **Then** settings must be restored to declared configuration

______________________________________________________________________

### User Story 2 - Secure Login Configuration (Priority: P2)

As a system administrator, I want guest account access disabled and a custom hostname set during system deployment so that unauthorized users cannot access the system and the system is properly identified on the network according to security policies.

**Why this priority**: Guest account represents a security risk by allowing unauthenticated access. Custom hostname is important for network identification but less critical than preventing unauthorized access. This is second priority because it controls local access security.

**Independent Test**: Can be fully tested by running `darwin-rebuild switch`, then checking guest account status with `sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled` and verifying hostname with `sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName`.

**Acceptance Scenarios**:

1. **Given** a new system deployment, **When** `darwin-rebuild switch` is executed, **Then** guest account must be disabled (GuestEnabled=false)
1. **Given** hostname configuration with a specific value, **When** the system is configured, **Then** NetBIOS name must be set to the configured value (e.g., "Work-MacBook", "Home-MacMini")
1. **Given** an existing system with correct settings, **When** `darwin-rebuild switch` is run, **Then** settings must not be unnecessarily rewritten (idempotent)
1. **Given** a user manually enables guest account, **When** configuration is reapplied, **Then** guest account must be disabled again

______________________________________________________________________

### User Story 3 - Boot Configuration and Diagnostics (Priority: P3)

As a system administrator, I want verbose boot mode enabled and startup sound muted through NVRAM configuration so that I can diagnose boot issues with detailed logging while maintaining a professional silent boot experience.

**Why this priority**: NVRAM boot configuration is useful for debugging but not critical for security or basic system operation. It requires a reboot to take effect and is primarily a convenience feature. This is lowest priority as it enhances diagnostics but doesn't affect system functionality or security.

**Independent Test**: Can be fully tested by running `darwin-rebuild switch`, verifying NVRAM settings with `nvram -p | grep boot-args` and `nvram -p | grep SystemAudioVolume`, then rebooting to confirm verbose boot display and silent startup.

**Acceptance Scenarios**:

1. **Given** a new system deployment, **When** `darwin-rebuild switch` is executed, **Then** NVRAM boot-args must be set to "-v" for verbose mode
1. **Given** startup sound preferences, **When** configuration is applied, **Then** SystemAudioVolume must be set to 0 (muted)
1. **Given** NVRAM settings are configured, **When** the system reboots, **Then** verbose boot output must be visible during startup
1. **Given** existing NVRAM settings match desired state, **When** `darwin-rebuild switch` is run, **Then** NVRAM should not be unnecessarily written to (idempotent)
1. **Given** NVRAM configuration, **When** activation completes, **Then** user must be informed that a reboot is required for changes to take effect

______________________________________________________________________

### Edge Cases

- What happens when firewall settings file `/Library/Preferences/com.apple.alf` doesn't exist or is corrupted?
- How does the system handle NVRAM write failures (e.g., when System Integrity Protection prevents modifications)?
- What happens if the activation script runs without sudo privileges required for system-level preferences?
- How does the configuration behave when manually applied security settings conflict with declared configuration?
- What happens when firewall service fails to respond to configuration changes?
- How does the system handle partial NVRAM writes (boot-args succeeds but SystemAudioVolume fails)?
- What happens if the hostname contains invalid characters or exceeds length limits?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST enable macOS application firewall (globalstate=1) via system preference modification
- **FR-002**: System MUST configure firewall stealth mode (stealthenabled=1) to prevent network port scanning
- **FR-003**: System MUST disable firewall logging (loggingenabled=0) to minimize log verbosity
- **FR-004**: System MUST restart or reload firewall service after configuration changes to ensure settings take effect
- **FR-005**: System MUST disable guest account access (GuestEnabled=false) at login window
- **FR-006**: System MUST set NetBIOS hostname for SMB server identification (configurable per-host)
- **FR-007**: System MUST configure NVRAM boot arguments to "-v" for verbose boot mode
- **FR-008**: System MUST configure NVRAM SystemAudioVolume to 0 to mute startup sound
- **FR-009**: All system preference modifications MUST be idempotent (check before write pattern)
- **FR-010**: System MUST require and verify sudo/root privileges for system-level preference modifications
- **FR-011**: All configuration operations MUST be performed during nix-darwin activation
- **FR-012**: System MUST log all configuration changes for audit trail
- **FR-013**: Configuration MUST provide clear user feedback about actions taken or skipped
- **FR-014**: System MUST inform users when reboot is required for NVRAM changes to take effect
- **FR-015**: All activation scripts MUST use helper library functions (no inline command duplication)
- **FR-016**: NetBIOS hostname MUST be configurable per-host via nix-darwin module option (not hardcoded)

**Clarifications Resolved**:

- **FR-017**: Firewall application-specific exceptions [RESOLVED: Use default macOS behavior - firewall prompts user when apps request network access, no declarative configuration needed]
- **FR-018**: Hostname configurability [RESOLVED: NetBIOS hostname must be configurable per-host via host-specific configuration option]
- **FR-019**: NVRAM boot-args flexibility [RESOLVED: Fixed to "-v" for this specification, additional flags can be added in future specs if needed]

### Key Entities

- **System Firewall Preferences**: macOS application firewall settings stored in `/Library/Preferences/com.apple.alf`

  - Attributes: globalstate (0=off, 1=on), loggingenabled (0/1), stealthenabled (0/1)
  - Requires: sudo privileges, firewall service restart

- **Login Window Preferences**: System-wide login configuration stored in `/Library/Preferences/com.apple.loginwindow`

  - Attributes: GuestEnabled (boolean), affects pre-authentication access
  - Requires: sudo privileges

- **SMB Server Configuration**: Network identity settings stored in `/Library/Preferences/SystemConfiguration/com.apple.smb.server`

  - Attributes: NetBIOSName (string), used for Windows network identification
  - Configurability: Must be settable per-host (e.g., "Work-MacBook", "Home-MacMini", "Darwin-Dev")
  - Requires: sudo privileges

- **NVRAM Variables**: Non-volatile firmware variables stored in hardware

  - Attributes: boot-args (string), SystemAudioVolume (integer 0-255)
  - Requires: sudo privileges, reboot for changes to take effect
  - Persistence: survives reboots but can be reset by PRAM/NVRAM reset

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After running `darwin-rebuild switch`, firewall must be enabled and verifiable via `sudo defaults read /Library/Preferences/com.apple.alf globalstate` returning 1
- **SC-002**: After configuration, stealth mode must be active and verifiable via network port scan showing no response
- **SC-003**: After configuration, guest account must be disabled and not visible on login screen
- **SC-004**: After configuration and reboot, system must display verbose boot output during startup
- **SC-005**: After configuration and reboot, system must not play startup sound
- **SC-006**: Running `darwin-rebuild switch` multiple times must not cause unnecessary writes to system preferences (logged as "already set" or "skipped")
- **SC-007**: All configuration operations must complete within 30 seconds during activation
- **SC-008**: Configuration must succeed on clean macOS installation without pre-existing settings files
- **SC-009**: System must display clear user feedback messages for each configuration step (e.g., "Setting firewall stealth mode: enabled", "NVRAM configured - reboot required")
- **SC-010**: All system preference files must maintain correct ownership and permissions after modification (owned by root, appropriate mode bits)
