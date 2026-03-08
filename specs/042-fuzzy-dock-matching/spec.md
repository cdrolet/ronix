# Feature Specification: Fuzzy Dock Application Matching

**Feature Branch**: `042-fuzzy-dock-matching`\
**Created**: 2025-02-04\
**Status**: Draft\
**Input**: User description: "when defining docked application in user.docked config, if an application is not found with exact name and current path logic, a fallback should try to find a app with a tolerant approach such as containing the name without being case sensitive and by not considering the path .. by example, "calculator" should be found in gnome since org.gnome.Calculator without path and case is simply calculator. for "settings" by example, since in darwin it's "system settings", it contain the word settings and should be close enough if no exact match are found. then we can removed duplicated entries in user.docked for supporting multiple systems"

## Clarifications

### Session 2025-02-04

- Q: When multiple applications match a fuzzy search term, what order should the system prioritize them? → A: Precise 5-step matching cascade: (1) Exact match with case, (2) Exact match case-insensitive, (3) Exact match on app name without path/namespace, (4) Word match in app name without path, (5) Skip entry if no match. No guessing - deterministic or nothing.
- Q: What is the expected scale of application search - how many applications should the fuzzy matcher be prepared to handle per platform? → A: 100-500 apps per platform (typical desktop environments, no indexing optimization needed).
- Q: Should the system provide any visibility into which matching strategy was used for each dock entry? → A: Summary at end of build listing all resolved apps and their strategies.

## User Scenarios & Testing

### User Story 1 - Simple Cross-Platform Dock Configuration (Priority: P1)

Users want to define their dock layout once using simple, intuitive names (like "calculator", "settings", "mail") without needing to know platform-specific application names or paths. The system should automatically find the correct application on each platform.

**Why this priority**: This is the core value proposition - enabling users to write portable dock configurations. Without this, users must maintain separate dock entries for each platform, defeating the purpose of the shared configuration system.

**Independent Test**: Can be fully tested by defining a user.docked array with simple names like ["calculator", "settings", "mail"] and verifying it works on both Darwin and NixOS/GNOME without duplicates.

**Acceptance Scenarios**:

1. **Given** a user config with `docked = ["calculator"]`, **When** system builds on GNOME, **Then** dock includes org.gnome.Calculator
1. **Given** a user config with `docked = ["calculator"]`, **When** system builds on Darwin, **Then** dock includes Calculator.app
1. **Given** a user config with `docked = ["settings"]`, **When** system builds on GNOME, **Then** dock includes org.gnome.Settings
1. **Given** a user config with `docked = ["settings"]`, **When** system builds on Darwin, **Then** dock includes System Settings.app

______________________________________________________________________

### User Story 2 - Eliminate Duplicate Platform-Specific Entries (Priority: P2)

Users should be able to remove duplicate dock entries that currently exist for cross-platform compatibility. The fuzzy matching should make configurations like `["calculator", "org.gnome.Calculator"]` unnecessary - a single `"calculator"` entry should work everywhere.

**Why this priority**: Reduces configuration maintenance burden and improves readability. This is a natural follow-on to P1, cleaning up what the fuzzy matching enables.

**Independent Test**: Can be tested by comparing a user.docked config before/after - configs with duplicates should produce identical dock layouts after migration to single entries.

**Acceptance Scenarios**:

1. **Given** a user config with platform-duplicates removed, **When** system builds on any platform, **Then** all expected applications appear in dock
1. **Given** a simplified dock config, **When** compared to legacy config, **Then** resulting dock layout is identical on all platforms
1. **Given** a user config with only simple names, **When** switching between platforms, **Then** dock contains correct platform-specific applications

______________________________________________________________________

### User Story 3 - Graceful Handling of Missing Applications (Priority: P3)

When an application name cannot be resolved on a specific platform (exact match fails, fuzzy match fails), the system should skip that entry silently rather than failing the build. This allows users to include platform-specific apps in shared configs.

**Why this priority**: Nice-to-have for platform-specific apps in shared configs, but not critical for the core fuzzy matching functionality.

**Independent Test**: Can be tested by including a Darwin-only app name in the config and verifying NixOS build succeeds (skips the entry) and Darwin build includes it.

**Acceptance Scenarios**:

1. **Given** a dock config with `["utm"]` (Darwin-only), **When** system builds on NixOS, **Then** build succeeds and utm is silently skipped
1. **Given** a dock config with `["nautilus"]` (GNOME-only), **When** system builds on Darwin, **Then** build succeeds and nautilus is silently skipped
1. **Given** a dock config with mix of cross-platform and platform-specific apps, **When** system builds on any platform, **Then** only available apps appear in dock

______________________________________________________________________

### Edge Cases

- What happens when a user provides both exact match and fuzzy match for same app (e.g., `["calculator", "org.gnome.Calculator"]`)?
  - **Resolution**: Deduplicate - if fuzzy match resolves to same app as exact match, only include once
- How does fuzzy matching handle apps with special characters or numbers in names?
  - **Resolution**: Strip special characters and compare alphanumeric content only during matching
- What about apps with very similar names (e.g., "Firefox" vs "Firefox Developer Edition")?
  - **Resolution**: The 5-step matching cascade handles this deterministically - exact match wins, otherwise word-boundary match applies

## Requirements

### Functional Requirements

- **FR-001**: System MUST apply matching strategies in strict order: (1) exact match with case, (2) exact match case-insensitive, (3) exact match on app name without path/namespace (e.g., "terminal" matches "org.gnome.Terminal"), (4) word match in app name without path (e.g., "settings" matches "System Settings"), (5) skip entry if no match found
- **FR-002**: System MUST strip path/namespace prefixes when performing strategies 3-4 (e.g., remove "org.gnome." from "org.gnome.Calculator")
- **FR-003**: System MUST perform word-boundary matching for strategy 4 (e.g., "settings" matches "System Settings" but not "Settingsapp")
- **FR-004**: System MUST stop at first successful match in the cascade and not attempt further strategies
- **FR-005**: System MUST silently skip dock entries that reach strategy 5 (no match found) without failing the build
- **FR-006**: System MUST deduplicate dock entries that resolve to the same application after fuzzy matching
- **FR-007**: System MUST preserve dock entry order from user configuration after fuzzy matching and deduplication
- **FR-008**: System MUST work with existing dock features (separators "|" and "||", folders "/Downloads")
- **FR-009**: Users MUST be able to override fuzzy matching by providing exact application names when desired
- **FR-010**: System MUST handle special characters in application names by stripping them during comparison (alphanumeric-only matching)
- **FR-011**: System MUST handle application search scale of 100-500 apps per platform without performance optimization (simple linear search acceptable)
- **FR-012**: System MUST output a build-time summary listing all dock entries with their resolved applications and matching strategies used (or "skipped" for strategy 5)

### Non-Functional Requirements

- **NFR-001**: Matching process completes during build evaluation (no runtime performance requirements - evaluation time)
- **NFR-002**: Search algorithm can use simple linear iteration - no indexing or caching required for 100-500 app scale
- **NFR-003**: Matching is purely deterministic - no heuristics, machine learning, or probabilistic approaches
- **NFR-004**: Build summary output is concise and readable (one line per dock entry showing: user input → resolved app [strategy])

### Key Entities

- **Dock Entry**: User-provided string representing an application, separator, or folder. Can be simple name (fuzzy) or exact name/path
- **Application Match**: Resolved application name/path for a dock entry on a specific platform
- **Match Strategy**: One of five ordered strategies: (1) exact case-sensitive, (2) exact case-insensitive, (3) exact without path, (4) word-boundary, (5) no match/skip
- **Application Catalog**: Platform-specific list of available applications (100-500 entries) searched during matching
- **Match Summary**: Build-time output showing dock entry resolution results (user input, resolved app, strategy used)

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can define dock configuration with simple names and it works on both Darwin and GNOME platforms without modification
- **SC-002**: User dock configurations reduce in size by at least 30% by eliminating platform-specific duplicates
- **SC-003**: 95% of common applications (calculator, settings, mail, browser, terminal) resolve correctly using simple names on both platforms
- **SC-004**: Zero build failures caused by unresolvable dock entries (all handled gracefully via strategy 5)
- **SC-005**: Dock entry order is preserved exactly as specified in user configuration after fuzzy matching
- **SC-006**: Matching is deterministic - same input always produces same output on same platform
- **SC-007**: Matching completes within build evaluation time for typical user configs (10-30 dock entries against 100-500 available apps)
- **SC-008**: Build summary clearly shows which strategy resolved each dock entry, allowing users to verify matching behavior

## Assumptions

- Application names follow common patterns across platforms (descriptive English words)
- Platforms provide consistent application metadata (names, paths, desktop files)
- Users prefer simpler configurations over explicit control when both are equivalent
- Most users want same application layout across all their machines
- The 5-step matching cascade covers >95% of user intent without ambiguity
- Users may occasionally need to use exact names to disambiguate, and that's acceptable
- Word-boundary matching (strategy 4) is sufficient for multi-word app names
- 100-500 apps per platform is sufficient scope (covers typical desktop + Homebrew casks)
- Linear search performance acceptable for this scale during build evaluation
- Build-time summary output is sufficient for debugging (no runtime/interactive debugging needed)

## Dependencies

- Existing dock configuration system (Feature 023: user-dock-config)
- Platform-specific dock implementation (dockutil for Darwin, gsettings for GNOME)
- Application discovery mechanisms on each platform

## Out of Scope

- User-configurable fuzzy matching rules or priorities
- Machine learning or advanced matching algorithms
- Automatic suggestion/correction of misspelled application names
- Support for dock entries beyond applications, separators, and folders
- Migration tool to automatically simplify existing user.docked configs (users update manually)
- Visual diff showing what fuzzy matching resolved to (debugging feature for future)
- Heuristics like "prefer default apps" or "shortest name wins" - strictly deterministic cascade only
- Performance optimization for >500 applications (indexing, caching, pre-compilation)
- Interactive or runtime debugging of match resolution (build-time summary only)
- Logging/tracing infrastructure beyond build summary (no persistent logs, metrics, or traces)
