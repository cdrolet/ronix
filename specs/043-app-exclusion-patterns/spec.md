# Feature Specification: App Exclusion Patterns

**Feature Branch**: `043-app-exclusion-patterns`\
**Created**: 2026-02-07\
**Status**: Draft\
**Input**: User description: "I would like a way to exclude app from the user config so when using wildcards, it will not capture these application patterns. I was thinking about using the prefix '!' with potentially an app name or an app path. Path like '!ai/\*' should also work and will exclude all apps under the category 'ai'."

## User Scenarios & Testing

### User Story 1 - Exclude Specific App by Name (Priority: P1)

As a user using wildcards (e.g., `"*"`), I want to exclude specific applications by prefixing them with `"!"` so that I can install everything except apps I don't want.

**Why this priority**: Most common use case — user has `"*"` or `"category/*"` but wants to skip one or two specific apps.

**Independent Test**: User adds `["*", "!docker"]` to applications array, builds, and docker is not installed while all other apps are.

**Acceptance Scenarios**:

1. **Given** applications = `["*", "!docker"]`, **When** system builds, **Then** all apps except docker are installed
1. **Given** applications = `["dev/*", "!docker"]`, **When** system builds, **Then** all dev apps except docker are installed
1. **Given** applications = `["!docker"]` (exclusion without wildcard), **When** system builds, **Then** no apps are installed (exclusion only applies to wildcard results)
1. **Given** applications = `["*", "!nonexistent"]`, **When** system builds, **Then** all apps installed, exclusion of nonexistent app is silently ignored

______________________________________________________________________

### User Story 2 - Exclude Entire Category (Priority: P1)

As a user, I want to exclude an entire category of apps using `"!category/*"` so that I can install everything except one group.

**Why this priority**: Equally important as single-app exclusion — enables bulk exclusion of unwanted categories (e.g., `"!ai/*"` to skip all AI tools).

**Independent Test**: User adds `["*", "!ai/*"]` to applications array, builds, and no AI category apps are installed.

**Acceptance Scenarios**:

1. **Given** applications = `["*", "!ai/*"]`, **When** system builds, **Then** all apps except those in ai/ category are installed
1. **Given** applications = `["*", "!ai/*", "!games/*"]`, **When** system builds, **Then** all apps except ai and games categories are installed
1. **Given** applications = `["dev/*", "!ai/*"]`, **When** system builds, **Then** all dev apps installed (ai exclusion doesn't affect dev wildcard)

______________________________________________________________________

### User Story 3 - Mix Inclusions and Exclusions (Priority: P2)

As a user, I want to combine wildcards, explicit names, and exclusions in the same applications array so that I have full control over what gets installed.

**Why this priority**: Power-user scenario combining all patterns for precise control.

**Independent Test**: User config with `["*", "!ai/*", "chatgpt"]` installs everything, excludes all AI apps, but re-includes chatgpt specifically.

**Acceptance Scenarios**:

1. **Given** applications = `["*", "!ai/*", "chatgpt"]`, **When** system builds, **Then** all apps installed, ai category excluded, but chatgpt re-included
1. **Given** applications = `["dev/*", "!docker", "browser/*", "!firefox"]`, **When** system builds, **Then** dev apps minus docker, browser apps minus firefox
1. **Given** applications = `["*", "!docker", "docker"]`, **When** system builds, **Then** docker IS installed (explicit include overrides exclusion)

______________________________________________________________________

### Edge Cases

- What happens when exclusion pattern matches zero apps? Silently ignored (no warning).
- What happens with `["!docker"]` alone (no wildcard)? No apps installed — exclusions only subtract.
- What if same app is both excluded and explicitly included? Explicit include wins (order: expand wildcards → remove exclusions → add explicit includes).
- What about `"!*"` (exclude everything)? Valid — results in empty app list when combined with wildcards.
- Multi-level exclusion `"!ai/chat/*"`? Not supported — same restriction as wildcards (single-level only).

## Requirements

### Functional Requirements

- **FR-001**: System MUST support `"!appname"` syntax in user.applications to exclude a specific app from wildcard results
- **FR-002**: System MUST support `"!category/*"` syntax to exclude all apps in a category from wildcard results
- **FR-003**: Explicit app names (without `!` or `*`) MUST override exclusions (re-include)
- **FR-004**: Exclusion patterns MUST work with all existing wildcard types (`"*"`, `"category/*"`)
- **FR-005**: Exclusion of nonexistent apps MUST be silently ignored (no error, no warning)
- **FR-006**: System MUST reject multi-level exclusion patterns (`"!category/sub/*"`) with clear error
- **FR-007**: Processing order MUST be: expand wildcards → collect exclusions → remove excluded → add explicit includes
- **FR-008**: Exclusion patterns MUST respect hierarchical discovery (system → families → shared)
- **FR-009**: Existing configurations without exclusions MUST continue to work unchanged

### Key Entities

- **Exclusion Pattern**: String prefixed with `"!"` in user.applications (e.g., `"!docker"`, `"!ai/*"`)
- **Expanded App List**: Result after wildcard expansion and before exclusion filtering
- **Final App List**: Result after applying exclusions and re-adding explicit includes

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can exclude specific apps from wildcard results using `"!"` prefix
- **SC-002**: Users can exclude entire categories using `"!category/*"` syntax
- **SC-003**: Explicit includes override exclusions for fine-grained control
- **SC-004**: Existing configurations build identically (no breaking changes)
- **SC-005**: Exclusion resolution completes during nix evaluation phase (no runtime overhead)
