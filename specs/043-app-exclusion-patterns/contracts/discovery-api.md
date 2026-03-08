# API Contract: Discovery Functions — Exclusion Support

**Feature**: 043-app-exclusion-patterns\
**Date**: 2026-02-07

## Modified Function: `resolveApplications`

### Signature (unchanged)

```nix
resolveApplications :: {
  apps :: [String],        # Now supports "!" prefixed exclusion patterns
  callerPath :: Path,
  basePath :: Path,
  system :: String?,
  families :: [String]?,
} -> [Path]
```

### Input Format

The `apps` parameter accepts three entry types:

| Entry Type | Format | Example |
|------------|--------|---------|
| Explicit include | `"appname"` | `"git"` |
| Wildcard include | `"*"` or `"category/*"` | `"dev/*"` |
| Exclusion | `"!appname"` or `"!category/*"` | `"!docker"`, `"!ai/*"` |

### Processing Contract

1. **Classify** entries into wildcards, exclusions, and explicit includes
1. **Expand** wildcard includes using existing `expandCategoryWildcard`
1. **Expand** exclusion wildcards using the same function (after stripping `!`)
1. **Subtract** all exclusion-matched names from wildcard expansion results
1. **Union** explicit includes back (overriding any exclusion)
1. **Deduplicate** using `lib.unique`
1. **Resolve** remaining names to paths (existing logic)

### Behavioral Guarantees

| Scenario | Input | Result |
|----------|-------|--------|
| Exclude specific app | `["*", "!docker"]` | All apps except docker |
| Exclude category | `["*", "!ai/*"]` | All apps except ai category |
| Re-include after exclude | `["*", "!ai/*", "chatgpt"]` | All apps, ai excluded, chatgpt re-included |
| Explicit overrides exclusion | `["*", "!docker", "docker"]` | docker IS installed |
| Exclusion only (no wildcard) | `["!docker"]` | Empty list (no apps) |
| Exclude everything | `["*", "!*"]` | Empty list |
| Non-matching exclusion | `["*", "!nonexistent"]` | All apps (exclusion silently ignored) |
| Multiple exclusions | `["*", "!ai/*", "!games/*"]` | All apps except ai and games |

### Error Cases

| Input | Error |
|-------|-------|
| `["*", "!ai/sub/*"]` | `error: Multi-level wildcards not supported: 'ai/sub/*'` |

## New Internal Functions (not exported)

### `isExclusion :: String -> Bool`

```nix
isExclusion = str: lib.hasPrefix "!" str;
```

### `stripExclusion :: String -> String`

```nix
stripExclusion = str: lib.removePrefix "!" str;
```

### `classifyApplicationEntries :: [String] -> { wildcards :: [String], exclusions :: [String], explicits :: [String] }`

Splits input list. Exclusions have `!` prefix stripped in the returned `exclusions` list.

```nix
classifyApplicationEntries ["*" "!docker" "!ai/*" "git" "chatgpt"]
# => { wildcards = ["*"]; exclusions = ["docker" "ai/*"]; explicits = ["git" "chatgpt"]; }
```

## Backward Compatibility

- No changes to function signature
- No changes to callers (config-loader.nix, darwin.nix, nixos.nix, home-manager.nix)
- Existing configs without `!` entries produce identical results
- Exclusion is opt-in via `!` prefix syntax
