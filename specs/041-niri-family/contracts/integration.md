# Integration Contracts

**Feature**: 041-niri-family\
**Purpose**: Define integration points with existing systems and families

## Overview

The Niri family integrates with:

1. **Linux family** - Shared Linux settings (keyboard layout, XDG directories)
1. **Discovery system** - Auto-loading and module composition
1. **Feature 030** (fonts) - Font configuration
1. **Feature 033** (wallpaper) - Wallpaper management
1. **Feature 036** (standalone home-manager) - User-level activation
1. **Feature 039** (context segregation) - System/user directory structure

## Linux Family Composition

### Family Declaration Order

**Host configuration must declare linux BEFORE niri**:

```nix
# system/nixos/host/example/default.nix
{
  name = "example";
  family = ["linux", "niri"];  # Order matters: linux → niri
  applications = ["*"];
  settings = ["default"];
}
```

**Why order matters**:

- Linux family provides base Linux settings (keyboard, XDG dirs)
- Niri family extends with compositor-specific config
- Settings inherit through hierarchy (linux → niri)

### Shared Settings

| Setting | Provided By | Used By | Integration Point |
|---------|-------------|---------|-------------------|
| XKB Layout | linux/settings/system/keyboard.nix | niri/settings/user/keyboard.nix | `config.user.keyboardLayout` |
| XDG Directories | linux/settings/user/home-directory.nix | All apps | `$XDG_CONFIG_HOME`, `$XDG_DATA_HOME` |
| Font Cache | linux/settings/user/fonts.nix | All apps | `fc-cache` refresh |

### Linux Family Modules Used

```
system/shared/family/linux/
├── settings/
│   ├── system/
│   │   └── keyboard.nix         # XKB layout + Mac-style modifier remap
│   │
│   └── user/
│       ├── fonts.nix            # Font installation + fc-cache
│       └── home-directory.nix   # XDG base directories
```

**Integration**: Niri family DOES NOT duplicate these - it composes with them.

## Discovery System Integration

### Family Auto-Discovery

**Validation** (`system/nixos/lib/nixos.nix`):

```nix
# Validate family exists
discovery.validateFamilyExists {
  familyList = hostData.family or [];
  validFamilies = ["linux" "gnome" "niri"];  # niri added to valid list
  familyPath = ../../../system/shared/family;
};
```

**Auto-Installation** (`system/nixos/lib/nixos.nix`):

```nix
# Get family default.nix paths
familySettingsDefaults = configLoader.getFamilyDefaults {
  hostFamily = hostData.family or [];  # ["linux", "niri"]
};

# Result:
# [
#   system/shared/family/linux/settings/system/default.nix
#   system/shared/family/niri/settings/system/default.nix
# ]
```

**Module Imports**:

```nix
# In system configuration
{
  imports = [] ++ familySettingsDefaults ++ [ /* ... */ ];
}
```

**No manual imports required** - Discovery system handles everything.

### Module Auto-Discovery

**System-Level** (`niri/settings/system/default.nix`):

```nix
let
  discovery = import ../../../../lib/discovery.nix {inherit lib;};
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
# Discovers: compositor.nix, display-manager.nix, session.nix
```

**User-Level** (`niri/settings/user/default.nix`):

```nix
let
  discovery = import ../../../../lib/discovery.nix {inherit lib;};
in {
  imports = lib.optionalAttrs (options ? home) (
    map (file: ./${file}) (discovery.discoverModules ./.)
  );
}
# Discovers: keyboard.nix, wallpaper.nix, theme.nix (only in home-manager context)
```

### Hierarchical Discovery

**NOT APPLICABLE for family settings** - Families use auto-discovery via `default.nix`, not hierarchical search.

**Hierarchical discovery is for**:

- Applications (app directories)
- Settings when multiple families define same setting (first wins)

**Niri family pattern**:

- System settings: Direct imports via `default.nix`
- User settings: Direct imports via `default.nix` (within context guard)
- Apps: Hierarchical discovery (when user selects `waybar`, searches: nixos → niri → linux → shared)

## Feature 030: Font Integration

### Contract

**Feature 030 provides**:

- `config.user.fonts.defaults.monospace` - Monospace fonts
- `config.user.fonts.defaults.sansSerif` - Sans-serif fonts
- `config.user.fonts.defaults.serif` - Serif fonts
- Font package installation
- fontconfig configuration

**Niri family uses**:

- ✅ **No action required** - Applications automatically read fontconfig
- ✅ **No Niri-specific font modules** - Feature 030 handles everything

### Integration Point

```nix
# user/{username}/default.nix
{
  user.fonts.defaults = {
    monospace = { families = ["Berkeley Mono" "Fira Code"]; size = 12; };
    sansSerif = { families = ["Inter"]; size = 10; };
    serif = { families = ["Crimson Pro"]; size = 11; };
  };
}

# Applications in Niri session read fontconfig automatically
# Terminal: Uses monospace fonts
# GTK apps: Use sansSerif fonts
# No Niri-specific configuration needed
```

## Feature 033: Wallpaper Integration

### Contract

**Feature 033 provides**:

- `config.user.wallpaper` (string) - Single wallpaper for all monitors
- `config.user.wallpapers` (array) - Per-monitor wallpapers
- Path expansion (`~/` → `$HOME/`)
- File validation (build-time warning if missing)

**Niri family implements**:

- `niri/settings/user/wallpaper.nix` - swaybg integration
- systemd user service (`niri-wallpaper.service`)
- Reads `config.user.wallpaper` field

### Integration Point

```nix
# niri/settings/user/wallpaper.nix
let
  hasWallpaper = (config.user.wallpaper or null) != null;
  wallpaperPath = config.user.wallpaper or "";
  
  expandPath = path:
    if lib.hasPrefix "~/" path
    then "${config.home.homeDirectory}/${lib.removePrefix "~/" path}"
    else path;
in {
  config = lib.optionalAttrs (options ? home && hasWallpaper) {
    systemd.user.services.niri-wallpaper = {
      Service.ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${expandPath wallpaperPath} -m fill";
      # ...
    };
  };
}
```

**Behavior**:

- If `user.wallpaper` set → swaybg launches with specified image
- If `user.wallpaper` not set → service not created (graceful skip)
- Path expansion matches Feature 033 GNOME implementation

### Future: Per-Monitor Wallpapers

```nix
# Future enhancement (Phase 2 or separate feature)
# user/{username}/default.nix
{
  user.wallpapers = [
    { monitor = 0; path = "~/left.jpg"; }
    { monitor = 1; path = "~/right.jpg"; }
  ];
}

# niri/settings/user/wallpaper.nix would create multiple services:
# niri-wallpaper-0.service (for monitor 0)
# niri-wallpaper-1.service (for monitor 1)
```

## Feature 036: Standalone Home Manager

### Contract

**Feature 036 provides**:

- Dual configuration outputs:
  - `darwinConfigurations.{user}-{host}` (system-level)
  - `homeConfigurations."{user}@{host}"` (user-level)
- Standalone home-manager activation (Stage 2)
- Independent system and user configurations

**Niri family respects**:

- System settings run in Stage 1 (NixOS rebuild)
- User settings run in Stage 2 (home-manager activation)
- Context segregation (system/ and user/ subdirectories)

### Integration Point

**Stage 1 (System Build)**:

```nix
# nixos-rebuild switch
# Imports: niri/settings/system/default.nix
# Installs: Niri compositor, greetd, Wayland environment
# Result: System has Niri available, but user config not yet applied
```

**Stage 2 (User Activation)**:

```nix
# home-manager switch
# Imports: niri/settings/user/default.nix (within options ? home guard)
# Installs: Niri config file, swaybg service, GTK theme
# Result: User has personalized Niri configuration
```

**Commands**:

```bash
# Install both stages
just install user host

# Internally runs:
# 1. sudo nixos-rebuild switch --flake ".#user-host"  (Stage 1)
# 2. home-manager switch --flake ".#user@host"        (Stage 2)
```

## Feature 039: Context Segregation

### Contract

**Feature 039 requires**:

- Settings organized in `system/` and `user/` subdirectories
- System-level: Uses `system.*`, `environment.*`, `services.*` options
- User-level: Uses `home.*`, `programs.*`, `xdg.*`, `dconf.*` options
- Context guards: User-level modules use `lib.optionalAttrs (options ? home)`

**Niri family implements**:

```
niri/settings/
├── system/          # System-level (NixOS context)
│   ├── default.nix  # No context guard (always runs in system context)
│   ├── compositor.nix
│   ├── display-manager.nix
│   └── session.nix
│
└── user/            # User-level (home-manager context)
    ├── default.nix  # Context guard: lib.optionalAttrs (options ? home)
    ├── keyboard.nix # Context guard: lib.optionalAttrs (options ? home)
    ├── wallpaper.nix
    └── theme.nix
```

### Integration Point

**System-level modules** (no context validation needed):

```nix
# niri/settings/system/compositor.nix
{
  config,
  lib,
  pkgs,
  # NO options parameter
  ...
}: {
  programs.niri.enable = lib.mkDefault true;  # System option
}
```

**User-level modules** (context validation required):

```nix
# niri/settings/user/keyboard.nix
{
  config,
  lib,
  pkgs,
  options,  # REQUIRED
  ...
}: {
  config = lib.optionalAttrs (options ? home) {  # Context guard
    xdg.configFile."niri/config.kdl".text = ''...'';  # Home option
  };
}
```

## Platform Library Integration

### NixOS Platform Library

**File**: `system/nixos/lib/nixos.nix`

**Changes Required**: ✅ **NONE**

**Why**: Discovery system automatically:

1. Validates Niri family exists (via `validateFamilyExists`)
1. Imports `niri/settings/system/default.nix` (via `getFamilyDefaults`)
1. Loads all Niri system modules (via auto-discovery)

**Existing Logic**:

```nix
# nixos.nix already handles family discovery
familySettingsDefaults = configLoader.getFamilyDefaults {
  hostFamily = hostData.family or [];
};

# Niri family automatically included when host declares it
```

### Discovery Library

**File**: `system/shared/lib/discovery.nix`

**Changes Required**: ✅ **NONE**

**Why**: Discovery functions are generic:

- `discoverModules` - Finds all `.nix` files recursively
- `validateFamilyExists` - Checks family directory exists
- `getFamilyDefaults` - Returns `settings/system/default.nix` path

**Validation**:

```nix
# discovery.validateFamilyExists checks:
builtins.pathExists (familyPath + "/${familyName}")

# For niri family:
# familyPath = system/shared/family
# familyName = "niri"
# Result: true (directory exists)
```

## User Configuration Integration

### Required User Fields

**Mandatory** (for basic Niri functionality):

```nix
{
  user.name = "username";
  user.applications = ["ghostty" "fuzzel" /* ... */];
}
```

**Optional** (Niri-specific customization):

```nix
{
  user.terminal = "${pkgs.ghostty}/bin/ghostty";  # Read by keyboard.nix
  user.launcher = "${pkgs.fuzzel}/bin/fuzzel";    # Read by keyboard.nix
  user.wallpaper = "~/Pictures/wallpaper.jpg";     # Read by wallpaper.nix
  user.darkMode = true;                            # Read by theme.nix (default: true)
  user.keyboardLayout = "us";                      # Read by keyboard.nix (via linux)
  user.fonts = { /* ... */ };                      # Read system-wide (Feature 030)
}
```

### Fallback Behavior

**All optional fields have sensible defaults**:

| Field | Default | Used By |
|-------|---------|---------|
| `terminal` | `${pkgs.ghostty}/bin/ghostty` | keyboard.nix |
| `launcher` | `${pkgs.fuzzel}/bin/fuzzel` | keyboard.nix |
| `wallpaper` | `null` (no wallpaper) | wallpaper.nix |
| `darkMode` | `true` | theme.nix |
| `keyboardLayout` | `"us"` (from linux family) | keyboard.nix |

**Graceful degradation**:

- Missing `user.terminal` → Uses default terminal
- Missing `user.wallpaper` → No wallpaper (blank background)
- Missing `user.darkMode` → Uses dark mode by default

## Testing Integration Points

### Discovery System Test

```bash
# Test family validation
nix eval ".#nixosConfigurations.test-niri.config.system.build.toplevel" --json

# Should succeed without errors
# Output: Nix store path for system configuration
```

### Linux Family Composition Test

```bash
# Test family composition (linux + niri)
nix build ".#nixosConfigurations.test-niri-host.config.system.build.toplevel"

# Verify both families loaded:
# - Linux family: XKB layout set
# - Niri family: Compositor installed
```

### User Config Integration Test

```bash
# Test user config fields read correctly
nix eval ".#homeConfigurations.\"user@host\".config.xdg.configFile.\"niri/config.kdl\".text" --raw

# Should output Niri config with:
# - Terminal command from user.terminal
# - Launcher command from user.launcher
# - Keyboard layout from user.keyboardLayout
```

### Wallpaper Integration Test

```bash
# Test wallpaper service generation
nix eval ".#homeConfigurations.\"user@host\".config.systemd.user.services" --json | jq '.["niri-wallpaper"]'

# Should output service definition with:
# - ExecStart contains swaybg command
# - Wallpaper path from user.wallpaper
```

## Error Scenarios

### Family Not Found

```nix
# Host declares non-existent family
{
  family = ["linux", "niri-typo"];  # Typo in family name
}
```

**Expected**: Evaluation error with message:

```
error: Family 'niri-typo' not found in system/shared/family/
Did you mean: niri, gnome, linux?
```

### Conflicting Families

```nix
# Host declares conflicting desktop environments
{
  family = ["gnome", "niri"];
}
```

**Expected**: Validation warning (both install desktop environments)

**Recommendation**: Add validation to `validateFamilyExists` to detect conflicts.

### Missing Linux Family

```nix
# Niri declared without linux family
{
  family = ["niri"];  # Missing "linux"
}
```

**Expected**: Works but loses Linux-specific settings (XKB layout, XDG dirs)

**Recommendation**: Documentation should note that `linux` family is recommended for NixOS hosts.

## Migration Support

### From GNOME to Niri

**Before**:

```nix
{
  family = ["linux", "gnome"];
}
```

**After**:

```nix
{
  family = ["linux", "niri"];
}
```

**What changes**:

- ✅ Compositor: GNOME Shell → Niri
- ✅ Display manager: GDM → greetd
- ✅ Panel: GNOME Panel → Waybar (if user adds `waybar` app)
- ✅ Wallpaper: GNOME background → swaybg
- ✅ Settings: dconf → KDL config file

**What stays the same**:

- ✅ User apps (all apps work on both)
- ✅ Fonts (fontconfig works everywhere)
- ✅ GTK theme (both use GTK apps)
- ✅ Wayland (both are Wayland compositors)

## Compliance Matrix

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Compose with linux family | ✅ Pass | Family order: `["linux", "niri"]` |
| Use discovery system | ✅ Pass | Auto-discovery via `default.nix` |
| Context segregation (Feature 039) | ✅ Pass | `system/` and `user/` subdirectories |
| Standalone home-manager (Feature 036) | ✅ Pass | User modules use context guards |
| Font integration (Feature 030) | ✅ Pass | No Niri-specific config needed |
| Wallpaper integration (Feature 033) | ✅ Pass | Reads `user.wallpaper` field |
| No manual imports | ✅ Pass | Discovery system handles all imports |
| No platform library changes | ✅ Pass | Generic discovery functions work as-is |
