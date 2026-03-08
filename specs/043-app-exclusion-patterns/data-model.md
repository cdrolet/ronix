# Data Model: App Exclusion Patterns

**Feature**: 043-app-exclusion-patterns\
**Date**: 2026-02-07

## Entities

### ApplicationEntry (String)

A single entry in the `user.applications` array. Can be one of three types:

| Type | Pattern | Examples | Description |
|------|---------|----------|-------------|
| Explicit Include | `"appname"` | `"git"`, `"docker"` | Specific app, always included (overrides exclusions) |
| Wildcard Include | `"*"` or `"category/*"` | `"*"`, `"dev/*"` | Expands to all matching app names |
| Exclusion | `"!appname"` or `"!category/*"` | `"!docker"`, `"!ai/*"` | Removes matching apps from wildcard results |

### Classification Result

The `apps` input list is classified into three buckets:

```
{
  wildcards    :: [String]   # ["*", "dev/*"]       — patterns to expand
  exclusions   :: [String]   # ["!docker", "!ai/*"] — patterns to subtract (! stripped)
  explicits    :: [String]   # ["git", "chatgpt"]   — always included
}
```

### Processing Pipeline

```
Input: ["*", "!ai/*", "chatgpt", "!docker"]
  │
  ├─ wildcards:  ["*"]
  ├─ exclusions: ["ai/*", "docker"]    (! prefix stripped)
  └─ explicits:  ["chatgpt"]
  │
  ▼
Expand wildcards: ["git", "docker", "chatgpt", "claude", ...]  (all apps)
  │
  ▼
Expand exclusion wildcards: ["claude", "chatgpt"]  (ai/* expanded)
Merge with explicit exclusions: ["claude", "chatgpt", "docker"]
  │
  ▼
Subtract exclusions from expanded: [...all except claude, chatgpt, docker...]
  │
  ▼
Union with explicits: [...all except claude and docker...] + ["chatgpt"]
  │
  ▼
Deduplicate: final app name list
  │
  ▼
Resolve to paths (existing logic)
```

## New Functions in discovery.nix

### `isExclusion :: String -> Bool`

Detects if entry starts with `"!"`.

### `stripExclusion :: String -> String`

Removes `"!"` prefix from exclusion pattern.

### `classifyApplicationEntries :: [String] -> { wildcards, exclusions, explicits }`

Splits the applications array into three buckets. Exclusion entries have their `!` prefix stripped.

### `expandExclusions :: [String] -> [Path] -> [String]`

Expands exclusion patterns (both single names and wildcards) to a flat list of app names to exclude. Reuses `expandCategoryWildcard` for wildcard exclusions.

## Validation Rules

| Rule | Behavior |
|------|----------|
| `"!category/sub/*"` | ERROR: Multi-level exclusion not supported (same as wildcards) |
| `"!nonexistent"` | Silently ignored |
| `"!category/*"` matching zero apps | Silently ignored |
| `"!*"` | Valid: excludes all wildcard results |
| Exclusion without wildcards | No effect (exclusions only subtract from wildcard results) |

## State Transitions

N/A — pure functional transformation with no state. Input list in, resolved path list out.
