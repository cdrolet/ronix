# Feature Specification: Keyboard Configuration Restructure

**Feature Branch**: `044-keyboard-config-restructure`\
**Created**: 2026-02-07\
**Status**: Draft\
**Input**: User description: "In user config, a new keyboard config will be defined that includes the current keyboardLayout config. All existing modules that were referring to keyboardLayout will now have to use keyboard.layout path instead. This new keyboard will also include a new setting for using mac style mappings. This will be used by shared/family/linux as a condition before swapping Super and Ctrl keys."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Restructured Keyboard Layout Configuration (Priority: P1)

A user configures their keyboard layouts using the new `keyboard.layout` path instead of the legacy `keyboardLayout` field. The system applies their chosen layouts to all platforms exactly as before, with no change in behavior.

**Why this priority**: This is the foundational restructuring that all other stories depend on. Existing keyboard layout functionality must continue working under the new path before any new features are added.

**Independent Test**: Can be fully tested by changing a user config from `keyboardLayout = [...]` to `keyboard.layout = [...]`, rebuilding, and verifying keyboard layouts are applied correctly on all platforms.

**Acceptance Scenarios**:

1. **Given** a user config with `keyboard.layout = ["canadian-english" "canadian-french"]`, **When** the system builds, **Then** the correct keyboard layouts are applied on all platforms (macOS keyboard layout IDs, XKB layouts on Linux, GNOME input sources)
1. **Given** a user config with no `keyboard` field defined, **When** the system builds, **Then** platform defaults are used (no errors, same behavior as omitting `keyboardLayout` today)
1. **Given** a user config with the legacy `keyboardLayout` field, **When** the system builds, **Then** the build fails with a clear error message indicating the field has moved to `keyboard.layout`

______________________________________________________________________

### User Story 2 - Mac-Style Modifier Mapping Toggle (Priority: P2)

A user opts into or out of mac-style keyboard modifier remapping (Super/Ctrl key swap) using a new `keyboard.macStyleMappings` setting. On Linux, this controls whether Super and Ctrl keys are swapped to provide a macOS-like keyboard experience.

**Why this priority**: This is the primary new capability being added. Currently the Super/Ctrl swap is hardcoded for all Linux family users with no way to disable it. Making it configurable gives users control over their modifier key behavior.

**Independent Test**: Can be tested by setting `keyboard.macStyleMappings = false` on a Linux host, rebuilding, and verifying that Super and Ctrl keys are NOT swapped (native Linux behavior).

**Acceptance Scenarios**:

1. **Given** a user config with `keyboard.macStyleMappings = true` on a Linux host, **When** the system builds, **Then** Super and Ctrl keys are swapped (XKB options applied at both system and GNOME user levels)
1. **Given** a user config with `keyboard.macStyleMappings = false` on a Linux host, **When** the system builds, **Then** Super and Ctrl keys are NOT swapped (standard Linux modifier behavior)
1. **Given** a user config with `keyboard.macStyleMappings` not specified on a Linux host, **When** the system builds, **Then** the default behavior is applied (mac-style mappings enabled, preserving current behavior)
1. **Given** a user config with `keyboard.macStyleMappings = true` on a macOS host, **When** the system builds, **Then** the setting is ignored (macOS already uses Command key natively)

______________________________________________________________________

### User Story 3 - Consistent Keyboard Configuration for New Users (Priority: P3)

A new user sets up their keyboard preferences using a single, organized `keyboard` configuration block that groups all keyboard-related settings together, making the configuration intuitive and discoverable.

**Why this priority**: Improves the user experience for new users configuring their system for the first time. Having keyboard settings grouped under one namespace is more logical than scattered top-level fields.

**Independent Test**: Can be tested by creating a new user with the `keyboard` block and verifying all settings are applied correctly.

**Acceptance Scenarios**:

1. **Given** a new user using the developer template, **When** they create their config, **Then** the template includes the `keyboard` block with layout and macStyleMappings fields
1. **Given** a user config with all keyboard fields populated, **When** the system builds, **Then** all settings are applied: layouts on all platforms, mac-style mappings on Linux only

______________________________________________________________________

### Edge Cases

- What happens when `keyboard.layout` is an empty list? The system uses platform defaults (no layouts configured).
- What happens when `keyboard.macStyleMappings` is set but `keyboard.layout` is not? The mac-style mapping setting is applied independently — it controls modifier key behavior regardless of which layouts are active.
- What happens when a Niri family host uses `keyboard.macStyleMappings`? The setting applies to XKB options for the Niri compositor in the same way as GNOME.
- What happens when a user sets `keyboard.macStyleMappings = false` on GNOME? The GNOME dconf XKB options omit the `ctrl:swap_lwin_lctl` and `ctrl:swap_rwin_rctl` entries.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `keyboard` configuration namespace in the user schema that groups all keyboard-related settings
- **FR-002**: System MUST support a `keyboard.layout` field that accepts an ordered list of keyboard layout names, replacing the current `keyboardLayout` field
- **FR-003**: System MUST support a `keyboard.macStyleMappings` boolean field that controls whether Super and Ctrl modifier keys are swapped on Linux
- **FR-004**: The `keyboard.macStyleMappings` field MUST default to `true` to preserve existing behavior for current users
- **FR-005**: All existing modules that reference `keyboardLayout` MUST be updated to reference `keyboard.layout` instead
- **FR-006**: The Linux family system-level keyboard settings MUST conditionally apply the Super/Ctrl swap based on the `keyboard.macStyleMappings` value
- **FR-007**: The GNOME family user-level keyboard settings MUST conditionally apply the XKB swap options based on the `keyboard.macStyleMappings` value
- **FR-008**: The `keyboard.macStyleMappings` setting MUST have no effect on macOS (Darwin) builds
- **FR-009**: The legacy `keyboardLayout` field MUST be removed from the user schema
- **FR-010**: User templates MUST be updated to use the new `keyboard` namespace
- **FR-011**: All platform-specific keyboard translation layers MUST continue to function identically under the new path

### Key Entities

- **Keyboard Configuration**: A user-level configuration block containing layout preferences and modifier key behavior settings. Attributes: layout (list of layout names), macStyleMappings (boolean)
- **Keyboard Layout**: A platform-agnostic identifier for a keyboard layout (e.g., "canadian-english", "us") that gets translated to platform-specific representations
- **Mac-Style Mappings**: A behavioral setting that swaps Super and Ctrl modifier keys on Linux to provide a macOS-like keyboard experience

## Assumptions

- The default for `keyboard.macStyleMappings` is `true`, preserving the existing hardcoded behavior for all current Linux users
- macOS (Darwin) ignores the `macStyleMappings` setting entirely since macOS keyboards already have the Command key in the expected position
- The Niri family compositor respects the same `macStyleMappings` setting as GNOME when applying XKB options
- All existing keyboard layout names in the shared registry remain unchanged
- The `keyboard` namespace is flat (not deeply nested beyond `keyboard.layout` and `keyboard.macStyleMappings`)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of existing user configurations continue to build successfully after migrating from `keyboardLayout` to `keyboard.layout`
- **SC-002**: All platform-specific keyboard behaviors (layout selection, key repeat, input source switching) remain identical after the restructure
- **SC-003**: Users can disable mac-style modifier swapping on Linux by setting a single configuration value, with changes taking effect on the next system rebuild
- **SC-004**: The `nix flake check` command passes for all existing host/user combinations after the migration
