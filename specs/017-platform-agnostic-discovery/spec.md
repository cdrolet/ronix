# Feature Specification: Platform-Agnostic Discovery System

**Feature ID**: 017-platform-agnostic-discovery\
**Status**: Planning Complete\
**Priority**: P1 (Constitutional Violation Fix)

## Problem Statement

The current discovery system violates Constitution v2.2.0 Core Principle VI by hardcoding platform names ("darwin", "nixos") in `detectContext` and `buildSearchPaths` functions. This creates two critical issues:

1. **User configs locked to platforms**: Users referencing platform-specific apps get errors when building for different platforms, preventing cross-platform configurations
1. **Platform coupling**: Adding new platforms requires modifying discovery.nix code instead of just adding directory structure

## User Stories

### User Story 1 (P1): Dynamic Platform Discovery

**As a** repository maintainer\
**I want** platforms to be discovered automatically from the filesystem\
**So that** I can add new platforms without modifying discovery.nix code

**Acceptance Criteria**:

- Platforms are discovered by scanning `platform/` directory (excluding "shared")
- No hardcoded platform names in discovery.nix except "shared"
- Adding a new platform only requires creating `platform/{new-platform}/` directory structure
- Discovery system works for any platform name (darwin, nixos, nix-on-droid, kali, etc.)

**Independent Test**:

```bash
# Create test platform directory
mkdir -p platform/test-platform/app
echo '{ ... }' > platform/test-platform/app/test-app.nix

# Platform should be auto-discovered
nix eval --expr '
  let lib = (import <nixpkgs> {}).lib;
      discovery = import ./platform/shared/lib/discovery.nix { inherit lib; };
  in discovery.discoverPlatforms ./.
'
# Expected output: ["darwin" "nixos" "test-platform"]
```

______________________________________________________________________

### User Story 2 (P1): Context-Aware App Resolution with Graceful Degradation

**As a** user with configs across multiple platforms\
**I want** my user config to work on any platform\
**So that** I can maintain a single config referencing platform-specific apps

**Acceptance Criteria**:

- User configs can reference apps from any platform
- Apps not available on current platform are skipped (no error)
- Apps that don't exist anywhere throw helpful error with suggestions
- Profiles remain strict (error on missing apps)
- Context detection extracts platform dynamically from caller path

**Independent Test**:

```bash
# User config references darwin-only app
echo 'applications = ["git", "aerospace"];' > user/test/default.nix

# Build on darwin: succeeds, imports both
nix build .#darwinConfigurations.test-home.system

# Build on nixos: succeeds, imports only git (skips aerospace)
# nix build .#nixosConfigurations.test-desktop.config.home-manager.users.test.home.file
```

______________________________________________________________________

### User Story 3 (P2): App Registry and Validation

**As a** user making typos in app names\
**I want** helpful error messages with suggestions\
**So that** I can quickly fix mistakes

**Acceptance Criteria**:

- Build complete app registry mapping app names to platforms
- Validate requested apps exist somewhere in repository
- Provide "did you mean?" suggestions for typos
- List all available apps when app not found
- Distinguish between "doesn't exist" vs "wrong platform"

**Independent Test**:

```bash
# Reference non-existent app
echo 'applications = ["aerospc"];' > user/test/default.nix

# Error message should include:
# - "Application 'aerospc' not found in any platform"
# - "Did you mean: aerospace, aerc?"
# - List of all available apps by platform
```

______________________________________________________________________

### User Story 4 (P3): Improved Error Messages

**As a** developer debugging discovery issues\
**I want** context-aware error messages\
**So that** I understand what went wrong and how to fix it

**Acceptance Criteria**:

- Errors show which platform the caller is building for
- Errors show which directories were searched
- Errors distinguish user configs (graceful) vs profiles (strict)
- Errors show calling file path for context
- Errors include actionable tips for resolution

**Independent Test**:

```bash
# Profile references unavailable app
echo 'applications = ["aerospace"];' > platform/nixos/profiles/test/default.nix

# Error should show:
# - "Application 'aerospace' not found in platform 'nixos'"
# - "Available in other platforms: darwin: platform/darwin/app/aerospace.nix"
# - "Searched in current context: platform/nixos/app, platform/shared/app"
# - "Tip: Remove from this profile's application list"
```

______________________________________________________________________

## Non-Functional Requirements

### Performance

- Evaluation time increase: \<100ms for typical 50-app repository
- No regression in build times (discovery is evaluation-time only)

### Compatibility

- 100% backward compatible - existing configs work without changes
- No changes to public API (`mkApplicationsModule`, `discoverUsers`, `discoverProfiles`)

### Code Quality

- Module size remains under 250 lines (split into sub-modules if needed)
- All functions remain pure (no side effects)
- No Import From Derivation (IFD)

### Documentation

- Update CLAUDE.md with new approach
- Quickstart.md explains cross-platform usage
- API contracts document all functions

## Out of Scope

- Caching layer (only if evaluation time exceeds 2 seconds)
- App metadata and dependencies (future extension)
- Profile-specific app overrides (future extension)
- Multi-level search paths (future extension)

## Success Metrics

1. **Constitutional Compliance**: No hardcoded platforms in discovery.nix
1. **Cross-Platform**: User configs build successfully on multiple platforms
1. **Extensibility**: New platform added by creating directory only
1. **Developer Experience**: Error messages provide actionable guidance
1. **Performance**: Evaluation time under 1 second for typical configs

## Technical Constraints

- Must work at Nix evaluation time (no runtime dependencies)
- Pure functions only (deterministic, no side effects)
- Limited to `builtins.readDir` and `builtins.pathExists` for filesystem access
- Must maintain existing directory structure (no breaking changes)
