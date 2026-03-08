# Implementation Plan: Fuzzy Dock Application Matching

**Branch**: `042-fuzzy-dock-matching` | **Date**: 2025-02-04 | **Spec**: [spec.md](./spec.md)\
**Input**: Feature specification from `/specs/042-fuzzy-dock-matching/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable portable dock configurations using simple application names ("calculator", "settings") that work across Darwin and GNOME platforms through a deterministic 5-step matching cascade. Eliminates duplicate platform-specific entries (e.g., "calculator" + "org.gnome.Calculator") by automatically resolving simple names to platform-specific app paths. Build-time summary shows resolution strategy for each entry.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: nixpkgs lib (builtins.filter, builtins.match, lib.strings), existing dock module (Feature 023)\
**Storage**: N/A (evaluation-time transformation, no persistent state)\
**Testing**: nix flake check (syntax), manual testing on Darwin + NixOS with sample dock configs\
**Target Platform**: Darwin (nix-darwin) + NixOS (GNOME family)\
**Project Type**: Nix configuration library (pure functional transformation)\
**Performance Goals**: Complete matching for 10-30 dock entries against 100-500 available apps during build evaluation (\<1 second)\
**Constraints**: Pure functional (no side effects), deterministic output, linear search only (no indexing)\
**Scale/Scope**: Single helper function, ~100-150 lines total, integrated into existing dock settings modules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Module Size Compliance

- **Requirement**: Each module file MUST be under 200 lines
- **Status**: PASS - Fuzzy matching logic ~100-150 lines, within limit
- **Evidence**: Helper function in lib/, invoked by existing dock modules

### ✅ Single Responsibility

- **Requirement**: Each file configures one functional domain only
- **Status**: PASS - Single responsibility: resolve dock entry names to platform paths
- **Evidence**: New `fuzzy-dock-matcher.nix` in `system/shared/lib/`

### ✅ Context Validation

- **Requirement**: Settings/apps MUST use lib.optionalAttrs with (options ? home) check
- **Status**: PASS - Fuzzy matching runs during evaluation, no context-specific options used
- **Evidence**: Pure function transformation, no home.\* or system.\* options accessed

### ✅ Documentation Required

- **Requirement**: All modules MUST include header documentation with purpose, dependencies, usage
- **Status**: PASS - Will include comprehensive header with 5-step cascade explanation
- **Evidence**: Template includes function signature, examples, edge case handling

### ✅ Platform Abstraction

- **Requirement**: Platform-agnostic code in shared/, platform-specific in darwin/nixos/
- **Status**: PASS - Matching logic is platform-agnostic (in shared/lib/), platform-specific app catalogs provided by callers
- **Evidence**: `fuzzy-dock-matcher.nix` in `system/shared/lib/`, platform libs call it

### ✅ Determinism

- **Requirement**: Pure, deterministic configurations with no network access
- **Status**: PASS - Pure functional transformation, no I/O, deterministic 5-step cascade
- **Evidence**: Same inputs always produce same outputs (NFR-003)

### ✅ No Backward Compatibility

- **Requirement**: Breaking changes permitted, no compatibility layers
- **Status**: PASS - Existing dock configs continue to work (exact matches), new fuzzy matching is additive
- **Evidence**: FR-009 ensures override capability, no breaking changes to existing behavior

## Project Structure

### Documentation (this feature)

```text
specs/042-fuzzy-dock-matching/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file (/speckit.plan output)
├── research.md          # Phase 0 output (PENDING)
├── data-model.md        # Phase 1 output (PENDING)
├── quickstart.md        # Phase 1 output (PENDING)
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
system/
├── shared/
│   ├── lib/
│   │   ├── discovery.nix                    # Existing - app/module discovery
│   │   ├── file-associations.nix            # Existing - file associations helper
│   │   └── fuzzy-dock-matcher.nix           # NEW - fuzzy matching logic (this feature)
│   └── settings/
│       └── user/
│           └── dock.nix                     # MODIFIED - import and use fuzzy matcher
│
├── darwin/
│   └── settings/
│       └── user/
│           └── dock.nix                     # MODIFIED - import and use fuzzy matcher
│
└── shared/
    └── family/
        └── gnome/
            └── settings/
                └── user/
                    └── dock.nix             # MODIFIED - import and use fuzzy matcher

user/
└── cdrokar/
    └── default.nix                          # MODIFIED - simplify docked array (remove duplicates)
```

**Structure Decision**: Single helper library in `system/shared/lib/fuzzy-dock-matcher.nix` containing the 5-step matching cascade. Existing dock modules (`system/shared/settings/user/dock.nix`, `system/darwin/settings/user/dock.nix`, `system/shared/family/gnome/settings/user/dock.nix`) import and invoke the fuzzy matcher. This follows the helper library pattern established in Constitution v2.3.0.

## Complexity Tracking

> No constitutional violations - all gates PASS. This section intentionally empty.

______________________________________________________________________

## Phase 0: Research & Technical Decisions

### Research Topics

The following technical decisions need research to inform implementation:

1. **Application Catalog Source**: How to obtain list of available applications on each platform

   - Darwin: Homebrew cask names, /Applications/\*.app, system apps
   - GNOME: .desktop files in /usr/share/applications, ~/.local/share/applications
   - Need: Platform-specific discovery mechanism

1. **String Normalization Strategy**: Best approach for case-insensitive, alphanumeric-only comparison

   - Options: `lib.toLower` + regex strip, `builtins.match` with patterns, custom normalizer
   - Need: Performance vs. readability tradeoff for 100-500 app search

1. **Word Boundary Detection**: Reliable method for strategy 4 word matching

   - Options: Split on whitespace/punctuation then match, regex word boundaries, manual tokenization
   - Need: "settings" matches "System Settings" but not "Settingsapp"

1. **Path/Namespace Stripping**: Consistent pattern removal across platforms

   - Darwin: .app suffix, /Applications/ prefix
   - GNOME: org.gnome., org.kde., com.\*, reverse-DNS prefixes
   - Need: Generic pattern that works for both platforms

1. **Build Summary Output**: How to display matching results during build

   - Options: trace messages, writeTextFile in derivation, evaluation warnings
   - Need: User-visible output that doesn't clutter successful builds

### Research Agents

Execute the following research tasks using the Task tool:

1. **App Catalog Discovery**:

   - Task: "Research how to enumerate installed applications on Darwin (Homebrew + /Applications) and NixOS/GNOME (.desktop files) for dock matching"
   - Output: Methods to get app lists, data structures, performance considerations

1. **Nix String Manipulation**:

   - Task: "Find best practices for case-insensitive string matching, alphanumeric normalization, and word-boundary detection using nixpkgs lib functions"
   - Output: Recommended functions, performance characteristics, example patterns

1. **Build-Time Output**:

   - Task: "Research approaches for displaying build-time summary information in Nix (trace, warnings, evaluation output) that's visible to users"
   - Output: Recommended approach for FR-012 build summary

### Research Consolidation

After research agents complete, consolidate findings into `research.md` with format:

- **Decision**: [What approach was chosen]
- **Rationale**: [Why this approach over alternatives]
- **Alternatives Considered**: [What else was evaluated and why rejected]
- **Implementation Notes**: [Key details for Phase 1 implementation]

______________________________________________________________________

## Phase 1: Design & Implementation

**Prerequisites**: `research.md` complete with all decisions finalized

### Data Model

Extract entities from spec and define their structure in `data-model.md`:

**Entities**:

1. **DockEntry** (input):

   - Type: String
   - Values: Application name (simple or exact), separator ("|", "||"), folder path ("/Downloads")
   - Validation: Non-empty string

1. **ApplicationCatalog** (input):

   - Type: List of AppInfo
   - AppInfo: `{ name, path, displayName, desktopFile? }`
   - Platform-specific structure (Darwin vs GNOME different metadata)

1. **MatchStrategy** (enum):

   - Values: "exact-case", "exact-nocase", "exact-nopath", "word-boundary", "skipped"
   - Used for: Build summary output, debugging

1. **MatchResult** (output):

   - Type: `{ userInput, resolvedPath?, resolvedName?, strategy }`
   - Fields:
     - `userInput`: Original dock entry string
     - `resolvedPath`: Platform-specific app path (null if skipped)
     - `resolvedName`: Human-readable app name (for summary)
     - `strategy`: Which of 5 strategies matched (or "skipped")

1. **MatchSummary** (aggregated output):

   - Type: List of MatchResult
   - Used for: FR-012 build-time summary display

### API Contracts

Since this is a Nix library (not REST/GraphQL), define the function contract in `contracts/fuzzy-dock-matcher.nix.contract`:

```nix
# Function: fuzzyMatchDock
# Location: system/shared/lib/fuzzy-dock-matcher.nix
#
# Purpose: Resolve dock entry names to platform-specific application paths
# using a deterministic 5-step matching cascade.
#
# Signature:
#   fuzzyMatchDock :: {
#     entries :: [String],           # User's dock configuration (user.docked)
#     appCatalog :: [AppInfo],        # Platform-specific available apps
#     platform :: String,             # "darwin" or "nixos"
#   } -> {
#     resolved :: [String],           # Resolved app paths (separators/folders preserved)
#     summary :: [MatchResult],       # Match results for build summary (FR-012)
#   }
#
# AppInfo Structure:
#   {
#     name :: String,                 # App name (e.g., "Calculator", "org.gnome.Calculator")
#     path :: String,                 # Full path (e.g., "/Applications/Calculator.app")
#     displayName :: String,          # Human-readable name (for summary)
#     desktopFile :: Maybe String,    # Desktop file path (GNOME only)
#   }
#
# MatchResult Structure:
#   {
#     userInput :: String,            # Original entry from user.docked
#     resolvedPath :: Maybe String,   # Platform path (null if skipped)
#     resolvedName :: String,         # Human-readable name (for summary)
#     strategy :: String,             # "exact-case" | "exact-nocase" | "exact-nopath" | "word-boundary" | "skipped"
#   }
#
# Matching Cascade (FR-001):
#   1. Exact match with case (user input == app.name)
#   2. Exact match case-insensitive (toLower(user input) == toLower(app.name))
#   3. Exact match on app name without path (user input == stripPath(app.name))
#   4. Word match in app name (user input is word in app.name)
#   5. Skip entry (no match found)
#
# Special Cases:
#   - Separators ("|", "||"): Pass through unchanged, not matched
#   - Folders ("/Downloads"): Pass through unchanged, not matched
#   - Deduplication (FR-006): If multiple entries resolve to same path, keep first
#
# Example Usage:
#   let
#     result = fuzzyMatchDock {
#       entries = ["calculator" "settings" "|" "terminal"];
#       appCatalog = [
#         { name = "Calculator"; path = "/Applications/Calculator.app"; displayName = "Calculator"; }
#         { name = "System Settings"; path = "/Applications/System Settings.app"; displayName = "System Settings"; }
#         { name = "Terminal"; path = "/Applications/Terminal.app"; displayName = "Terminal"; }
#       ];
#       platform = "darwin";
#     };
#   in {
#     result.resolved == [
#       "/Applications/Calculator.app"
#       "/Applications/System Settings.app"
#       "|"
#       "/Applications/Terminal.app"
#     ];
#     result.summary == [
#       { userInput = "calculator"; resolvedPath = "/Applications/Calculator.app"; resolvedName = "Calculator"; strategy = "exact-nocase"; }
#       { userInput = "settings"; resolvedPath = "/Applications/System Settings.app"; resolvedName = "System Settings"; strategy = "word-boundary"; }
#       { userInput = "|"; resolvedPath = "|"; resolvedName = "separator"; strategy = "passthrough"; }
#       { userInput = "terminal"; resolvedPath = "/Applications/Terminal.app"; resolvedName = "Terminal"; strategy = "exact-nocase"; }
#     ];
#   }
```

### Quickstart Guide

Create `quickstart.md` with step-by-step implementation guide:

1. **Create fuzzy-dock-matcher.nix** in `system/shared/lib/`
1. **Implement 5-step matching cascade** (FR-001 to FR-005)
1. **Add string normalization helpers** (case-insensitive, alphanumeric, path stripping)
1. **Implement word-boundary matching** for strategy 4
1. **Add deduplication logic** (FR-006)
1. **Generate match summary** (FR-012)
1. **Update platform dock modules** to import and use fuzzy matcher
1. **Add build summary output** (trace or warning messages)
1. **Test with sample configs** on Darwin + NixOS
1. **Update user configs** to remove duplicate entries (optional migration)

### Agent Context Update

Run agent context update script:

```bash
cd /Users/charles/project/nix-config
.specify/scripts/bash/update-agent-context.sh claude
```

This will update `.claude/context.md` with:

- New technology: Nix string manipulation functions (lib.toLower, builtins.match, lib.strings)
- New helper library: fuzzy-dock-matcher.nix
- Updated dock configuration pattern: fuzzy matching integration

______________________________________________________________________

## Phase 2: Task Breakdown

**Prerequisites**: Phase 1 complete (research.md, data-model.md, contracts/, quickstart.md)

Phase 2 is executed via `/speckit.tasks` command, which generates `tasks.md` with detailed implementation tasks based on the design artifacts from Phase 1. This phase is NOT part of `/speckit.plan` output.

The tasks will cover:

- Implementing fuzzy-dock-matcher.nix with 5-step cascade
- Updating dock modules (shared, darwin, gnome) to use fuzzy matcher
- Adding build summary output mechanism
- Testing on both platforms with sample configurations
- Updating user configs to demonstrate simplified syntax

______________________________________________________________________

## Next Steps

1. **Execute Phase 0**: Run research agents to resolve technical unknowns
1. **Review research.md**: Validate all decisions before proceeding
1. **Execute Phase 1**: Generate data-model.md, contracts/, quickstart.md
1. **Run agent context update**: Update `.claude/context.md`
1. **Ready for `/speckit.tasks`**: With design complete, generate task breakdown
