# Research: Fuzzy Dock Application Matching

**Feature**: 042-fuzzy-dock-matching\
**Date**: 2025-02-04\
**Purpose**: Resolve technical unknowns for implementing 5-step fuzzy matching cascade

______________________________________________________________________

## Summary of Decisions

This research resolves 5 key technical decisions needed for implementation:

1. **Application Catalog Source**: Use evaluation-time config metadata, not runtime filesystem
1. **String Normalization**: Use `lib.toLower` + `builtins.replaceStrings` for alphanumeric matching
1. **Word Boundary Detection**: Use `lib.splitString` + `lib.filter` for word tokenization
1. **Path/Namespace Stripping**: Use `lib.removePrefix` + pattern matching for platform prefixes
1. **Build Summary Output**: Use activation-time script with `entryAfter ["writeBoundary"]`

______________________________________________________________________

## Decision 1: Application Catalog Source

### Problem

How to obtain the list of available applications for fuzzy matching? Need app names, paths, and metadata.

### Options Considered

**Option A: Runtime Filesystem Scanning**

- Scan `/Applications` (Darwin) or `/usr/share/applications` (GNOME) during activation
- **Rejected**: Not available at Nix evaluation time (when matching happens)
- **Rejected**: Slow, unreliable, requires filesystem access

**Option B: Homebrew Registry Query**

- Query `brew search --casks` for Darwin apps
- **Rejected**: Homebrew is runtime tool, not available during Nix evaluation
- **Rejected**: Doesn't cover non-Homebrew apps

**Option C: Evaluation-Time Config Metadata** ← **SELECTED**

- Extract from imported home-manager modules during evaluation
- **Selected**: Already available, no additional data needed

### Decision: Use Evaluation-Time Config Metadata

**Rationale**:

- All app modules are imported during home-manager evaluation
- Config object contains all installed apps: `config.programs.*.enable`, `config.home.packages`, `config.homebrew.casks`
- App metadata available via `programs.*.desktop.paths` (Feature 019)
- No runtime dependencies, purely functional transformation
- Works identically on Darwin and NixOS

**Implementation**:

```nix
# Build application catalog from config at evaluation time
appCatalog = lib.flatten [
  # From home.packages
  (map (pkg: {
    name = pkg.pname or pkg.name;
    path = "${pkg}/bin/${pkg.pname or pkg.name}";
    source = "nixpkgs";
  }) config.home.packages)
  
  # From homebrew.casks (Darwin only)
  (lib.optionalAttrs (options ? homebrew) (
    map (cask: {
      name = cask;
      path = "/Applications/${capitalize cask}.app";
      source = "homebrew";
    }) config.homebrew.casks
  ))
  
  # From programs.*.desktop.paths (explicit declarations)
  (lib.mapAttrsToList (name: prog:
    if prog ? desktop && prog.desktop ? paths
    then {
      name = name;
      path = prog.desktop.paths.${currentPlatform};
      source = "desktop-metadata";
    }
    else null
  ) config.programs)
];
```

**Alternatives Rejected**:

- Runtime scanning: Not evaluation-time
- Homebrew queries: Not evaluation-time
- Hardcoded app lists: Not dynamic, maintenance burden

______________________________________________________________________

## Decision 2: String Normalization Strategy

### Problem

Need case-insensitive, alphanumeric-only comparison for fuzzy matching strategies.

### Options Considered

**Option A: Custom Regex Pattern**

- Use `builtins.match` with complex regex
- **Rejected**: Overly complex, hard to maintain, POSIX ERE limitations

**Option B: lib.toLower + builtins.replaceStrings** ← **SELECTED**

- Proven pattern from existing code (fonts.nix)
- **Selected**: Simple, readable, performant

**Option C: Manual Character Filtering**

- Iterate through string, filter alphanumeric
- **Rejected**: Inefficient, no built-in support for character iteration

### Decision: Use lib.toLower + builtins.replaceStrings

**Rationale**:

- Already proven in `system/shared/settings/user/fonts.nix` for font name normalization
- Simple, readable implementation
- Performant for typical strings (app names ~20 chars)
- Handles all required transformations

**Implementation**:

```nix
normalizeAppName = name:
  lib.toLower (
    builtins.replaceStrings
      [" " "-" "_" "." "'" "(" ")" "[" "]"]  # Common special chars in app names
      ["" "" "" "" "" "" "" "" ""]          # Remove all
      name
  );

# Example:
# "System Settings" → "systemsettings"
# "org.gnome.Calculator" → "orggnomecalculator"
# "Proton Mail" → "protonmail"
```

**Existing Pattern from fonts.nix**:

```nix
toPackageName = name:
  lib.toLower (builtins.replaceStrings [" "] ["-"] name);
```

**Alternatives Rejected**:

- Regex: Too complex for simple normalization
- Manual filtering: No built-in iteration support
- lib.hasInfix without normalization: Case-sensitive issues

______________________________________________________________________

## Decision 3: Word Boundary Detection

### Problem

Strategy 4 requires matching "settings" within "System Settings" as separate words, not just substring.

### Options Considered

**Option A: Regex Word Boundaries**

- Use `builtins.match` with `\b` word boundaries
- **Rejected**: POSIX ERE doesn't support `\b` (Perl feature)

**Option B: lib.splitString + lib.filter** ← **SELECTED**

- Split on whitespace/punctuation, check if search term is a word
- **Selected**: Simple, effective, proven in git.nix

**Option C: lib.hasInfix (substring only)**

- Just check if search term is substring
- **Rejected**: Doesn't distinguish words ("set" would match "Settings")

### Decision: Use lib.splitString + lib.filter for Word Tokenization

**Rationale**:

- Existing pattern in `system/shared/lib/git.nix` for URL parsing
- Simple implementation, no regex needed
- Distinguishes words from substrings
- Works for multi-word app names

**Implementation**:

```nix
getWords = str:
  lib.filter (s: s != "") (
    lib.splitString " " (
      builtins.replaceStrings ["-" "_" "." "(" ")"] [" " " " " " " " " "] 
      (lib.toLower str)
    )
  );

matchesWord = searchTerm: appName: let
  searchWords = getWords searchTerm;
  appWords = getWords appName;
in
  lib.any (searchWord:
    lib.elem searchWord appWords
  ) searchWords;

# Example:
# matchesWord "settings" "System Settings"
#   → searchWords = ["settings"]
#   → appWords = ["system", "settings"]
#   → Result: true (elem found)
#
# matchesWord "set" "System Settings"
#   → searchWords = ["set"]
#   → appWords = ["system", "settings"]
#   → Result: false (no elem found)
```

**Existing Pattern from git.nix**:

```nix
repoName = url: let
  withoutGit = lib.removeSuffix ".git" url;
  parts = lib.splitString "/" withoutGit;
in
  lib.last parts;
```

**Alternatives Rejected**:

- Regex word boundaries: Not supported in POSIX ERE
- Substring matching: Too permissive (matches partial words)

______________________________________________________________________

## Decision 4: Path/Namespace Stripping

### Problem

Need to remove platform-specific prefixes/suffixes for Strategy 3:

- Darwin: `.app` suffix, `/Applications/` prefix
- GNOME: `org.gnome.`, `com.`, `org.kde.` reverse-DNS prefixes

### Options Considered

**Option A: Hardcoded lib.removePrefix/removeSuffix**

- List all known prefixes/suffixes
- **Rejected**: Brittle, requires maintenance as new patterns emerge

**Option B: Regex Pattern Matching** ← **SELECTED**

- Use `builtins.match` to extract app name from path
- **Selected**: Flexible, handles multiple patterns

**Option C: lib.baseNameOf (path component only)**

- Extract last path component
- **Rejected**: Doesn't handle reverse-DNS prefixes (org.gnome.\*)

### Decision: Use Regex Pattern Matching for Platform Prefixes

**Rationale**:

- Existing pattern in `system/shared/lib/discovery.nix` for system extraction
- Handles multiple platform patterns with single implementation
- Extensible for future platform additions

**Implementation**:

```nix
stripPlatformPrefix = appName:
  let
    # Try Darwin pattern: /Applications/Foo.app → Foo
    darwinMatch = builtins.match ".*/([^/]+)\\.app$" appName;
    
    # Try reverse-DNS pattern: org.gnome.Calculator → Calculator
    reverseDNSMatch = builtins.match "([a-z]+\\.)+(.+)" appName;
    
    # Try simple .desktop suffix: brave.desktop → brave
    desktopMatch = builtins.match "(.+)\\.desktop$" appName;
  in
    if darwinMatch != null then builtins.head darwinMatch
    else if reverseDNSMatch != null then builtins.head (lib.drop 1 reverseDNSMatch)
    else if desktopMatch != null then builtins.head desktopMatch
    else appName;  # No pattern matched, return as-is

# Examples:
# stripPlatformPrefix "/Applications/Calculator.app" → "Calculator"
# stripPlatformPrefix "org.gnome.Calculator" → "Calculator"
# stripPlatformPrefix "brave.desktop" → "brave"
# stripPlatformPrefix "Firefox" → "Firefox" (no pattern, unchanged)
```

**Existing Pattern from discovery.nix**:

```nix
systemMatch = builtins.match ".*/system/([^/]+)/.*" relPath;
system =
  if systemMatch != null
  then builtins.head systemMatch
  else null;
```

**Alternatives Rejected**:

- Hardcoded prefix list: Brittle, maintenance burden
- baseNameOf: Doesn't handle reverse-DNS prefixes

______________________________________________________________________

## Decision 5: Build Summary Output

### Problem

FR-012 requires build-time summary showing resolved apps and strategies.

### Options Considered

**Option A: builtins.trace (Evaluation Time)**

- Output during Nix evaluation
- **Rejected**: Unstructured output, hard to read, pollutes stderr

**Option B: lib.warn (Evaluation Time)**

- Structured warnings during evaluation
- **Rejected**: Semantically wrong (not a warning), clutters validation output

**Option C: Activation Script (Runtime)** ← **SELECTED**

- Print summary during home-manager activation
- **Selected**: Clean, visible, follows established patterns

**Option D: Write to File (Runtime)**

- Generate summary file during activation
- **Rejected**: Users won't read files, want terminal output

### Decision: Use Activation Script with entryAfter ["writeBoundary"]

**Rationale**:

- Existing pattern in wallpaper.nix, desktop-cache.nix, secrets.nix
- Users see output during `darwin-rebuild switch` or `home-manager switch`
- Clean, readable formatting with echo statements
- Supports verbose mode with `$VERBOSE_ECHO`
- Works identically on Darwin and NixOS

**Implementation**:

```nix
home.activation.dockMatchingSummary = lib.mkIf (config.user.docked != []) (
  lib.hm.dag.entryAfter ["writeBoundary"] ''
    echo "[dock] Fuzzy matching resolution:"
    ${lib.concatStringsSep "\n" (map (entry:
      if entry.strategy != "passthrough"
      then ''echo "  ${entry.userInput} → ${entry.resolvedPath} [${entry.strategy}]"''
      else ""
    '') resolvedDockEntries)}
  ''
);

# Example output:
# [dock] Fuzzy matching resolution:
#   calculator → /Applications/Calculator.app [exact-nocase]
#   settings → /Applications/System Settings.app [word-boundary]
#   mail → /Applications/Mail.app [exact-nocase]
#   terminal → /Applications/Utilities/Terminal.app [exact-nopath]
#   nautilus → (skipped - not available) [skipped]
```

**Existing Patterns**:

From `wallpaper.nix`:

```nix
home.activation.darwinWallpaper = lib.hm.dag.entryAfter ["writeBoundary"] ''
  if [[ -v VERBOSE ]]; then
    echo "Darwin wallpaper set: $WALLPAPER"
  fi
'';
```

From `desktop-cache.nix`:

```nix
home.activation.refreshDesktopCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
  $VERBOSE_ECHO "Desktop file cache refreshed"
'';
```

From `secrets.nix`:

```nix
home.activation.${activationName} = lib.hm.dag.entryAfter ["agenixInstall"] ''
  echo "${name}: Resolved ${fieldPath} from secrets"
'';
```

**Alternatives Rejected**:

- builtins.trace: Unstructured, pollutes evaluation output
- lib.warn: Semantically wrong, clutters warnings
- Write to file: Users won't read log files

______________________________________________________________________

## Implementation Notes

### Integration Points

1. **Create fuzzy matcher helper**: `system/shared/lib/fuzzy-dock-matcher.nix`

   - Pure function: `fuzzyMatchDock :: { entries, appCatalog, platform } → { resolved, summary }`
   - Implements 5-step cascade (FR-001)
   - Returns both resolved paths and match summary

1. **Update dock modules** to use fuzzy matcher:

   - `system/shared/settings/user/dock.nix` (cross-platform logic)
   - `system/darwin/settings/user/dock.nix` (Darwin-specific)
   - `system/shared/family/gnome/settings/user/dock.nix` (GNOME-specific)

1. **Add activation summary**:

   - In appropriate dock module (platform-specific or shared)
   - Use `lib.hm.dag.entryAfter ["writeBoundary"]`
   - Conditional on `config.user.docked != []`

### Performance Considerations

- All operations are O(n) or O(n\*m) where n = dock entries (10-30), m = available apps (100-500)
- Total complexity: O(10 * 500 * 5) = ~25,000 operations worst case
- Nix handles this trivially (\<1ms evaluation time)
- No indexing or caching needed (NFR-002)

### Testing Strategy

1. **Unit testing**: Test normalizeAppName, matchesWord, stripPlatformPrefix in isolation
1. **Integration testing**: Test full fuzzyMatchDock function with sample catalogs
1. **Platform testing**: Verify on Darwin and NixOS with real user.docked configs
1. **Edge case testing**: Empty entries, duplicates, platform-specific apps

______________________________________________________________________

## References

**Existing Code Patterns**:

- String normalization: `system/shared/settings/user/fonts.nix:32-45`
- Regex pattern matching: `system/shared/lib/discovery.nix:207-289`
- Word tokenization: `system/shared/lib/git.nix:14-15`
- Activation scripts: `system/darwin/settings/user/wallpaper.nix:57-100`
- DAG ordering: `system/shared/family/gnome/settings/user/desktop-cache.nix:18-33`

**nixpkgs lib Functions**:

- Case conversion: `lib.toLower`, `lib.toUpper`
- String manipulation: `lib.removePrefix`, `lib.removeSuffix`, `lib.hasInfix`, `lib.splitString`
- Pattern matching: `builtins.match`, `builtins.replaceStrings`
- List operations: `lib.filter`, `lib.any`, `lib.elem`, `lib.findFirst`, `lib.unique`

______________________________________________________________________

## Next Phase

With research complete, proceed to Phase 1 (Design & Implementation):

1. Generate `data-model.md` defining entity structures
1. Create `contracts/` with function signatures
1. Write `quickstart.md` with implementation steps
1. Update agent context with new technologies/patterns
