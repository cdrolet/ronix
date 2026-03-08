# Feature Specification: Darwin System Defaults Restructuring and Migration

**Feature Branch**: `002-darwin-system-restructure`\
**Created**: 2025-10-26\
**Status**: Draft\
**Input**: User description: "Restructure modules/darwin/defaults.nix into modular system folder with topic-specific files (finder, dock, etc.), migrate dotfiles system.sh configuration to corresponding Nix files, establish standard structure for all module types (darwin, nixos), and update constitution with derived principles."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Restructure Darwin System Defaults (Priority: P1)

As a system administrator managing the nix-config repository, I need the Darwin system defaults organized by topic (Finder, Dock, Trackpad, etc.) in separate files under a system folder, so that related configurations are grouped together and easier to maintain.

**Why this priority**: This is the foundational structural change that enables all other work. Without this reorganization, migration and future maintenance cannot proceed effectively.

**Independent Test**: Can be fully tested by running `darwin-rebuild switch` and verifying that all existing system defaults still apply correctly after restructuring, without adding any new configurations.

**Acceptance Scenarios**:

1. **Given** the current monolithic `modules/darwin/defaults.nix` file exists, **When** the restructuring is complete, **Then** there should be a `modules/darwin/system/` folder containing a `default.nix` file that imports all topic-specific modules
1. **Given** the restructured files, **When** each topic file (finder.nix, dock.nix, trackpad.nix, etc.) is examined, **Then** it should contain only settings relevant to that specific topic
1. **Given** the restructured configuration, **When** applying the configuration with `darwin-rebuild switch`, **Then** all previously configured system defaults should continue to work identically to before
1. **Given** the old `modules/darwin/defaults.nix` file, **When** the restructuring is complete, **Then** it should be removed or clearly marked as deprecated

______________________________________________________________________

### User Story 2 - Migrate Dotfiles System Defaults (Priority: P2)

As a system administrator consolidating configurations, I need all macOS system defaults from the dotfiles repository's `scripts/sh/darwin/system.sh` migrated to the appropriate Nix files in the darwin system folder, so that all system configuration is centralized in nix-config.

**Why this priority**: This adds value on top of the restructured foundation. It can be tested independently after P1 is complete by verifying new settings are applied.

**Independent Test**: Can be tested by comparing system defaults before and after migration using `defaults read` commands, and verifying that settings from system.sh are now active through Nix configuration.

**Acceptance Scenarios**:

1. **Given** the dotfiles `scripts/sh/darwin/system.sh` contains system preference commands, **When** migration is complete, **Then** all equivalent settings should exist in the appropriate topic-specific Nix files (e.g., keyboard settings in keyboard.nix)
1. **Given** a setting exists in both the current defaults.nix and system.sh, **When** migrating, **Then** the system.sh version should be evaluated and merged appropriately, with conflicts documented
1. **Given** the migrated Nix configuration, **When** applying it with `darwin-rebuild switch`, **Then** the system should reflect all settings from both the original defaults.nix and system.sh
1. **Given** settings that cannot be expressed in nix-darwin, **When** migration is complete, **Then** these should be documented with explanations and alternative approaches suggested

______________________________________________________________________

### Edge Cases

- **What happens when a system setting could logically belong to multiple topics (e.g., a keyboard shortcut that affects Finder)?**

  - Application-specific settings belong to their respective application files (e.g., Finder keyboard shortcuts go in finder.nix)
  - The keyboard.nix file contains only system-wide keyboard settings that apply globally across all applications
  - When in doubt, settings should be placed with the application or component they affect, not with the input mechanism

- **How does the system handle settings in system.sh that use bash utilities or functions not available in Nix?**

  - Focus on the intent of the setting rather than the specific bash implementation
  - Find alternative Nix-native approaches that achieve the same end result
  - Settings that cannot be properly replicated in Nix must be documented in an `unresolved-migration.md` file
  - This unresolved migration documentation pattern is the standard for all future migrations

- **What happens when nix-darwin doesn't support a particular macOS default available in system.sh?**

  - Document unsupported settings in `unresolved-migration.md` with explanations of what they do
  - Investigate alternative approaches (e.g., using CustomUserPreferences or system activation scripts)
  - Track these as future work items for potential nix-darwin contributions

- **How should deprecated or macOS version-specific settings be handled during migration?**

  - Do NOT migrate deprecated settings
  - Create a post-migration report documenting all deprecated settings that were intentionally skipped
  - Include reasoning for why each deprecated setting was excluded

- **What happens if there are conflicts between settings in the current defaults.nix and system.sh?**

  - The migrated system.sh settings take precedence over current defaults.nix settings
  - The new defaults.nix becomes solely an orchestration file that imports topic-specific modules
  - All actual settings are removed from defaults.nix and placed in appropriate topic files
  - Conflicts are resolved by using the system.sh version as it represents the more comprehensive configuration

## Requirements *(mandatory)*

### Functional Requirements

**Structure & Organization**

- **FR-001**: System MUST reorganize `modules/darwin/defaults.nix` into a `modules/darwin/system/` folder structure
- **FR-002**: System MUST create a `modules/darwin/system/default.nix` that imports all topic-specific modules
- **FR-003**: System MUST separate settings into topic-specific files including at minimum: dock.nix, finder.nix, trackpad.nix, keyboard.nix, and screen.nix
- **FR-004**: Each topic file MUST contain only settings directly related to that topic's functionality
- **FR-005**: System MUST maintain identical functional behavior after restructuring (no settings lost or changed)

**Migration**

- **FR-006**: System MUST migrate all applicable settings from `~/project/dotfiles/scripts/sh/darwin/system.sh` to corresponding Nix files
- **FR-007**: System MUST map bash `defaults write` commands to equivalent nix-darwin configuration options where supported
- **FR-008**: System MUST document settings that cannot be migrated in an `unresolved-migration.md` file with explanations and alternative approaches
- **FR-009**: System MUST resolve conflicts by giving precedence to system.sh settings and removing all actual settings from defaults.nix (which becomes import-only)
- **FR-010**: Migrated settings MUST be organized into appropriate topic-specific files, with application-specific settings (including shortcuts) placed in application files rather than input mechanism files
- **FR-011**: System MUST NOT migrate deprecated settings, but MUST document them in a post-migration report with exclusion reasoning
- **FR-012**: System MUST focus on replicating the intent of bash-based settings using Nix-native approaches rather than literal translation

**Standardization**

- **FR-013**: System MUST establish naming conventions for topic-specific files that are consistent and descriptive
- **FR-014**: System MUST establish `unresolved-migration.md` as the standard documentation pattern for future migrations

**Validation**

- **FR-021**: System MUST provide a way to validate that restructured configuration produces identical results to the original
- **FR-022**: System MUST verify that all migrated settings from system.sh are actually applied after darwin-rebuild

### Key Entities

- **System Default**: A macOS system preference or setting that can be configured via `defaults write` commands or nix-darwin options
- **Topic Domain**: A logical grouping of related system settings (e.g., Dock, Finder, Trackpad, Keyboard, Security)
- **Module**: A Nix file containing configuration for a specific aspect of the system
- **Migration Mapping**: The correspondence between a bash `defaults write` command and its nix-darwin equivalent
- **Constitution Rule**: A documented principle or guideline governing how the nix-config repository should be organized and maintained

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All system defaults from the original defaults.nix file continue to function identically after restructuring (verified via system behavior testing)
- **SC-002**: At least 80% of applicable settings from dotfiles system.sh are successfully migrated to Nix configuration (measured by comparing setting counts)
- **SC-003**: The darwin/system folder contains at least 8 topic-specific files with clear domain boundaries (dock, finder, trackpad, keyboard, screen, security, etc.)
- **SC-004**: Zero regressions in system behavior after applying the restructured configuration (all existing functionality preserved)
- **SC-005**: Migration documentation (unresolved-migration.md, deprecated-settings.md) is complete and comprehensive

## Assumptions

- The `~/project/dotfiles/scripts/sh/darwin/system.sh` file is the authoritative source for system configuration (takes precedence in conflicts)
- Settings from system.sh should be preserved during migration unless deprecated
- The current defaults.nix will be transformed into an import-only orchestration file with no actual settings
- The nix-darwin framework supports most common macOS system defaults through its `system.defaults` options
- Some settings from system.sh may not have direct nix-darwin equivalents and will need alternative approaches or documentation
- Breaking settings into topic-specific files improves maintainability without introducing complexity
- Application-specific settings (including shortcuts) belong with the application, not with input mechanism files

## Dependencies

- nix-darwin framework and its available configuration options
- Access to the dotfiles repository at `~/project/dotfiles`
- Understanding of macOS system defaults and their organization
- Ability to test configuration changes on a macOS system

## Out of Scope

- Migrating non-system settings from dotfiles (application configurations, shell settings, etc.)
- Creating new system settings not present in either defaults.nix or system.sh
- Restructuring modules other than darwin (covered in spec 005-nix-config-documentation)
- Documentation of the darwin system structure (covered in spec 005-nix-config-documentation)
- Constitution updates (covered in spec 005-nix-config-documentation)
- Implementing automated testing infrastructure for system defaults
- Converting system.sh bash utilities or helper functions to Nix equivalents
- Migrating startup applications, dock item configurations, or other dynamic system state
