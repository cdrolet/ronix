# User Locale Configuration

Configure your system's language, keyboard layouts, timezone, and regional settings declaratively in your user configuration.

## Overview

The user locale configuration feature allows you to specify your localization preferences directly in your user config file. All settings are optional - if you don't specify them, the system uses sensible platform defaults.

**Supported Settings**:

- **Languages**: System UI language and fallback languages
- **Keyboard Layouts**: Available keyboard layouts for switching
- **Timezone**: System timezone for accurate time display
- **Regional Locale**: Date/time/number format, measurements, currency

## Quick Start

Add locale preferences to your user config (`user/<username>/default.nix`):

```nix
user = {
  name = "yourname";
  email = "you@example.com";
  fullName = "Your Full Name";
  
  # Locale configuration (all fields optional)
  languages = [ "en-CA" "fr-CA" ];
  keyboardLayout = [ "us" "canadian-english" ];
  timezone = "America/Toronto";
  locale = "en_CA.UTF-8";
};
```

After editing, rebuild your configuration:

```bash
# Build configuration
just build <username> <profile>

# Apply to system (darwin)
darwin-rebuild switch --flake .#<username>-<profile>
```

**Note**: Keyboard layout changes require logout/login to take effect.

## Configuration Fields

### Languages

Sets the system UI language and fallback languages.

**Format**: Array of ISO 639-1 + ISO 3166-1 language codes

**Behavior**: First language is primary, subsequent languages are fallbacks

**Examples**:

```nix
languages = [ "en-US" ];                    # English (US) only
languages = [ "en-CA" "fr-CA" ];            # English (Canada) with French fallback
languages = [ "fr-FR" "en-GB" "de" ];       # French, British English, German
```

**Common Language Codes**:

- `"en-US"` - English (United States)
- `"en-CA"` - English (Canada)
- `"en-GB"` - English (United Kingdom)
- `"fr-CA"` - French (Canada)
- `"fr-FR"` - French (France)
- `"de"` - German
- `"es"` - Spanish
- `"it"` - Italian
- `"pt"` - Portuguese
- `"ja"` - Japanese
- `"zh-CN"` - Chinese (Simplified)

### Keyboard Layouts

Sets available keyboard layouts (accessible via menu bar or keyboard shortcut).

**Format**: Array of platform-agnostic layout names

**Behavior**: First layout is default, others available for switching

**Examples**:

```nix
keyboardLayout = [ "us" ];                                   # US QWERTY only
keyboardLayout = [ "canadian-english" "canadian-french" ];   # Canadian English and French
keyboardLayout = [ "canadian-french" "us" ];                 # Canadian French with US fallback
```

**Available Layouts** (currently supported):

- `"us"` - U.S. QWERTY
- `"canadian-english"` - Canadian English
- `"canadian-french"` - Canadian French (CSA)

**Adding New Layouts**:

New keyboard layouts must be added in two places:

1. **Add to shared registry** (`platform/shared/lib/keyboard-layouts.nix`):

   ```nix
   layouts = {
     us = "U.S. QWERTY";
     canadian-english = "Canadian English";
     canadian-french = "Canadian French (CSA)";
     your-layout = "Your Layout Description";  # Add here
   };
   ```

1. **Add platform translation** (`platform/darwin/lib/keyboard-layout-translation.nix`):

   - Follow the discovery procedure in the file header to find the macOS keyboard layout ID
   - Add translation entry:
     ```nix
     your-layout = {
       id = <discovered-id>;
       name = "macOS Layout Name";
     };
     ```

**Validation**: The build will fail with a clear error if:

- You use a layout not defined in the shared registry
- A platform is missing translations for layouts in the shared registry

### Timezone

Sets the system timezone for accurate time display.

**Format**: IANA timezone identifier (string)

**Examples**:

```nix
timezone = "America/Toronto";      # Eastern Time (Canada)
timezone = "America/Vancouver";    # Pacific Time (Canada)
timezone = "America/New_York";     # Eastern Time (US)
timezone = "Europe/London";        # GMT/BST
timezone = "Asia/Tokyo";           # Japan Standard Time
```

**Reference**: [List of tz database timezones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

### Locale

Sets regional formatting for dates, numbers, currency, and measurements.

**Format**: POSIX locale identifier (language_REGION.encoding)

**Behavior**: Controls display formats, independent of UI language

**Examples**:

```nix
locale = "en_CA.UTF-8";   # English (Canada): metric, CAD, YYYY-MM-DD
locale = "en_US.UTF-8";   # English (US): imperial, USD, MM/DD/YYYY
locale = "fr_CA.UTF-8";   # French (Canada): metric, CAD, French formatting
locale = "en_GB.UTF-8";   # English (UK): metric, GBP, DD/MM/YYYY
```

**What Locale Controls**:

- **Date format**: YYYY-MM-DD (CA) vs MM/DD/YYYY (US) vs DD/MM/YYYY (GB)
- **Time format**: 24-hour vs 12-hour
- **Number format**: 1,234.56 vs 1 234,56
- **Currency**: $ (USD) vs $ (CAD) vs £ (GBP)
- **Measurements**: Metric (cm, kg) vs Imperial (in, lb)

**Note**: Locale can differ from languages. Example: English UI with Canadian formatting.

## Platform-Specific Behavior

### macOS (darwin)

All locale settings are applied to macOS system preferences:

- **Languages**: `System Preferences → Language & Region → Preferred Languages`
- **Keyboard Layouts**: `System Preferences → Keyboard → Input Sources`
- **Timezone**: `System Preferences → Date & Time → Time Zone`
- **Locale**: `System Preferences → Language & Region → Region`

**Automatic Settings** (derived from locale):

- Measurement units (metric/imperial) detected from locale region
- Temperature units follow measurement system
- Number/currency formatting follows locale conventions

### Future Platforms

The configuration is designed to be platform-agnostic:

- User config uses platform-agnostic names (e.g., `"us"` for keyboard)
- Platform libraries translate to platform-specific identifiers
- NixOS support can be added by creating similar translation layer

## Default Behavior

**All locale fields are optional**. If you don't specify a field:

- System uses platform defaults (typically en-US, US keyboard, America/New_York)
- Existing configurations without locale fields continue to work (backward compatible)
- You can specify some fields and omit others

**Example** (only timezone):

```nix
user = {
  name = "username";
  # ... other fields ...
  timezone = "America/Toronto";  # Only setting timezone
};
```

## Verification

After applying your configuration, verify the settings:

### Languages

```bash
defaults read NSGlobalDomain AppleLanguages
# Expected: ( "en-CA", "fr-CA" )
```

### Keyboard Layouts

```bash
defaults read com.apple.HIToolbox AppleSelectedInputSources
# Expected: Array with configured layouts
```

### Timezone

```bash
sudo systemsetup -gettimezone
# Expected: Time Zone: America/Toronto
```

### Locale & Regional Settings

```bash
defaults read NSGlobalDomain AppleLocale
# Expected: en_CA

defaults read NSGlobalDomain AppleMeasurementUnits
# Expected: Centimeters (for metric) or Inches (for imperial)
```

## Troubleshooting

### Keyboard layouts not appearing

**Problem**: New keyboard layouts don't show in menu bar after rebuild

**Solution**: Logout and login. macOS requires session restart for keyboard layout changes.

### Unknown layout error

**Problem**: Build fails with "Unknown keyboard layout: 'layout-name'"

**Solution**:

1. Check spelling matches available layouts list
1. Layout might not be in registry yet - see adding new layouts section
1. Available layouts listed in error message

### Layout with null ID error

**Problem**: Build fails with "KeyboardLayout ID is null"

**Solution**: The layout exists in registry but ID hasn't been discovered yet. Follow the discovery procedure in `platform/darwin/lib/keyboard-layout-translation.nix`.

### Settings not applying

**Problem**: Configuration builds but settings don't change

**Solution**:

1. Verify you ran `darwin-rebuild switch` (not just build)
1. Keyboard layouts require logout/login
1. Check System Preferences to see if settings took effect
1. Some settings may require system restart

### Multi-user conflicts

**Problem**: Worried about multiple users interfering

**Solution**: User locale settings are per-user and isolated. Each user can have different locale preferences without affecting others.

## Examples

### Bilingual Canadian User

```nix
user = {
  name = "user";
  languages = [ "en-CA" "fr-CA" ];
  keyboardLayout = [ "canadian-english" "canadian-french" ];
  timezone = "America/Toronto";
  locale = "en_CA.UTF-8";
};
```

### US Developer

```nix
user = {
  name = "developer";
  languages = [ "en-US" ];
  keyboardLayout = [ "us" ];
  timezone = "America/New_York";
  locale = "en_US.UTF-8";
};
```

### French Canadian User

```nix
user = {
  name = "user";
  languages = [ "fr-CA" "en-CA" ];
  keyboardLayout = [ "canadian-french" "us" ];
  timezone = "America/Montreal";
  locale = "fr_CA.UTF-8";
};
```

### West Coast User

```nix
user = {
  name = "pacific-user";
  languages = [ "en-US" ];
  keyboardLayout = [ "us" "canadian-english" ];
  timezone = "America/Vancouver";
  locale = "en_US.UTF-8";
};
```

### Minimal Configuration (timezone only)

```nix
user = {
  name = "user";
  # Only set timezone, use defaults for everything else
  timezone = "America/Vancouver";
};
```

## Technical Details

### Architecture

- **User config schema**: `user/shared/lib/home-manager.nix` defines locale field options
- **Shared registry**: `platform/shared/lib/keyboard-layouts.nix` defines all supported layouts
- **Darwin settings**: `platform/darwin/settings/locale.nix` consumes user config
- **Translation layer**: `platform/darwin/lib/keyboard-layout-translation.nix` maps agnostic names to darwin IDs
- **Validation**: Build-time validation ensures platform translations match shared registry
- **Auto-discovery**: Settings module automatically discovered, no manual imports needed

### Constitutional Compliance

- **Module size**: locale.nix is 155 lines (under 200-line limit)
- **Declarative**: All settings declared in Nix expressions
- **Backward compatible**: Optional fields, existing configs work unchanged
- **Multi-user**: Per-user settings via user config object
- **Platform-agnostic**: User config uses agnostic names, platform translates

### Files Modified

This feature modified these files:

- `platform/shared/lib/keyboard-layouts.nix` (new - shared registry)
- `platform/darwin/lib/keyboard-layout-translation.nix` (new - darwin translations with validation)
- `platform/darwin/settings/locale.nix` (new - darwin locale settings)
- `user/shared/lib/home-manager.nix` (added locale options)
- `platform/darwin/settings/keyboard.nix` (removed hardcoded locale settings)

## See Also

- Specification: `specs/018-user-locale-config/spec.md`
- Implementation Plan: `specs/018-user-locale-config/plan.md`
- Research Notes: `specs/018-user-locale-config/research.md`
- Developer Guide: `specs/018-user-locale-config/quickstart.md`
