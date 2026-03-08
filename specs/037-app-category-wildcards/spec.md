# Feature Specification: App Category Wildcards

**Feature Branch**: `037-app-category-wildcards`\
**Created**: 2026-01-03\
**Status**: Draft\
**Input**: User description: "As a user, I want to be able to install a category of app by using wildcard in this fashion: "productivity/*" "browser/*""

## User Scenarios & Testing

### User Story 1 - Install All Apps in a Category (Priority: P1)

As a user managing my nix-config, I want to install all applications in a specific category by using a wildcard pattern (e.g., "productivity/\*") so that I can quickly add entire groups of related applications without listing each one individually.

**Why this priority**: Core functionality that provides immediate value by simplifying bulk app installation and reducing configuration maintenance.

**Independent Test**: User adds "browser/\*" to their applications array, runs `just install`, and all browser apps (zen, brave, firefox, etc.) are installed.

**Acceptance Scenarios**:

1. **Given** user has "browser/*" in their applications array, **When** they run `just install <user> <host>`, **Then** all apps in system/*/app/browser/ are installed
1. **Given** user has "productivity/\*" in applications, **When** system builds, **Then** all productivity category apps are discovered and installed
1. **Given** user has both specific apps ("git") and wildcards ("dev/\*"), **When** installation runs, **Then** both explicit and wildcard-matched apps are installed without duplicates
1. **Given** user has "games/\*" wildcard, **When** new game apps are added to the category later, **Then** next rebuild automatically includes the new apps without config changes

______________________________________________________________________

### User Story 2 - Mix Wildcards and Explicit App Names (Priority: P1)

As a user, I want to combine wildcard patterns with explicit app names in my applications array so that I can install entire categories plus specific apps from other categories.

**Why this priority**: Essential flexibility - users need both bulk and selective installation in the same configuration.

**Independent Test**: User config with ["dev/\*", "zen", "obsidian"] successfully installs all dev apps plus zen and obsidian.

**Acceptance Scenarios**:

1. **Given** applications = ["dev/\*", "zen", "bitwarden"], **When** installation runs, **Then** all dev apps AND zen AND bitwarden are installed
1. **Given** applications = ["\*"], **When** system builds, **Then** ALL available apps across ALL categories are installed
1. **Given** applications = ["browser/\*", "brave"], **When** installation runs, **Then** brave is not installed twice (deduplication works)
1. **Given** applications = \["productivity/*", "design/*"\], **When** system builds, **Then** all apps from both categories are installed

______________________________________________________________________

### User Story 3 - Platform-Specific Category Wildcards (Priority: P2)

As a user with multiple platforms (darwin, nixos), I want wildcard patterns to automatically discover apps from the correct platform hierarchy so that the same config works across platforms.

**Why this priority**: Critical for cross-platform consistency - aligns with repository's platform-agnostic philosophy.

**Independent Test**: Same user config with "browser/\*" installs platform-specific browsers on darwin (via Homebrew) and nixos (via nixpkgs) correctly.

**Acceptance Scenarios**:

1. **Given** darwin user has "browser/\*", **When** installation runs, **Then** apps are discovered from system/darwin/app/browser/ AND system/shared/app/browser/
1. **Given** nixos user has "productivity/\*", **When** system builds, **Then** apps are discovered from system/nixos/app/productivity/ AND system/shared/app/productivity/ AND family-specific paths
1. **Given** user has "games/\*" on both platforms, **When** each platform builds, **Then** each gets appropriate platform-specific games without cross-contamination
1. **Given** family = ["gnome"] and "utility/\*" wildcard, **When** nixos builds, **Then** apps discovered from system/shared/family/gnome/app/utility/ are included

______________________________________________________________________

### User Story 4 - Hierarchical Discovery with Wildcards (Priority: P2)

As a user with family-based hosts (e.g., family = ["linux", "gnome"]), I want category wildcards to respect the hierarchical discovery system so that wildcards search platform → families → shared in order.

**Why this priority**: Maintains architectural integrity - wildcards must work with existing discovery system.

**Independent Test**: GNOME user with "productivity/\*" gets apps from system → gnome → linux → shared hierarchy.

**Acceptance Scenarios**:

1. **Given** gnome family host with "productivity/\*", **When** discovery runs, **Then** apps resolved in order: system/nixos/app/productivity/ → system/shared/family/gnome/app/productivity/ → system/shared/family/linux/app/productivity/ → system/shared/app/productivity/
1. **Given** same app name exists in multiple hierarchy levels, **When** wildcard resolves, **Then** first match wins (no duplicates, follows existing hierarchy precedence)
1. **Given** user without families has "dev/\*", **When** discovery runs, **Then** apps found from system/{platform}/app/dev/ and system/shared/app/dev/ only
1. **Given** wildcard pattern matches no apps in hierarchy, **When** installation runs, **Then** clear warning message explains which category was empty

______________________________________________________________________

### User Story 5 - Validation and Error Handling (Priority: P3)

As a user, I want clear error messages when wildcard patterns are invalid or produce unexpected results so that I can quickly fix configuration issues.

**Why this priority**: Important for usability but not blocking - users can work without it using explicit app names.

**Independent Test**: User adds invalid wildcard "nonexistent-category/\*" and receives clear error during build.

**Acceptance Scenarios**:

1. **Given** applications = ["invalid/\*"], **When** nix flake check runs, **Then** clear error indicates which wildcard matched zero apps
1. **Given** applications = ["browser"], **When** validation runs, **Then** warning suggests "Did you mean browser/\*?"
1. **Given** applications = \["*/*"\], **When** validation runs, **Then** error explains only single-level wildcards are supported ("category/*" not "category/sub/*")
1. **Given** applications = \["dev/*", "dev/*"\], **When** deduplication runs, **Then** duplicate wildcards are silently handled (no error, just deduplicated apps)

______________________________________________________________________

### Edge Cases

- What happens when a wildcard pattern matches zero apps? (Empty category)
- How does system handle duplicate apps from different hierarchy levels with wildcards?
- What if user has both wildcard ("browser/\*") and explicit app from same category ("brave") in applications array?
- How does deduplication work when multiple wildcards resolve to the same app?
- What happens when new app is added to a category after initial install? (Does it auto-install on next rebuild?)
- How does "\*" (all apps) wildcard interact with settings array? (Should settings support wildcards too, or only apps?)
- What if a platform-specific category doesn't exist on another platform? (e.g., "darwin-only/\*" on nixos)
- How does system handle symbolic links or circular references in app directories?
- What happens if user specifies both inclusive wildcard ("dev/*") and explicit exclusion pattern? (Future: "dev/*" "!dev/docker")

## Requirements

### Functional Requirements

- **FR-001**: System MUST support wildcard pattern "category/\*" in user.applications array to match all apps in that category
- **FR-002**: System MUST support "\*" wildcard to match ALL available apps across ALL categories
- **FR-003**: System MUST resolve wildcards using hierarchical discovery system (system → families → shared)
- **FR-004**: System MUST deduplicate apps when same app is matched by multiple patterns or explicit names
- **FR-005**: System MUST support mixing wildcards and explicit app names in the same applications array
- **FR-006**: System MUST work on both darwin and nixos platforms with same wildcard syntax
- **FR-007**: System MUST validate wildcard patterns at evaluation time (nix flake check)
- **FR-008**: System MUST provide clear error messages when wildcard matches zero apps
- **FR-009**: System MUST automatically include newly-added apps in matching wildcard categories on next rebuild
- **FR-010**: Wildcard resolution MUST respect family-based hierarchical discovery when host declares families
- **FR-011**: System MUST prevent duplicate app installation when app is specified both explicitly and via wildcard
- **FR-012**: System MUST support wildcards in cross-platform shared apps (system/shared/app/)
- **FR-013**: Wildcard discovery MUST be pure (no side effects, deterministic results)

### Key Entities

- **Wildcard Pattern**: String in format "category/*" or "*" that expands to multiple app names
- **Category**: Directory name under system/\*/app/ (e.g., "browser", "productivity", "dev")
- **App Discovery Function**: Extended version of existing `resolveApplications` that handles wildcard expansion
- **Resolved App List**: Deduplicated list of app paths after wildcard expansion and hierarchy search

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can install all apps in a category by adding one wildcard pattern instead of N explicit app names
- **SC-002**: Adding "browser/\*" installs 100% of available browser apps without manual enumeration
- **SC-003**: Configuration with wildcards builds successfully on both darwin and nixos without modifications
- **SC-004**: Wildcard resolution completes during nix evaluation phase (no runtime overhead)
- **SC-005**: Users adding new app to category see it auto-installed on next rebuild without config changes
- **SC-006**: Configuration lines reduced by up to 90% for users with many apps in same category
- **SC-007**: Zero duplicate apps installed when combining wildcards and explicit names
- **SC-008**: Wildcard errors are detected at `nix flake check` time, not at installation time

## Scope

### In Scope

- Wildcard expansion for user.applications array
- Single-level wildcards (category/\*)
- Global wildcard (\*) for all apps
- Hierarchical discovery integration (respecting families)
- Deduplication of wildcard matches with explicit app names
- Validation and error messaging for invalid wildcards
- Cross-platform support (darwin + nixos)
- Documentation of wildcard syntax in CLAUDE.md

### Out of Scope

- Multi-level wildcards (category/subcategory/\*)
- Exclusion patterns (category/\* !specific-app)
- Regex or complex pattern matching beyond simple "\*"
- Wildcard support for settings array (settings remain explicit)
- Wildcard support for docked array (dock items remain explicit)
- Conditional wildcards based on platform or context
- App version pinning or selection via wildcards
- Wildcard expansion for other user fields (fonts, etc.)

## Assumptions

- Existing app discovery system (`discoverApplications`, `resolveApplications`) can be extended to handle wildcards
- Category names are directory names under system/\*/app/ (one level deep)
- Wildcard expansion happens at Nix evaluation time, not at runtime
- Deduplication uses app module path as unique identifier
- Users expect wildcard behavior similar to shell glob patterns
- Performance impact of wildcard expansion is negligible (few hundred apps max)
- App categories are well-organized and meaningful to users

## Dependencies

- **Existing discovery system** (system/shared/lib/discovery.nix): Must extend `resolveApplications` to handle wildcards
- **Feature 020** (App Array Config): Pure data application arrays that wildcards will expand
- **Feature 021** (Host/Family Architecture): Hierarchical discovery that wildcards must respect
- **Nix builtins**: `builtins.readDir`, `builtins.match`, list manipulation functions

## Non-Functional Requirements

- **NFR-001**: Wildcard expansion must be deterministic (same input always produces same app list)
- **NFR-002**: Wildcard resolution must complete in under 1 second for repositories with up to 200 apps
- **NFR-003**: Error messages must clearly indicate which wildcard pattern failed and why
- **NFR-004**: Wildcard syntax must be intuitive to users familiar with shell glob patterns
- **NFR-005**: Implementation must not break existing configurations without wildcards (backward compatible)
- **NFR-006**: Wildcard expansion must be lazy (only resolve when applications array is accessed)
