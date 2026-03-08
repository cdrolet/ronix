# Feature Specification: Unresolved Migration MVP (Low-Risk Items)

**Feature ID**: 008\
**Feature Name**: Unresolved Migration MVP - Low-Risk Items\
**Created**: 2025-10-27\
**Status**: Draft\
**Parent Spec**: 002-darwin-system-restructure

______________________________________________________________________

## Overview

Complete migration of low-risk, high-value unresolved items from spec 002's `unresolved-migration.md`. This MVP focuses on three user stories that don't require complex sudo operations, firewall changes, or NVRAM modifications.

**MVP Scope**: Power management (US2), display configuration (US5), and one-time operations (US8)

**Future Specs**: Higher-risk items (NVRAM, firewall, security, login items, services) will be addressed in subsequent specs after MVP validation.

______________________________________________________________________

## Problem Statement

### Current State

- Spec 002 has 10 unresolved items requiring manual configuration
- Item 6 (Spotlight) excluded by user
- Item 8 (Dock) completed in spec 007
- Remaining 8 items lack helper library functions
- No activation scripts exist for system-level operations

### Desired State (MVP)

- Power management settings automated (standby delay)
- HiDPI display modes enabled for external monitors
- One-time setup operations (Library folder, Spotlight) automated
- Helper library functions created for these operations
- All operations are idempotent and documented

### Why MVP First

- **Low Risk**: These operations don't affect network/security/boot
- **High Value**: Immediate quality-of-life improvements
- **Validation**: Proves helper library pattern for system operations
- **Foundation**: Success enables tackling higher-risk items later

______________________________________________________________________

## User Stories

### User Story 1: Power Management Configuration

**Priority**: P1 (MVP)\
**As a** macOS user\
**I want** standby delay configured to 24 hours via nix-darwin\
**So that** my Mac doesn't enter standby during normal idle periods

**Acceptance Criteria**:

- Helper function `mkPmsetSet { setting, value, scope }` created
- Standby delay set to 86400 seconds (24 hours)
- Configuration applies to all power sources (-a flag)
- Setting persists across reboots
- Configuration is idempotent (safe to rerun)

**Source** (from `~/project/dotfiles/scripts/sh/darwin/system.sh`):

```bash
sudo pmset -a standbydelay 86400
```

**Technical Details**:

- Uses `pmset` command (Power Management Settings)
- Requires sudo for system-level power configuration
- `-a` flag applies to all power sources (AC, battery, UPS)
- Value is in seconds (86400 = 24 hours)

**Risks**: Low - only affects sleep/standby behavior, easily reversed

______________________________________________________________________

### User Story 2: HiDPI Display Configuration

**Priority**: P1 (MVP)\
**As a** macOS user with external displays\
**I want** HiDPI (Retina) resolution modes enabled\
**So that** I have optimal resolution options for non-Apple displays

**Acceptance Criteria**:

- Configuration added to existing `modules/darwin/system/screen.nix`
- HiDPI modes enabled via activation script
- Setting persists across reboots
- Uses sudo for WindowServer system preference
- Configuration is idempotent

**Source** (from `~/project/dotfiles/scripts/sh/darwin/system.sh`):

```bash
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
```

**Technical Details**:

- Modifies `/Library/Preferences/` (system-wide)
- Affects WindowServer (display management)
- Requires sudo for system-level preference
- Enables scaled resolutions for external displays

**Risks**: Low - only adds display options, doesn't change current resolution

______________________________________________________________________

### User Story 3: One-Time Setup Operations

**Priority**: P1 (MVP)\
**As a** macOS user\
**I want** initial setup operations automated\
**So that** my system is properly configured on first boot

**Acceptance Criteria**:

- Helper function `mkOneTimeOperation { name, command, checkCommand }` created
- Library folder (~/ Library) unhidden in Finder
- Spotlight indexing enabled (if disabled)
- Operations run once during first activation
- Marker files track completion to prevent re-execution
- Configuration is idempotent

**Source** (from `~/project/dotfiles/scripts/sh/darwin/system.sh`):

```bash
chflags nohidden ~/Library
sudo mdutil -i on /
```

**Technical Details**:

- `chflags nohidden`: Removes hidden flag from Library folder
- `mdutil -i on`: Enables Spotlight indexing for root volume
- Both are one-time operations (shouldn't re-run)
- Marker file: `~/.nix-darwin-initial-setup-complete`

**Risks**: Very low - both operations are commonly recommended for new Macs

______________________________________________________________________

## Functional Requirements

### FR-001: Helper Library Functions

**Priority**: MUST\
**Description**: Create helper functions for MVP operations in `modules/darwin/lib/mac.nix`

**Required Functions**:

1. **`mkPmsetSet { setting, value, scope ? "-a" }`**

   - Generates: `sudo pmset <scope> <setting> <value>`
   - Idempotency: Checks current value before setting
   - Example: `mkPmsetSet { setting = "standbydelay"; value = 86400; }`

1. **`mkOneTimeOperation { name, command, checkCommand }`**

   - Generates: Script that runs command once, tracks with marker file
   - Idempotency: Checks marker file or checkCommand
   - Example: `mkOneTimeOperation { name = "unhide-library"; command = "chflags nohidden ~/Library"; checkCommand = "test ! -f ~/Library/.hidden"; }`

**Function Requirements**:

- All functions return shell script strings
- Include idempotency checks
- Use absolute paths for commands
- Proper error handling (|| true where appropriate)
- Clear inline comments

### FR-002: Module Structure

**Priority**: MUST\
**Description**: Organize configuration into appropriate modules

**Modules**:

1. **modules/darwin/system/power.nix** (NEW)

   - Power management via pmset
   - Uses `mkPmsetSet` helper function
   - Activation script with sudo

1. **modules/darwin/system/screen.nix** (UPDATE)

   - Add HiDPI configuration
   - Uses activation script with sudo
   - Preserves existing screen settings

1. **modules/darwin/system/initial-setup.nix** (NEW)

   - One-time setup operations
   - Uses `mkOneTimeOperation` helper function
   - Unhide Library folder, enable Spotlight

### FR-003: Activation Scripts

**Priority**: MUST\
**Description**: All operations use activation scripts

**Pattern**:

```nix
system.activationScripts.<name> = {
  text = ''
    ${helperFunction { params }}
  '';
};
```

**Sudo Handling**:

- Helper functions generate `sudo` commands where needed
- Assumes `darwin-rebuild switch` runs with appropriate privileges
- No interactive sudo prompts

### FR-004: Idempotency

**Priority**: MUST\
**Description**: All operations must be safe to rerun

**Implementation**:

- `mkPmsetSet`: Check current pmset value before setting
- HiDPI: Check if already enabled before writing
- One-time ops: Use marker files or check commands

### FR-005: Documentation

**Priority**: MUST\
**Description**: Comprehensive documentation for all configuration

**Requirements**:

- Module headers reference dotfiles source
- Comments explain sudo requirements
- Helper function documentation in code
- Update `unresolved-migration.md` to mark items resolved

______________________________________________________________________

## Non-Functional Requirements

### NFR-001: Performance

- All operations complete within 10 seconds during `darwin-rebuild switch`
- No unnecessary command execution (idempotency checks)

### NFR-002: Safety

- Sudo commands use absolute paths
- All operations are reversible
- No system-critical settings modified

### NFR-003: Maintainability

- Helper functions in shared library (`modules/darwin/lib/mac.nix`)
- Clear separation between helper functions and module configuration
- Each user story maps to one module

______________________________________________________________________

## Technical Constraints

### TC-001: Sudo Requirement

- **Constraint**: pmset and system defaults require root privileges
- **Impact**: Must run during `darwin-rebuild switch` with sudo
- **Mitigation**: Document sudo requirement clearly

### TC-002: Display Configuration Timing

- **Constraint**: HiDPI setting may require logout/reboot to take effect
- **Impact**: User must log out after initial configuration
- **Mitigation**: Document in module comments

### TC-003: Spotlight Indexing

- **Constraint**: Spotlight usually enabled by default on modern macOS
- **Impact**: Operation may be no-op on most systems
- **Mitigation**: Make it idempotent with proper checking

______________________________________________________________________

## Out of Scope (Future Specs)

### Deferred to Later

1. **NVRAM Configuration** (Item #1)

   - Reason: Requires reboot, higher risk
   - Future: Spec 009 or later

1. **Firewall Configuration** (Item #3)

   - Reason: Network security implications, needs careful testing
   - Future: Spec 009 or later

1. **Security & Privacy** (Item #4)

   - Reason: Guest account, hostname require system-level changes
   - Future: Spec 009 or later

1. **Startup Applications** (Item #7)

   - Reason: Login items management is complex
   - Future: Spec 009 or later

1. **Service Management** (Item #9)

   - Reason: LaunchAgent configuration needs validation
   - Future: Spec 009 or later

### Excluded Entirely

1. **Spotlight Indexing Order** (Item #6)

   - Reason: User explicitly excluded, complex structure

1. **Dock Configuration** (Item #8)

   - Reason: Already completed in spec 007

______________________________________________________________________

## Dependencies

### Internal Dependencies

- **Spec 006**: Helper library framework (COMPLETE)

  - Requires `modules/darwin/lib/mac.nix`
  - Will extend with 2 new functions

- **Spec 002**: Darwin system restructure (COMPLETE)

  - Requires module directory structure
  - Updates `unresolved-migration.md`

### External Dependencies

- **nix-darwin**: System configuration framework
- **macOS**: System commands (pmset, defaults, chflags, mdutil)

______________________________________________________________________

## Success Criteria

### Definition of Done

1. **Helper Functions Created**:

   - [ ] `mkPmsetSet` function added to `modules/darwin/lib/mac.nix`
   - [ ] `mkOneTimeOperation` function added to `modules/darwin/lib/mac.nix`
   - [ ] Both functions are idempotent
   - [ ] Both functions documented with examples

1. **Modules Implemented**:

   - [ ] `modules/darwin/system/power.nix` created
   - [ ] `modules/darwin/system/screen.nix` updated
   - [ ] `modules/darwin/system/initial-setup.nix` created
   - [ ] All modules use helper library functions

1. **Testing Complete**:

   - [ ] `darwin-rebuild switch` completes successfully
   - [ ] pmset standby delay verifies as 86400 seconds
   - [ ] HiDPI modes appear in display preferences
   - [ ] Library folder visible in Finder
   - [ ] Spotlight indexing confirmed active
   - [ ] Configuration is idempotent (safe to rerun)

1. **Documentation Complete**:

   - [ ] All modules have header comments with dotfiles references
   - [ ] Helper functions documented in code
   - [ ] `unresolved-migration.md` updated (items 2, 5, 10 marked resolved)
   - [ ] Quickstart guide created for testing

______________________________________________________________________

## Risk Assessment

### Low Risk (All MVP Items)

**Risk**: pmset standby delay doesn't persist

- **Likelihood**: Very low (pmset designed for persistence)
- **Impact**: Low (Mac enters standby sooner, not a critical issue)
- **Mitigation**: Verify with `pmset -g` after configuration
- **Contingency**: Manually set via System Settings > Battery

**Risk**: HiDPI modes don't appear or cause display issues

- **Likelihood**: Very low (standard macOS feature)
- **Impact**: Low (adds options, doesn't change current settings)
- **Mitigation**: Test on system with external display
- **Contingency**: Revert via `defaults delete`

**Risk**: One-time operations run repeatedly

- **Likelihood**: Low (marker file tracking)
- **Impact**: Low (operations are safe to rerun anyway)
- **Mitigation**: Robust marker file checking
- **Contingency**: Delete marker file to force re-run

______________________________________________________________________

## Implementation Strategy

### Phase-by-Phase Approach

**Phase 1**: Helper Functions

1. Implement `mkPmsetSet` with idempotency check
1. Implement `mkOneTimeOperation` with marker file tracking
1. Test functions in isolation

**Phase 2**: Module Implementation

1. Create `power.nix` (simplest)
1. Update `screen.nix` (existing module)
1. Create `initial-setup.nix` (most complex)

**Phase 3**: Testing & Validation

1. Test each module individually
1. Test all together with `darwin-rebuild switch`
1. Verify idempotency by rerunning
1. Document results

**Phase 4**: Documentation & Cleanup

1. Update `unresolved-migration.md`
1. Add helper function documentation
1. Create quickstart guide

### Validation Criteria

After implementation, verify:

```bash
# Verify pmset
pmset -g | grep standbydelay  # Should show 86400

# Verify HiDPI (if external display connected)
# Check System Settings > Displays for scaled options

# Verify Library folder visible
ls -lOd ~/Library | grep -v hidden  # Should not show "hidden"

# Verify Spotlight indexing
sudo mdutil -s /  # Should show "Indexing enabled"
```

______________________________________________________________________

## Future Expansion

After MVP success, subsequent specs can address:

- **Spec 009**: Medium-risk items (startup apps, services, security)
- **Spec 010**: High-risk items (NVRAM, firewall)

**Rationale**: MVP validates the approach with minimal risk, building confidence for more complex migrations.

______________________________________________________________________

## Glossary

- **pmset**: Power Management Settings utility
- **HiDPI**: High Dots Per Inch, enables Retina-like resolution scaling
- **WindowServer**: macOS display management service
- **mdutil**: Spotlight indexing management utility
- **Marker file**: File used to track one-time operation completion
- **Idempotent**: Safe to run multiple times without cumulative effects

______________________________________________________________________

## References

- **Parent Spec**: [002-darwin-system-restructure](../002-darwin-system-restructure/spec.md)
- **Helper Library Spec**: [006-reusable-helper-library](../006-reusable-helper-library/spec.md)
- **Dock Migration**: [007-007-complete-dock-migration](../007-007-complete-dock-migration/spec.md)
- **Unresolved Items**: [002/unresolved-migration.md](../002-darwin-system-restructure/unresolved-migration.md)
- **Dotfiles Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`
- **Helper Library**: `modules/darwin/lib/mac.nix`
