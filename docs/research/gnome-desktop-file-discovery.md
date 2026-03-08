# GNOME Desktop File Discovery from Nix Packages

**Research Date**: 2026-02-05\
**Context**: Building a fuzzy dock matcher for GNOME favorites\
**Question**: How to discover .desktop file names from Nix packages at evaluation time?

______________________________________________________________________

## Executive Summary

**Short Answer**: You **cannot reliably** extract .desktop file names from Nix packages at evaluation time. Most packages don't expose this information, and `builtins.readDir` on store paths creates circular dependencies.

**Recommended Solution**: Use **runtime discovery** via activation scripts to scan installed packages for desktop files, or maintain a **static mapping table** with fuzzy matching fallbacks.

______________________________________________________________________

## Research Findings

### 1. No Standard Evaluation-Time Access ❌

- **Most nixpkgs packages do NOT expose desktop file names** at evaluation time
- There's an [open GitHub issue (#347835)](https://github.com/NixOS/nixpkgs/issues/347835) requesting standardization
- Only a handful of packages expose desktop items via passthru (e.g., `firefox.package.desktopItem`, `element-desktop.desktopItem`)
- The issue was opened in mid-2024 and remains unresolved as of 2026-02

**Quote from issue**:

> "Many derivations use makeDesktopItem to create XDG desktop files. The results sometimes have to be referenced elsewhere in the configuration, such as in xdg.mime.defaultApplications. In these cases it would be good to be able to refer to the desktop files directly, rather than having to build, switch, then look through /run/current-system/sw/share/applications, and finally hard-code the filename in the configuration."

### 2. Why `builtins.readDir` Doesn't Work ❌

From Nix documentation and [GitHub issue #3956](https://github.com/NixOS/nix/issues/3956):

- `builtins.readDir` operates at **evaluation time** (before builds happen)
- Store paths don't exist until **after** evaluation completes and builds run
- Creates a **circular dependency**: need the path to evaluate, but need evaluation to build the path
- Error example: `builtins.readDir does not honor --store`

**Technical explanation**:

```nix
# This will FAIL if the package isn't already built
builtins.readDir "${pkgs.gnome-calculator}/share/applications"
# Error: path does not exist in the Nix store during evaluation
```

### 3. Current Nixpkgs Patterns

#### Pattern A: `makeDesktopItem` (Internal Definition)

Packages use `makeDesktopItem` to define desktop files:

```nix
desktopItem = makeDesktopItem {
  name = "element-desktop";  # This becomes element-desktop.desktop
  exec = "${executableName} %u";
  icon = "element";
  desktopName = "Element";
  genericName = "Matrix Client";
  categories = [ "Network" "InstantMessaging" "Chat" ];
  # ...
};
```

The `name` attribute becomes the `.desktop` filename (without extension). Default installation path: `/share/applications/`.

#### Pattern B: `passthru.desktopItem` (Rare, Not Standardized)

A few packages expose their desktop item via passthru:

```nix
passthru = {
  inherit desktopItem;  # Expose for external use
  # ...
};
```

**Access example**:

```nix
pkgs.element-desktop.desktopItem.name  # → "element-desktop"
```

**Limitation**: Only works for packages that explicitly expose this. Not a nixpkgs-wide standard.

#### Pattern C: `meta.mainProgram` (Unreliable Correlation)

Many packages expose their main executable:

```nix
meta.mainProgram = "gnome-calculator";
```

**Test result**:

```bash
$ nix eval nixpkgs#gnome-calculator.meta.mainProgram
"gnome-calculator"
```

**Correlation examples**:

- `meta.mainProgram = "firefox"` → Desktop file: `firefox.desktop` ✅
- `meta.mainProgram = "gnome-calculator"` → Desktop file: `org.gnome.Calculator.desktop` ❌

**Problem**: GNOME apps use reverse-DNS naming (`org.gnome.*`), making correlation unreliable.

______________________________________________________________________

## Recommended Approaches

### Approach 1: Runtime Discovery (Recommended) ✅

Use Home Manager activation scripts to discover desktop files **after** packages are installed:

```nix
{ config, pkgs, lib, ... }:

let
  # Extract desktop file names at activation time
  discoverDesktopFiles = packages: ''
    for pkg in ${lib.concatStringsSep " " (map (p: "${p}") packages)}; do
      if [ -d "$pkg/share/applications" ]; then
        find "$pkg/share/applications" -name "*.desktop" -exec basename {} .desktop \;
      fi
    done
  '';
  
in {
  home.activation.discoverDesktopFiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
    echo "Discovering desktop files..." >&2
    DESKTOP_FILES=$(${discoverDesktopFiles config.home.packages})
    echo "Found:" >&2
    echo "$DESKTOP_FILES" | sort -u >&2
    
    # Use $DESKTOP_FILES for GNOME favorites configuration
    # Example: Build gsettings command to set favorite-apps
  '';
}
```

**How it works**:

1. During activation, iterate through `config.home.packages`
1. For each package, check if `$pkg/share/applications` exists
1. Extract `.desktop` filenames using `find` and `basename`
1. Use the discovered files to configure GNOME favorites

**Pros**:

- ✅ Works with **all** packages (no maintainer support needed)
- ✅ Accurate (reads actual installed files)
- ✅ No manual mapping maintenance
- ✅ Handles edge cases (multiple desktop files per package)

**Cons**:

- ❌ Runs at **activation time** (not evaluation time)
- ❌ Can't use result in pure Nix expressions
- ❌ Slightly slower activation (filesystem scanning)

### Approach 2: Static Mapping with Fuzzy Fallbacks ⚠️

Maintain a manual mapping table with algorithmic fallbacks:

```nix
{ lib, pkgs, ... }:

let
  # Known mappings for problematic apps (especially GNOME)
  desktopMappings = {
    "gnome-calculator" = "org.gnome.Calculator";
    "gnome-calendar" = "org.gnome.Calendar";
    "gnome-maps" = "org.gnome.Maps";
    "firefox" = "firefox";
    "chromium" = "chromium-browser";
    # Add more as needed...
  };
  
  # Try multiple strategies to guess desktop name
  guessDesktopName = pkg:
    let
      name = pkg.pname or (lib.getName pkg);
      mainProg = pkg.meta.mainProgram or name;
      
      # Try in order of reliability
      candidates = [
        (desktopMappings.${name} or null)                    # 1. Known mapping
        (if pkg ? passthru.desktopItem 
         then pkg.passthru.desktopItem.name 
         else null)                                          # 2. Passthru (rare)
        mainProg                                             # 3. mainProgram
        name                                                 # 4. Package name
      ];
      
    in lib.findFirst (x: x != null) name candidates;
    
  # Get desktop names for all installed packages
  allDesktopNames = map (pkg: guessDesktopName pkg) config.home.packages;
  
in {
  # Use allDesktopNames in your GNOME favorites config
  dconf.settings."org/gnome/shell" = {
    favorite-apps = map (name: "${name}.desktop") allDesktopNames;
  };
}
```

**Pros**:

- ✅ Works at **evaluation time**
- ✅ Can use in pure Nix expressions
- ✅ Fast (no filesystem scanning)

**Cons**:

- ❌ Requires **manual mapping maintenance**
- ❌ Will miss new packages or upstream renames
- ❌ Fragile (no validation that files exist)
- ❌ Guesses may be wrong

### Approach 3: Hybrid (Best of Both Worlds) ✅✅

Combine static hints with runtime validation:

```nix
{ config, pkgs, lib, ... }:

let
  # Static mappings for known problematic cases
  desktopMappings = import ./gnome-desktop-mappings.nix;
  
  # Generate candidate names at eval-time
  getCandidates = pkg:
    let
      name = pkg.pname or (lib.getName pkg);
      mainProg = pkg.meta.mainProgram or name;
    in lib.filter (x: x != null) [
      (desktopMappings.${name} or null)           # Known mapping
      (if pkg ? passthru.desktopItem 
       then pkg.passthru.desktopItem.name 
       else null)                                 # Passthru
      mainProg                                    # mainProgram
      name                                        # Package name
      # GNOME reverse-DNS pattern heuristic
      "org.gnome.${lib.toUpper (lib.substring 0 1 name)}${lib.substring 1 (-1) name}"
    ];
  
  # Build candidate map
  packageCandidates = lib.listToAttrs (map (pkg: {
    name = pkg.pname or (lib.getName pkg);
    value = getCandidates pkg;
  }) config.home.packages);
  
in {
  home.activation.configureGnomeFavorites = lib.hm.dag.entryAfter ["writeBoundary"] ''
    echo "Building GNOME favorites list..." >&2
    
    # Discover actual installed desktop files
    INSTALLED_APPS=$(find ~/.local/share/applications /run/current-system/sw/share/applications \
      -name "*.desktop" 2>/dev/null | xargs -n1 basename .desktop | sort -u)
    
    # Match candidates against installed files
    MATCHED_APPS=""
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (pkgName: candidates: ''
      for candidate in ${lib.concatStringsSep " " candidates}; do
        if echo "$INSTALLED_APPS" | grep -qx "$candidate"; then
          MATCHED_APPS="$MATCHED_APPS$candidate.desktop;"
          break
        fi
      done
    '') packageCandidates)}
    
    # Set GNOME favorites
    gsettings set org.gnome.shell favorite-apps "[$MATCHED_APPS]"
    echo "Configured favorites: $MATCHED_APPS" >&2
  '';
}
```

**Benefits**:

1. **Fast evaluation**: Pre-compute candidate names
1. **Runtime validation**: Only use desktop files that actually exist
1. **Fuzzy matching**: Multiple strategies increase success rate
1. **Graceful degradation**: Missing mappings don't break the build

______________________________________________________________________

## Code Examples

### Example 1: Simple Runtime Discovery

```nix
{ config, pkgs, lib, ... }:

{
  home.activation.listDesktopFiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
    echo "Desktop files from installed packages:" >&2
    for pkg in ${lib.concatStringsSep " " (map (p: "${p}") config.home.packages)}; do
      [ -d "$pkg/share/applications" ] && \
        find "$pkg/share/applications" -name "*.desktop" -exec basename {} \;
    done | sort -u
  '';
}
```

### Example 2: Check for Passthru Support

```nix
{ pkgs, lib, ... }:

let
  # Check if a package exposes desktop item
  hasDesktopItem = pkg: pkg ? passthru.desktopItem;
  
  # Extract desktop name if available
  getDesktopName = pkg:
    if hasDesktopItem pkg
    then pkg.passthru.desktopItem.name
    else null;
    
in {
  # Test with firefox
  home.file."test-passthru.txt".text = ''
    Firefox has desktopItem: ${toString (hasDesktopItem pkgs.firefox)}
    Desktop name: ${toString (getDesktopName pkgs.firefox)}
  '';
}
```

### Example 3: GNOME Desktop Mappings File

Create `gnome-desktop-mappings.nix`:

```nix
{
  # GNOME Core Apps (reverse-DNS naming)
  "gnome-calculator" = "org.gnome.Calculator";
  "gnome-calendar" = "org.gnome.Calendar";
  "gnome-clocks" = "org.gnome.clocks";
  "gnome-contacts" = "org.gnome.Contacts";
  "gnome-font-viewer" = "org.gnome.font-viewer";
  "gnome-maps" = "org.gnome.Maps";
  "gnome-music" = "org.gnome.Music";
  "gnome-photos" = "org.gnome.Photos";
  "gnome-screenshot" = "org.gnome.Screenshot";
  "gnome-software" = "org.gnome.Software";
  "gnome-system-monitor" = "gnome-system-monitor";
  "gnome-terminal" = "org.gnome.Terminal";
  "gnome-text-editor" = "org.gnome.TextEditor";
  "gnome-weather" = "org.gnome.Weather";
  
  # Third-party apps
  "firefox" = "firefox";
  "chromium" = "chromium-browser";
  "vscode" = "code";
  "slack" = "slack";
  "discord" = "discord";
  "spotify" = "spotify";
  
  # Add more as you discover mismatches...
}
```

______________________________________________________________________

## Testing Strategy

### Test 1: Verify Runtime Discovery Works

```bash
# Build a test configuration
nix build '.#homeConfigurations."user@host".activationPackage'

# Run activation and check output
./result/activate

# Check if desktop files were discovered
ls ~/.local/share/applications/
ls /run/current-system/sw/share/applications/
```

### Test 2: Check Passthru Support

```bash
# Test if a package exposes desktopItem
nix eval --json 'nixpkgs#firefox' --apply 'pkg: builtins.attrNames (pkg.passthru or {})' --impure

# Try to access desktopItem (will fail for most packages)
nix eval --raw 'nixpkgs#element-desktop.desktopItem.name' --impure 2>/dev/null || echo "Not exposed"
```

### Test 3: Validate meta.mainProgram Correlation

```bash
# Get mainProgram for GNOME apps
for app in gnome-calculator gnome-calendar firefox; do
  echo -n "$app: "
  nix eval --raw "nixpkgs#$app.meta.mainProgram" --impure 2>/dev/null || echo "not set"
done

# Compare with actual desktop files
nix-shell -p gnome-calculator --run 'ls $(nix-build '<nixpkgs>' -A gnome-calculator --no-out-link)/share/applications/'
```

______________________________________________________________________

## Conclusion

**For your GNOME favorites dock matcher**, I recommend:

1. **Use Approach 3 (Hybrid)** for the best balance of reliability and performance
1. **Start with a static mapping table** for common GNOME apps (they use reverse-DNS naming)
1. **Use runtime discovery** to validate and discover new packages
1. **Implement fuzzy matching** with multiple fallback strategies (mainProgram, pname, etc.)
1. **Track nixpkgs issue #347835** for future standardization

This approach gives you:

- ✅ Immediate working solution (static mappings)
- ✅ Accurate results (runtime validation)
- ✅ Low maintenance (auto-discovery for new packages)
- ✅ Graceful degradation (missing mappings don't break builds)

______________________________________________________________________

## Sources

1. [Feature request: Expose desktop item(s) for packages which have them · Issue #347835 · NixOS/nixpkgs](https://github.com/NixOS/nixpkgs/issues/347835)
1. [builtins.readDir does not honor --store · Issue #3956 · NixOS/nix](https://github.com/NixOS/nix/issues/3956)
1. [Nix Built-in Functions - readDir documentation](https://nix.dev/manual/nix/2.25/language/builtins)
1. [nixpkgs makeDesktopItem builder](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/make-desktopitem/default.nix)
1. [element-desktop example with desktopItem](https://github.com/NixOS/nixpkgs/blob/478f3cbc8448b5852539d785fbfe9a53304133be/pkgs/applications/networking/instant-messengers/element/element-desktop.nix)
1. [signal-desktop package.nix with makeDesktopItem](https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/si/signal-desktop/package.nix)
1. [What is the recommended use of makeDesktopItem? - NixOS Discourse](https://discourse.nixos.org/t/what-is-the-recommended-use-of-makedesktopitem-how-to-setup-the-icon-correctly/13388)
1. [Meta-attributes | nixpkgs documentation](https://ryantm.github.io/nixpkgs/stdenv/meta/)
1. [Nix (builtins) & Nixpkgs (lib) Functions reference](https://teu5us.github.io/nix-lib.html)

______________________________________________________________________

**Document Version**: 1.0\
**Last Updated**: 2026-02-05\
**Status**: Research Complete ✅
