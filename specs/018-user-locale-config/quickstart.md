# Quickstart: Implementing User Locale Configuration

**Feature**: 018-user-locale-config\
**Target**: Developers implementing this feature\
**Estimated Time**: 4-6 hours

## Prerequisites

- Familiarity with Nix module system
- Understanding of nix-darwin configuration
- Access to macOS system for testing
- Read `research.md` and `data-model.md` for context

## Implementation Steps

### Step 1: Create Keyboard Layout Translation Registry (30 min)

**File**: `platform/darwin/lib/keyboard-layout-translation.nix`

```nix
{
  darwin = {
    us = { id = 0; name = "U.S."; };
    canadian = { id = 29; name = "Canadian"; };
    canadian-french = { id = null; name = "Canadian-CSA"; };
    british = { id = null; name = "British"; };
    dvorak = { id = null; name = "Dvorak"; };
    colemak = { id = null; name = "Colemak"; };
    french = { id = null; name = "French"; };
    german = { id = null; name = "German"; };
    spanish = { id = null; name = "Spanish"; };
    brazilian = { id = null; name = "Brazilian"; };
  };
}
```

**Validation**:

```bash
nix eval --impure --expr 'import ./platform/darwin/lib/keyboard-layout-translation.nix'
```

**Notes**:

- IDs with `null` need manual discovery (see Step 6)
- Can start with just `us` and `canadian` (known IDs) for initial testing

______________________________________________________________________

### Step 2: Create Darwin Locale Settings Module (90 min)

**File**: `platform/darwin/settings/locale.nix`

```nix
{ config, lib, pkgs, userContext, ... }:

let
  # Import keyboard layout translation registry
  layoutRegistry = import ../lib/keyboard-layout-translation.nix;
  
  # Access user configuration
  user = userContext.user or {};
  
  # Check which locale fields are specified
  hasLanguages = user ? languages && user.languages != [] && user.languages != null;
  hasKeyboardLayout = user ? keyboardLayout && user.keyboardLayout != [] && user.keyboardLayout != null;
  hasTimezone = user ? timezone && user.timezone != null;
  hasLocale = user ? locale && user.locale != null;
  
  # Translate platform-agnostic keyboard layout names to darwin layout objects
  translateLayout = layoutName:
    let
      layout = layoutRegistry.darwin.${layoutName} or null;
    in
      if layout == null then
        throw ''
          Unknown keyboard layout: '${layoutName}'
          Available layouts: ${lib.concatStringsSep ", " (lib.attrNames layoutRegistry.darwin)}
        ''
      else if layout.id == null then
        throw ''
          Keyboard layout '${layoutName}' has not been configured yet (ID is null).
          Please discover the KeyboardLayout ID by:
          1. Manually configuring the layout in System Preferences
          2. Running: defaults read com.apple.HIToolbox AppleSelectedInputSources
          3. Updating platform/darwin/lib/keyboard-layout-translation.nix with the ID
        ''
      else
        {
          InputSourceKind = "Keyboard Layout";
          "KeyboardLayout ID" = layout.id;
          "KeyboardLayout Name" = layout.name;
        };
  
  # Strip .UTF-8 suffix from locale for macOS
  stripEncoding = locale: lib.removeSuffix ".UTF-8" locale;
  
  # Derive metric/imperial from locale region
  # Simple heuristic: US uses imperial, most others use metric
  isMetric = locale:
    let
      region = lib.last (lib.splitString "_" (stripEncoding locale));
      imperialRegions = [ "US" ];
    in
      !(lib.elem region imperialRegions);
  
in {
  # Timezone configuration (top-level option)
  time.timeZone = lib.mkIf hasTimezone (lib.mkDefault user.timezone);
  
  # Language and locale settings
  system.defaults.CustomUserPreferences."Apple Global Domain" = lib.mkMerge [
    (lib.mkIf hasLanguages {
      AppleLanguages = lib.mkDefault user.languages;
    })
    (lib.mkIf hasLocale {
      AppleLocale = lib.mkDefault (stripEncoding user.locale);
    })
  ];
  
  # Regional settings derived from locale
  system.defaults.NSGlobalDomain = lib.mkIf hasLocale {
    AppleMeasurementUnits = lib.mkDefault (if isMetric user.locale then "Centimeters" else "Inches");
    AppleMetricUnits = lib.mkDefault (if isMetric user.locale then 1 else 0);
    # Could add AppleTemperatureUnit, AppleICUForce24HourTime based on locale if desired
  };
  
  # Keyboard layout configuration
  system.defaults.CustomUserPreferences."com.apple.HIToolbox" = lib.mkIf hasKeyboardLayout {
    AppleSelectedInputSources = lib.mkDefault (map translateLayout user.keyboardLayout);
  };
}
```

**Validation**:

```bash
nix eval --impure --expr '(import ./platform/darwin/settings/locale.nix { lib = (import <nixpkgs> {}).lib; config = {}; pkgs = import <nixpkgs> {}; userContext = { user = { languages = ["en-CA"]; }; }; }).time.timeZone or "not set"'
```

______________________________________________________________________

### Step 3: Update Darwin Settings Default Import (5 min)

**File**: `platform/darwin/settings/default.nix`

Add locale.nix to imports:

```nix
{
  imports = [
    ./dock.nix
    ./finder.nix
    ./keyboard.nix
    ./locale.nix  # NEW
    # ... other settings
  ];
}
```

**Validation**:

```bash
grep -q "locale.nix" platform/darwin/settings/default.nix && echo "✓ Import added" || echo "✗ Import missing"
```

______________________________________________________________________

### Step 4: Update Darwin Lib to Pass User Config Object (45 min)

**File**: `platform/darwin/lib/darwin.nix`

**Current state** (hypothetical - verify actual structure):

```nix
userContext = {
  user = username;  # Just a string
  platform = "darwin";
  profile = profileName;
};
```

**Required change**:

```nix
# Need to import user config and pass full config object
let
  userConfigPath = ../../user/${username}/default.nix;
  userConfig = import userConfigPath { inherit config lib pkgs; userContext = { user = username; platform = "darwin"; profile = profileName; }; };
in {
  # Pass to home-manager
  home-manager.extraSpecialArgs = {
    userContext = {
      user = userConfig.config.user;  # Full user config object
      platform = "darwin";
      profile = profileName;
    };
  };
  
  # ALSO need to pass to darwin settings modules
  specialArgs = {
    userContext = {
      user = userConfig.config.user;
      platform = "darwin";
      profile = profileName;
    };
  };
}
```

**Note**: This step requires careful analysis of the actual darwin.nix structure. The key requirement is ensuring `userContext.user` contains the full user configuration object (with `languages`, `keyboardLayout`, etc.) not just the username string.

**Validation**: Check that locale.nix can access `userContext.user.languages`, etc.

______________________________________________________________________

### Step 5: Add User Config Fields to User Configs (15 min)

**Files**: `user/cdrokar/default.nix`, `user/cdrolet/default.nix`, `user/cdrixus/default.nix`

Add locale fields (optional) to at least one user for testing:

```nix
{ userContext, lib, ... }:
let
  discovery = import ../../system/shared/lib/discovery.nix { inherit lib; };
in {
  imports = [
    ../shared/lib/home-manager.nix
    (discovery.mkApplicationsModule {
      applications = [ "git" "zsh" "helix" ];
      user = userContext.user;
      platform = userContext.platform;
      profile = userContext.profile;
    })
  ];
  
  user = {
    name = "cdrokar";
    email = "charles@example.com";
    fullName = "Charles Drolet";
    
    # NEW: Locale configuration (all optional)
    languages = [ "en-CA" "fr-CA" ];
    keyboardLayout = [ "us" "canadian" ];
    timezone = "America/Toronto";
    locale = "en_CA.UTF-8";
  };
}
```

**Validation**:

```bash
nix flake check
```

______________________________________________________________________

### Step 6: Discover Missing Keyboard Layout IDs (30 min)

For each layout with `id = null` in the registry:

1. Open **System Preferences** → **Keyboard** → **Input Sources**
1. Click **+** and add the layout (e.g., "Dvorak")
1. Run the discovery command:
   ```bash
   defaults read com.apple.HIToolbox AppleSelectedInputSources
   ```
1. Find the entry for the layout and note the `KeyboardLayout ID` value
1. Update `platform/darwin/lib/keyboard-layout-translation.nix` with the discovered ID

**Example output**:

```
(
    {
        InputSourceKind = "Keyboard Layout";
        "KeyboardLayout ID" = 16300;
        "KeyboardLayout Name" = Dvorak;
    }
)
```

**Update registry**:

```nix
dvorak = { id = 16300; name = "Dvorak"; };  # Was: id = null
```

**Priority**: Start with layouts you actually need for testing. Discovering all 10 layouts can be done incrementally.

______________________________________________________________________

### Step 7: Refactor Existing Keyboard Settings (30 min)

**Current**: `platform/darwin/settings/keyboard.nix` contains hardcoded locale settings

**Before**:

```nix
system.defaults.CustomUserPreferences."Apple Global Domain" = {
  AppleLanguages = lib.mkDefault ["en-CA" "fr-CA"];
  AppleLocale = lib.mkDefault "en_CA";
  AppleMeasurementUnits = lib.mkDefault "Centimeters";
  AppleMetricUnits = lib.mkDefault 1;
};
```

**After** (remove locale settings, keep keyboard settings):

```nix
# Keyboard key repeat and UI mode settings only
system.defaults.NSGlobalDomain = {
  KeyRepeat = lib.mkDefault 2;
  InitialKeyRepeat = lib.mkDefault 10;
  ApplePressAndHoldEnabled = lib.mkDefault false;
  AppleKeyboardUIMode = lib.mkDefault 3;
};

# Remove AppleLanguages, AppleLocale, AppleMeasurementUnits, AppleMetricUnits
# (now handled by locale.nix)
```

**Rationale**: Separation of concerns - keyboard.nix for keyboard behavior, locale.nix for locale settings

**Validation**: Verify no duplication between keyboard.nix and locale.nix

______________________________________________________________________

### Step 8: Build and Test (45 min)

**Build configuration**:

```bash
# Check syntax
nix flake check

# Build for user with locale settings
just build cdrokar home-macmini-m4

# Inspect generated configuration
nix build ".#darwinConfigurations.cdrokar-home-macmini-m4.system" --show-trace
```

**Apply configuration** (if using darwin-rebuild):

```bash
darwin-rebuild switch --flake .#cdrokar-home-macmini-m4
```

**Verify settings applied**:

```bash
# Language
defaults read NSGlobalDomain AppleLanguages
# Expected: ( "en-CA", "fr-CA" )

# Locale
defaults read NSGlobalDomain AppleLocale
# Expected: en_CA

# Keyboard layouts
defaults read com.apple.HIToolbox AppleSelectedInputSources
# Expected: Array with US and Canadian layouts

# Timezone
sudo systemsetup -gettimezone
# Expected: Time Zone: America/Toronto

# Measurement units
defaults read NSGlobalDomain AppleMeasurementUnits
# Expected: Centimeters
```

**Test backward compatibility**:

```bash
# Build config for user WITHOUT locale settings
# Should succeed with no errors (uses platform defaults)
just build cdrolet home-macmini-m4  # Assuming cdrolet has no locale fields
```

**Test multi-user isolation**:

```bash
# Add different locale settings to cdrolet user
# Build both configs, verify no interference
just build cdrokar home-macmini-m4
just build cdrolet home-macmini-m4
```

______________________________________________________________________

### Step 9: Update Documentation (30 min)

**File**: `docs/features/018-user-locale-config.md`

Create user-facing documentation:

```markdown
# User Locale Configuration

Configure your system's language, keyboard layouts, timezone, and regional settings
declaratively in your user configuration.

## Quick Start

Add locale preferences to your user config (`user/<username>/default.nix`):

\`\`\`nix
user = {
  name = "yourname";
  email = "you@example.com";
  fullName = "Your Full Name";
  
  # Optional locale configuration
  languages = [ "en-CA" "fr-CA" ];  # Primary: English (Canada), Fallback: French (Canada)
  keyboardLayout = [ "us" "canadian-french" ];  # Default: US, Available: Canadian French
  timezone = "America/Toronto";  # Eastern Time
  locale = "en_CA.UTF-8";  # Canadian English formatting
};
\`\`\`

## Available Settings

### Languages

Sets system UI language and fallback languages.

**Format**: Array of ISO 639-1 + ISO 3166-1 language codes

**Examples**:
- `[ "en-US" ]` - English (US) only
- `[ "en-CA" "fr-CA" ]` - English (Canada) with French fallback
- `[ "fr-FR" "en-GB" ]` - French (France) with British English fallback

**Common Codes**: en-US, en-CA, en-GB, fr-CA, fr-FR, de, es, it, pt, ja, zh-CN

### Keyboard Layouts

Sets available keyboard layouts (switch via menu bar or keyboard shortcut).

**Format**: Array of platform-agnostic layout names

**Available Layouts**: us, canadian, canadian-french, british, dvorak, colemak, french, german, spanish, brazilian

**Examples**:
- `[ "us" ]` - US QWERTY only
- `[ "canadian" "canadian-french" ]` - Canadian English and French
- `[ "dvorak" "us" ]` - Dvorak with US QWERTY fallback

### Timezone

Sets system timezone for accurate time display.

**Format**: IANA timezone identifier (string)

**Examples**:
- `"America/Toronto"` - Eastern Time (Canada)
- `"America/Vancouver"` - Pacific Time (Canada)
- `"Europe/London"` - GMT/BST
- `"Asia/Tokyo"` - Japan Standard Time

**Reference**: [List of tz database timezones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

### Locale

Sets regional formatting for dates, numbers, currency, and measurements.

**Format**: POSIX locale identifier (language_REGION.encoding)

**Examples**:
- `"en_CA.UTF-8"` - English (Canada): metric, CAD, YYYY-MM-DD dates
- `"en_US.UTF-8"` - English (US): imperial, USD, MM/DD/YYYY dates
- `"fr_CA.UTF-8"` - French (Canada): metric, CAD, French formatting

**Note**: Locale can differ from languages (e.g., English UI with Canadian formatting)

## Applying Changes

After editing your user config:

\`\`\`bash
# Rebuild configuration
just build <username> <profile>

# Apply to system (darwin-rebuild)
darwin-rebuild switch --flake .#<username>-<profile>

# Logout/login for keyboard layout changes to take effect
\`\`\`

## Default Behavior

All locale settings are **optional**. If you don't specify them, the system uses platform defaults (typically en-US/US keyboard/America/New_York/en_US.UTF-8 on macOS).

## Troubleshooting

**Keyboard layouts not appearing**: Logout and login after applying configuration.

**Unknown layout error**: Check that the layout name matches one of the available layouts listed above.

**Timezone not updating**: Run `sudo systemsetup -gettimezone` to verify, may require system restart.
```

______________________________________________________________________

## Testing Checklist

- [ ] `nix flake check` passes
- [ ] Build succeeds for user with all locale fields specified
- [ ] Build succeeds for user with no locale fields (backward compatibility)
- [ ] Build succeeds for user with partial locale fields (e.g., only timezone)
- [ ] Multi-user build succeeds with different locale settings per user
- [ ] Language preferences applied correctly (verify with `defaults read`)
- [ ] Timezone applied correctly (verify with `systemsetup`)
- [ ] Keyboard layouts available (verify with `defaults read` and menu bar)
- [ ] Regional settings applied (measurement units, etc.)
- [ ] Unknown keyboard layout throws helpful error message
- [ ] Keyboard layout with null ID throws helpful error message

______________________________________________________________________

## Common Issues

### Issue: `userContext.user.languages` is undefined

**Cause**: `userContext.user` is still a string (username) not the full config object

**Solution**: Update `platform/darwin/lib/darwin.nix` to pass full user config object (Step 4)

### Issue: Keyboard layouts not taking effect

**Cause**: macOS requires logout/login for keyboard layout changes

**Solution**: Document this limitation, recommend logout after first configuration

### Issue: Build error "Unknown keyboard layout"

**Cause**: Typo in layout name or layout not in registry

**Solution**: Check spelling, verify layout exists in `keyboard-layout-translation.nix`

### Issue: Build error "Keyboard layout ID is null"

**Cause**: Layout ID hasn't been discovered yet

**Solution**: Follow discovery procedure in Step 6

______________________________________________________________________

## Implementation Time Estimate

| Step | Estimated Time | Priority |
|------|----------------|----------|
| 1. Translation registry | 30 min | High |
| 2. Locale settings module | 90 min | High |
| 3. Update imports | 5 min | High |
| 4. Pass user config object | 45 min | High |
| 5. Add user config fields | 15 min | High |
| 6. Discover layout IDs | 30 min | Medium |
| 7. Refactor keyboard.nix | 30 min | Medium |
| 8. Build and test | 45 min | High |
| 9. Documentation | 30 min | Medium |
| **Total** | **4-5 hours** | |

**Note**: Step 6 (discover IDs) can be done incrementally for layouts as needed.

______________________________________________________________________

## Next Steps After Implementation

1. Test on actual darwin system with multiple users
1. Add more keyboard layouts to registry as requested
1. Consider optional warnings for language/locale mismatches
1. Plan NixOS implementation (similar pattern, different module options)
1. Update constitution if any new patterns emerge
