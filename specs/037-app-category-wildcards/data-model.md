# Data Model: App Category Wildcards

**Feature**: 037-app-category-wildcards\
**Date**: 2026-01-03\
**Phase**: Design (Phase 1)

## Overview

This document defines the data structures and entities used in the wildcard expansion system. All entities are pure Nix values (attribute sets, lists, strings) evaluated at build time.

## Core Entities

### 1. Wildcard Pattern

**Description**: A string pattern in the user.applications array that expands to multiple app names.

**Type**: `String`

**Valid Patterns**:

- `"category/*"` - Matches all apps in a specific category
- `"*"` - Matches ALL apps across ALL categories

**Invalid Patterns** (Out of Scope):

- `"category/subcategory/*"` - Multi-level wildcards
- `"!app-name"` - Exclusion patterns
- `"cat*"` - Partial wildcards or regex

**Examples**:

```nix
"browser/*"      # Valid: category wildcard
"productivity/*" # Valid: category wildcard
"*"              # Valid: global wildcard
"git"            # Valid: explicit app name (not a wildcard)
"dev/lang/*"     # Invalid: multi-level not supported
```

**Validation**:

```nix
isWildcard :: String → Bool
isWildcard = str:
  (builtins.match "(.+)/\\*" str) != null  # Matches "category/*"
  || str == "*";                           # Matches "*"
```

**State Transitions**:

```text
Raw Pattern String
        ↓
   [Validation]
        ↓
Valid Wildcard ----expand---→ List of App Names
        ↓
Invalid Pattern → Error/Warning
```

______________________________________________________________________

### 2. Category Name

**Description**: Directory name under `system/*/app/` that groups related applications.

**Type**: `String`

**Format**: Alphanumeric with hyphens (directory name compatible)

**Examples**:

- `"browser"` (from `system/shared/app/browser/`)
- `"productivity"` (from `system/shared/app/productivity/`)
- `"dev"` (from `system/shared/app/dev/`)
- `"games"` (from `system/shared/app/games/`)

**Extraction from Pattern**:

```nix
extractCategory :: String → String?
extractCategory = str: let
  match = builtins.match "(.+)/\\*" str;
in
  if match != null
  then builtins.head match  # Returns category name
  else null;                 # Not a category wildcard

# Examples:
# extractCategory "browser/*"     → "browser"
# extractCategory "dev/*"          → "dev"
# extractCategory "*"              → null (global wildcard)
# extractCategory "git"            → null (not a wildcard)
```

**Validation**:

- Category directory must exist (or returns empty list with warning)
- No multi-level categories (e.g., "dev/lang")

______________________________________________________________________

### 3. App Name

**Description**: Unique identifier for an application module (filename without .nix extension).

**Type**: `String`

**Format**: Alphanumeric with hyphens (filename compatible, no spaces)

**Derivation**: Filename of app module with .nix extension removed

**Examples**:

```text
system/shared/app/browser/zen.nix        → "zen"
system/shared/app/dev/git.nix            → "git"
system/darwin/app/productivity/mail.nix  → "mail"
```

**Uniqueness**: App names are unique within a given search path hierarchy level

**Usage Context**:

- Input: User specifies in applications array (or via wildcard)
- Processing: Resolved to full module path
- Output: Path to .nix module for Home Manager import

______________________________________________________________________

### 4. Expanded App List

**Description**: Deduplicated list of app names after wildcard expansion.

**Type**: `[String]`

**Characteristics**:

- Ordered (first occurrence preserved)
- Deduplicated (no duplicate app names)
- Flattened (from potentially nested wildcard results)

**Transformation**:

```text
Input:  ["browser/*", "git", "dev/*", "browser/*"]
           ↓
Expand: [["zen", "brave", "firefox"], ["git"], ["uv", "spec-kit", "git"], ["zen", "brave", "firefox"]]
           ↓
Flatten: ["zen", "brave", "firefox", "git", "uv", "spec-kit", "git", "zen", "brave", "firefox"]
           ↓
Dedupe:  ["zen", "brave", "firefox", "git", "uv", "spec-kit"]
           ↓
Output:  List of unique app names (order preserved)
```

**Processing**:

```nix
type ExpandedAppList = [String]

expandWildcards :: { patterns :: [String], ... } → ExpandedAppList
expandWildcards = { patterns, system ? null, families ? [], basePath }: let
  # Expand each pattern
  expanded = lib.flatten (map expandPattern patterns);
  
  # Deduplicate (preserves first occurrence)
  deduplicated = lib.unique expanded;
in
  deduplicated;
```

______________________________________________________________________

### 5. Resolved App Path

**Description**: Absolute filesystem path to an app's .nix module file.

**Type**: `Path`

**Format**: Absolute path to .nix file in nix-config repository

**Examples**:

```nix
/nix/store/.../nix-config/system/shared/app/browser/zen.nix
/nix/store/.../nix-config/system/darwin/app/productivity/mail.nix
/nix/store/.../nix-config/system/shared/family/gnome/app/utility/geary.nix
```

**Derivation**:

```text
App Name ("zen")
      ↓
[Hierarchical Search]
      ↓
Search Paths (in order):
  1. system/darwin/app/browser/zen.nix        (not found)
  2. system/shared/family/*/app/browser/zen.nix (not found)
  3. system/shared/app/browser/zen.nix         (FOUND ✓)
      ↓
Resolved Path: /absolute/path/to/system/shared/app/browser/zen.nix
```

**Null Handling**: Returns `null` if app not found in any search path

______________________________________________________________________

### 6. Hierarchical Search Paths

**Description**: Ordered list of directory paths to search for apps, respecting platform and family hierarchy.

**Type**: `[Path]`

**Order** (highest priority first):

1. System-specific: `system/{system}/app/`
1. Family-specific: `system/shared/family/{family}/app/` (for each family)
1. Shared: `system/shared/app/`

**Construction**:

```nix
type SearchPaths = [Path]

buildWildcardSearchPaths :: { system, families, basePath } → SearchPaths
buildWildcardSearchPaths = { system ? null, families ? [], basePath }: let
  systemPath = basePath + "/system/${system}/app";
  familyPaths = map (f: basePath + "/system/shared/family/${f}/app") families;
  sharedPath = basePath + "/system/shared/app";
in
  # Filter out non-existent paths
  (lib.optional (system != null && builtins.pathExists systemPath) systemPath)
  ++ familyPaths
  ++ [sharedPath];

# Example (darwin host with no families):
# → [
#     /path/to/system/darwin/app
#     /path/to/system/shared/app
#   ]

# Example (nixos host with ["linux", "gnome"] families):
# → [
#     /path/to/system/nixos/app
#     /path/to/system/shared/family/gnome/app
#     /path/to/system/shared/family/linux/app
#     /path/to/system/shared/app
#   ]
```

**Usage**:

- Wildcard expansion: Search each path for category directories
- App resolution: Search each path for specific app modules

______________________________________________________________________

### 7. Category App Registry

**Description**: Map of category paths to lists of app names found in that category.

**Type**: `AttrsOf [String]`

**Structure**:

```nix
{
  "/path/to/system/shared/app/browser" = ["zen" "brave" "firefox"];
  "/path/to/system/shared/app/dev" = ["git" "uv" "spec-kit" "helix"];
  "/path/to/system/darwin/app/productivity" = ["mail"];
}
```

**Construction**:

```nix
type CategoryAppRegistry = AttrsOf [String]

buildCategoryRegistry :: Path → CategoryAppRegistry
buildCategoryRegistry = categoryPath:
  if !builtins.pathExists categoryPath
  then {}
  else let
    entries = builtins.readDir categoryPath;
    nixFiles = lib.filterAttrs (n: t:
      t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix"
    ) entries;
    appNames = map (n: lib.removeSuffix ".nix" n) (builtins.attrNames nixFiles);
  in
    { ${toString categoryPath} = appNames; };
```

**Usage**:

- Wildcard expansion lookups
- Validation (check if category is empty)
- Error messages (list available apps in category)

______________________________________________________________________

## Data Flow Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                     USER CONFIGURATION                          │
│  user.applications = ["browser/*", "git", "dev/*"]              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                    WILDCARD EXPANSION                           │
│                                                                 │
│  1. Parse patterns:                                             │
│     "browser/*" → { type: "category", value: "browser" }        │
│     "git"       → { type: "explicit", value: "git" }            │
│     "dev/*"     → { type: "category", value: "dev" }            │
│                                                                 │
│  2. Build search paths (system → families → shared)             │
│                                                                 │
│  3. Expand wildcards:                                           │
│     "browser/*" → ["zen", "brave", "firefox"]                   │
│     "git"       → ["git"]                                       │
│     "dev/*"     → ["uv", "spec-kit", "helix", "git"]            │
│                                                                 │
│  4. Flatten & deduplicate:                                      │
│     → ["zen", "brave", "firefox", "git", "uv", "spec-kit", ...] │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                  HIERARCHICAL RESOLUTION                        │
│                                                                 │
│  For each app name:                                             │
│    1. Search system/darwin/app/                                 │
│    2. Search system/shared/family/*/app/ (if families exist)    │
│    3. Search system/shared/app/                                 │
│    → Returns first match or null                                │
│                                                                 │
│  Result: [Path, Path, Path, ...]                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                    HOME MANAGER IMPORT                          │
│  imports = resolvedPaths;                                       │
│  → Home Manager loads all app modules                           │
└─────────────────────────────────────────────────────────────────┘
```

## Validation Rules

### Pattern Validation

| Rule | Check | Action |
|------|-------|--------|
| Empty pattern | `pattern == ""` | Error: "Empty pattern not allowed" |
| Multi-level wildcard | `builtins.match ".*/.*/*" pattern != null` | Error: "Multi-level wildcards not supported" |
| Invalid characters | Contains characters outside `[a-zA-Z0-9_-/*]` | Error: "Invalid characters in pattern" |
| Category exists | `!builtins.pathExists categoryPath` | Warning: "Category '{category}' not found" |

### Expansion Validation

| Rule | Check | Action |
|------|-------|--------|
| Empty expansion | `expandedApps == []` | Warning: "Wildcard '{pattern}' matched zero apps" |
| Duplicate apps | Same app from multiple patterns | Deduplicate with `lib.unique` (silent) |
| Null paths | App name doesn't resolve | Filter out `null` (graceful degradation) |

## State Transitions

```text
                    ┌──────────────┐
                    │ Raw Pattern  │
                    │  (String)    │
                    └──────┬───────┘
                           │
                    [isWildcard?]
                           │
                ┌──────────┴───────────┐
                │                      │
               YES                    NO
                │                      │
         ┌──────▼──────┐        ┌─────▼──────┐
         │  Wildcard   │        │  Explicit  │
         │   Pattern   │        │  App Name  │
         └──────┬──────┘        └─────┬──────┘
                │                      │
       [extractCategory]               │
                │                      │
         ┌──────▼──────┐               │
         │  Category   │               │
         │    Name     │               │
         └──────┬──────┘               │
                │                      │
    [expandCategoryWildcard]           │
                │                      │
         ┌──────▼───────┐              │
         │  List of     │              │
         │  App Names   │              │
         └──────┬───────┘              │
                │                      │
                └──────────┬───────────┘
                           │
                    [lib.flatten]
                           │
                    [lib.unique]
                           │
                    ┌──────▼───────┐
                    │  Expanded    │
                    │  App List    │
                    └──────┬───────┘
                           │
              [resolveApplications]
                           │
                    ┌──────▼───────┐
                    │  Resolved    │
                    │  Paths       │
                    └──────────────┘
```

## Summary

### Key Entities

1. **Wildcard Pattern** - Input string (`"category/*"` or `"*"`)
1. **Category Name** - Extracted from pattern (`"category"`)
1. **App Name** - Unique app identifier (`"git"`)
1. **Expanded App List** - Deduplicated list of app names
1. **Resolved App Path** - Absolute path to .nix module
1. **Hierarchical Search Paths** - Ordered search locations
1. **Category App Registry** - Map of categories to apps

### Data Transformations

```text
["browser/*", "git"] → Validation → Expansion → Deduplication → Resolution → [Path, Path, ...]
```

### Purity Guarantees

- All entities are immutable Nix values
- All transformations are pure functions
- No side effects or state mutations
- Deterministic evaluation (same input → same output)
