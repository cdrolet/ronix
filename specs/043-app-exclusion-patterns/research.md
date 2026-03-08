# Research: App Exclusion Patterns

**Feature**: 043-app-exclusion-patterns\
**Date**: 2026-02-07

## Research Topic 1: Where to Integrate Exclusion Logic

### Decision: Inside `resolveApplications` in `discovery.nix`, between wildcard expansion and app resolution

### Rationale

The current pipeline in `resolveApplications` is:

```
apps input → wildcard expansion → deduplication → resolution → output
```

Exclusions are best processed as a filtering step between deduplication and resolution:

```
apps input → classify (wildcards / exclusions / explicit) → expand wildcards → expand exclusion wildcards → subtract exclusions → add explicit includes → deduplicate → resolution → output
```

This avoids:

- Changing `config-loader.nix` (exclusions are just strings in the same `apps` list)
- Changing any platform lib (darwin.nix, nixos.nix, home-manager.nix)
- Resolving paths for apps that will be excluded (wasteful)

### Alternatives Considered

1. **Separate `exclusions` parameter**: Would require changing config-loader and all platform libs. Rejected — unnecessary API change when `!` prefix is self-describing.
1. **Filter after path resolution**: Wasteful — resolves paths only to discard them. Also complicates error handling (excluded apps would trigger "app not found" errors).
1. **Handle in `expandCategoryWildcard`**: Would scatter exclusion logic across wildcard expansion. Less clean separation of concerns.

## Research Topic 2: Processing Order for Mixed Patterns

### Decision: Three-phase classification with explicit includes winning

### Rationale

The applications array can contain three types of entries:

1. **Wildcards**: `"*"`, `"category/*"` — expand to app names
1. **Exclusions**: `"!appname"`, `"!category/*"` — names/patterns to remove
1. **Explicit includes**: `"git"`, `"docker"` — specific app names

Processing order:

1. **Classify** all entries into the three buckets
1. **Expand** wildcards to app names (existing logic)
1. **Expand** exclusion wildcards (`"!category/*"` → list of names to exclude)
1. **Subtract** exclusion names from expanded wildcard results
1. **Union** with explicit includes (explicit always wins, even if excluded)
1. **Deduplicate** the final list

This ensures:

- `["*", "!docker"]` → everything except docker
- `["*", "!ai/*", "chatgpt"]` → everything, minus AI category, plus chatgpt back
- `["!docker"]` alone → empty list (exclusions only subtract from wildcards)
- `["dev/*", "!ai/*"]` → all dev apps (ai exclusion doesn't affect dev wildcard)

### Alternatives Considered

1. **Order-dependent processing** (left-to-right): `["*", "!docker", "docker"]` would depend on position. Rejected — error-prone and surprising to users.
1. **Exclusions always win**: `["*", "!docker", "docker"]` would exclude docker. Rejected — explicit includes should override for flexibility.

## Research Topic 3: Reusing Existing Wildcard Infrastructure

### Decision: Reuse `isWildcard`, `extractCategory`, `expandCategoryWildcard`, and `listAppsInCategorySafe` for exclusion wildcards

### Rationale

Exclusion wildcards (`"!category/*"`) need the same expansion logic as inclusion wildcards. After stripping the `"!"` prefix, the remainder is a standard wildcard pattern. No new expansion code needed — just:

```nix
isExclusion = str: lib.hasPrefix "!" str;
stripExclusion = str: lib.removePrefix "!" str;
```

Then for exclusion wildcards:

```nix
excludedNames = expandCategoryWildcard (stripExclusion pattern) searchPaths;
```

### Alternatives Considered

1. **Separate exclusion expansion system**: Duplicates wildcard infrastructure. Rejected — violates DRY.
1. **Regex-based exclusion matching**: Overkill for single-level category patterns. Rejected — unnecessary complexity.

## Research Topic 4: Validation of Exclusion Patterns

### Decision: Validate exclusion patterns using existing wildcard validation, plus `"!*"` as valid

### Rationale

After stripping `"!"`, the remaining string must be either:

- A valid app name (e.g., `"docker"`)
- A valid wildcard pattern (e.g., `"category/*"` or `"*"`)

The existing `validateMultiLevel` check in `expandCategoryWildcard` handles multi-level rejection. No additional validation needed.

Special cases:

- `"!*"` — valid, excludes all apps from wildcards
- `"!category/sub/*"` — rejected by existing multi-level validation
- `"!nonexistent"` — silently ignored (no error, as per spec FR-005)

### Alternatives Considered

1. **Warn on non-matching exclusions**: Could be noisy for cross-platform configs where some apps only exist on one platform. Rejected — silent ignore is more practical.

## Summary

| Decision | Choice | Key Reason |
|----------|--------|------------|
| Integration point | Inside `resolveApplications`, pre-resolution | No API changes to callers |
| Processing order | Classify → expand → subtract → re-include → deduplicate | Explicit includes win |
| Expansion reuse | Strip `!` prefix, reuse wildcard functions | DRY principle |
| Validation | Reuse existing wildcard validation | Consistent error messages |
| Non-matching exclusions | Silent ignore | Cross-platform friendliness |
