# Research: User Locale Configuration for nix-darwin

**Feature**: 018-user-locale-config\
**Date**: 2025-11-15\
**Status**: Complete

## Decisions Summary

### 1. Language Configuration

**Decision**: Use `system.defaults.CustomUserPreferences."Apple Global Domain".AppleLanguages`

**Rationale**:

- Standard nix-darwin pattern already in use in codebase (`platform/darwin/settings/keyboard.nix`)
- Accepts array of language codes in priority order (first = primary, rest = fallbacks)
- Format: `["en-CA" "fr-CA"]` matches macOS system language preferences
- Uses `lib.mkDefault` for user overridability per constitutional requirement

**Alternatives Considered**:

- Home Manager `targets.darwin.defaults.NSGlobalDomain.AppleLanguages`: Considered but system-level setting more appropriate for system language
- Direct `defaults write` via activation script: Rejected, not declarative

**Implementation**:

```nix
system.defaults.CustomUserPreferences."Apple Global Domain" = {
  AppleLanguages = lib.mkIf hasLanguages (lib.mkDefault user.languages);
};
```

______________________________________________________________________

### 2. Keyboard Layout Configuration

**Decision**: Use `system.defaults.CustomUserPreferences."com.apple.HIToolbox".AppleSelectedInputSources` with platform-agnostic translation layer

**Rationale**:

- No native nix-darwin module support for keyboard layouts (only key remapping)
- HIToolbox CustomUserPreferences is the macOS system API for keyboard layout configuration
- Platform-agnostic names (e.g., "us", "canadian-french") map to darwin-specific layout objects
- Translation layer enables future cross-platform support (NixOS, etc.)

**Alternatives Considered**:

- Direct darwin identifiers in user config: Rejected, violates platform-agnostic principle
- Activation script with `defaults write`: Rejected, not declarative
- Wait for native nix-darwin support: Rejected, no timeline for feature addition

**Implementation**:

```nix
# User config
keyboardLayout = [ "us" "canadian-french" ];

# Translation layer (platform/darwin/lib/keyboard-layout-translation.nix)
darwin = {
  us = { id = 0; name = "U.S."; };
  canadian = { id = 29; name = "Canadian"; };
  canadian-french = { id = null; name = "Canadian-CSA"; };  # ID discovery needed
  # ... more layouts
};

# Darwin settings
system.defaults.CustomUserPreferences."com.apple.HIToolbox" = {
  AppleSelectedInputSources = lib.mkDefault (
    map (layout: {
      InputSourceKind = "Keyboard Layout";
      "KeyboardLayout ID" = layout.id;
      "KeyboardLayout Name" = layout.name;
    }) (translateLayouts user.keyboardLayout)
  );
};
```

**Known Issues**:

- KeyboardLayout ID values need manual discovery for most layouts (run `defaults read com.apple.HIToolbox AppleSelectedInputSources` after manual configuration)
- Changes may require logout/login to take effect
- No validation of layout availability at build time

______________________________________________________________________

### 3. Timezone Configuration

**Decision**: Use top-level `time.timeZone` option

**Rationale**:

- Standard nix-darwin/NixOS cross-platform option
- IANA timezone database identifiers (e.g., "America/Toronto", "Europe/Paris")
- Well-documented and widely used
- Platform-agnostic (works on both darwin and NixOS)

**Alternatives Considered**:

- `system.defaults.timezone`: Does not exist in nix-darwin
- Automatic timezone detection: Not reliably supported in declarative configuration

**Implementation**:

```nix
time.timeZone = lib.mkIf hasTimezone (lib.mkDefault user.timezone);
```

**Validation**: Can list all valid timezones with `sudo systemsetup -listtimezones`

______________________________________________________________________

### 4. Regional Locale Configuration

**Decision**: Use combination of `NSGlobalDomain` options and `CustomUserPreferences."Apple Global Domain".AppleLocale`

**Rationale**:

- `AppleLocale` controls date/time/number/currency formatting (POSIX locale format)
- `NSGlobalDomain` options for measurement units, temperature, 24-hour time available natively in nix-darwin
- Combination provides complete regional customization
- User provides full locale (e.g., "en_CA.UTF-8"), we strip .UTF-8 suffix for macOS

**Alternatives Considered**:

- Only AppleLocale: Insufficient, doesn't cover metric/imperial or temperature
- Only NSGlobalDomain: Insufficient, doesn't set core locale
- Extended locale format with modifiers (e.g., "en_GB@currency=EUR"): Future enhancement, start simple

**Implementation**:

```nix
system.defaults.CustomUserPreferences."Apple Global Domain" = {
  AppleLocale = lib.mkIf hasLocale (lib.mkDefault (lib.removeSuffix ".UTF-8" user.locale));
};

system.defaults.NSGlobalDomain = {
  AppleMeasurementUnits = lib.mkDefault "Centimeters";  # Can derive from locale
  AppleMetricUnits = lib.mkDefault 1;
  AppleTemperatureUnit = lib.mkDefault "Celsius";
  AppleICUForce24HourTime = lib.mkDefault true;
};
```

**Known Issues**:

- macOS Mojave+ may not fully respect AppleLocale in all system components
- Requires testing on target macOS version to verify behavior

______________________________________________________________________

### 5. Module Organization

**Decision**: Single `platform/darwin/settings/locale.nix` module (if \<200 lines), split if exceeded

**Rationale**:

- All four locale settings (language, keyboard, timezone, regional) are related
- Estimated ~150-180 lines including translation logic
- Easier to maintain related settings together
- Can split later if constitutional 200-line limit approached

**Alternatives Considered**:

- Four separate modules: Premature split, adds unnecessary file count
- Add to existing `platform/darwin/settings/keyboard.nix`: Violates single-responsibility principle (keyboard remapping vs locale)

**Implementation Location**:

```
platform/darwin/
├── lib/
│   └── keyboard-layout-translation.nix  # Translation layer
└── settings/
    ├── default.nix  # Import locale.nix
    └── locale.nix   # NEW: All locale configuration
```

______________________________________________________________________

### 6. Platform-Agnostic Keyboard Layout Registry

**Decision**: Start with 10 common layouts, expand on demand

**Initial Registry**:

- `us` - U.S. QWERTY (ID: 0)
- `canadian` - Canadian English (ID: 29)
- `canadian-french` - Canadian French CSA (ID: TBD)
- `british` - UK layout (ID: TBD)
- `dvorak` - Dvorak (ID: TBD)
- `colemak` - Colemak (ID: TBD)
- `french` - French (ID: TBD)
- `german` - German (ID: TBD)
- `spanish` - Spanish (ID: TBD)
- `brazilian` - Brazilian Portuguese (ID: TBD)

**Rationale**:

- Covers most common use cases for initial implementation
- Additional layouts can be added as needed
- ID discovery procedure documented for expansion

**Discovery Procedure** (for missing IDs):

1. Manually configure layout in System Preferences → Keyboard → Input Sources
1. Run: `defaults read com.apple.HIToolbox AppleSelectedInputSources`
1. Find layout entry and extract `KeyboardLayout ID` value
1. Update `keyboard-layout-translation.nix` with ID

**Expansion Policy**: Add layouts when users request them, not speculatively

______________________________________________________________________

### 7. User Context Passing

**Decision**: Pass full user config object via `userContext` to darwin settings

**Current State**: `platform/darwin/lib/darwin.nix` passes `userContext` to Home Manager:

```nix
home-manager.extraSpecialArgs = {
  userContext = {
    user = username;  # String, not config object
    platform = "darwin";
    profile = profileName;
  };
};
```

**Required Change**: Pass actual user config object to enable darwin settings to read `user.languages`, `user.keyboardLayout`, etc.

**Implementation**:

```nix
# darwin.nix needs to:
# 1. Import user config
# 2. Pass config object to both home-manager AND darwin settings modules

specialArgs = {
  userContext = {
    user = userConfig;  # Full config object, not just name string
    platform = "darwin";
    profile = profileName;
  };
};
```

**Rationale**: Darwin system settings need access to user locale preferences to configure system-level settings

______________________________________________________________________

### 8. Default Behavior

**Decision**: All locale fields optional, use platform defaults when not specified

**Rationale**:

- Backward compatibility: Existing user configs without locale settings continue to work
- Constitutional requirement: No breaking changes to existing configurations
- Sensible fallback: macOS system defaults are reasonable for most users

**Implementation**:

```nix
# Only set if user provided value
time.timeZone = lib.mkIf hasTimezone (lib.mkDefault user.timezone);
AppleLanguages = lib.mkIf hasLanguages (lib.mkDefault user.languages);
# etc.
```

**Validation**: Test existing user configs (cdrokar, cdrolet, cdrixus) build successfully without locale fields

______________________________________________________________________

### 9. Validation Strategy

**Decision**: Three-tier validation: build-time, activation-time, runtime verification

**Build-Time Validation**:

- `nix flake check`: Syntax and type checking
- Keyboard layout name validation: Throw error for unknown layouts

**Activation-Time Validation**:

- `just build <user> <profile>`: Full build test
- No errors during darwin-rebuild activation

**Runtime Verification**:

```bash
# Verify language settings
defaults read NSGlobalDomain AppleLanguages

# Verify locale
defaults read NSGlobalDomain AppleLocale

# Verify keyboard layouts
defaults read com.apple.HIToolbox AppleSelectedInputSources

# Verify timezone
sudo systemsetup -gettimezone
```

**Multi-User Validation**:

- Build configs for all three users with different locale settings
- Verify no conflicts or interference between user settings

**Rationale**: Comprehensive validation ensures correctness and prevents deployment failures

______________________________________________________________________

## Technical Details

### nix-darwin Module Options Reference

| Setting | Module Option | Type | Format Example |
|---------|--------------|------|----------------|
| Language | `system.defaults.CustomUserPreferences."Apple Global Domain".AppleLanguages` | list of strings | `["en-CA" "fr-CA"]` |
| Timezone | `time.timeZone` | string | `"America/Toronto"` |
| Locale | `system.defaults.CustomUserPreferences."Apple Global Domain".AppleLocale` | string | `"en_CA"` (no .UTF-8) |
| Measurement | `system.defaults.NSGlobalDomain.AppleMeasurementUnits` | enum | `"Centimeters"` | `"Inches"` |
| Metric | `system.defaults.NSGlobalDomain.AppleMetricUnits` | int | `0` | `1` |
| Temperature | `system.defaults.NSGlobalDomain.AppleTemperatureUnit` | enum | `"Celsius"` | `"Fahrenheit"` |
| 24-hour | `system.defaults.NSGlobalDomain.AppleICUForce24HourTime` | bool | `true` | `false` |
| Keyboard | `system.defaults.CustomUserPreferences."com.apple.HIToolbox".AppleSelectedInputSources` | list of attrs | See below |

### Keyboard Layout Object Format

```nix
{
  InputSourceKind = "Keyboard Layout";
  "KeyboardLayout ID" = 0;  # Integer
  "KeyboardLayout Name" = "U.S.";  # String
}
```

### Code Examples from Codebase

Current configuration in `platform/darwin/settings/keyboard.nix`:

```nix
system.defaults.CustomUserPreferences."Apple Global Domain" = {
  AppleLanguages = lib.mkDefault ["en-CA" "fr-CA"];
  AppleLocale = lib.mkDefault "en_CA";
  AppleMeasurementUnits = lib.mkDefault "Centimeters";
  AppleMetricUnits = lib.mkDefault 1;
};
```

This demonstrates the pattern we'll extend to consume user config values.

______________________________________________________________________

## Known Limitations

### Keyboard Layout Configuration

1. **No native nix-darwin support**: Must use CustomUserPreferences
1. **Manual ID discovery required**: KeyboardLayout IDs not documented, must discover via `defaults read`
1. **Activation timing**: Changes may require logout/login or system restart
1. **No build-time layout validation**: Can't verify layout exists on system until activation

### Locale Configuration

1. **macOS version compatibility**: AppleLocale behavior may vary on macOS Mojave+
1. **Split between modules**: Some settings in NSGlobalDomain (native), others in CustomUserPreferences
1. **No locale validation**: Must trust user provides valid POSIX locale identifier

### Multi-User Configuration

1. **System vs user level unclear**: CustomUserPreferences stores in `~/Library/Preferences/` (user-level) but applied via system config
1. **Testing required**: Need to verify multiple users with different locales don't interfere
1. **Home Manager integration**: May need Home Manager `targets.darwin.defaults` for true per-user isolation

______________________________________________________________________

## Open Questions Resolved

### Q: Should we use Home Manager or nix-darwin for locale settings?

**A**: nix-darwin for system-level settings (language, timezone, regional), Home Manager passes user context

### Q: How to handle platform-agnostic keyboard layout naming?

**A**: Translation layer in `platform/darwin/lib/keyboard-layout-translation.nix` maps agnostic names to darwin-specific layout objects

### Q: What happens when user doesn't specify locale settings?

**A**: All fields optional, use platform defaults (no settings applied), ensures backward compatibility

### Q: How to discover KeyboardLayout ID values?

**A**: Manual discovery procedure: configure in System Preferences, then `defaults read com.apple.HIToolbox AppleSelectedInputSources`

### Q: Can we validate keyboard layouts at build time?

**A**: Partial - can validate against registry (known layouts), but can't verify layout actually exists on system until activation

______________________________________________________________________

## Implementation Checklist

- [ ] Create `platform/darwin/lib/keyboard-layout-translation.nix` with initial 10-layout registry
- [ ] Create `platform/darwin/settings/locale.nix` consuming user config (language, keyboard, timezone, regional)
- [ ] Update `platform/darwin/lib/darwin.nix` to pass full user config object via userContext
- [ ] Update `platform/darwin/settings/default.nix` to import locale.nix
- [ ] Refactor existing `platform/darwin/settings/keyboard.nix` to remove hardcoded locale settings (move to locale.nix)
- [ ] Add user config schema validation (optional fields, type checking)
- [ ] Discover KeyboardLayout IDs for all 10 initial layouts
- [ ] Test multi-user configurations with different locale settings
- [ ] Validate with `nix flake check` and `just build`
- [ ] Create user documentation in `docs/features/018-user-locale-config.md`

______________________________________________________________________

## References

- nix-darwin documentation: https://daiderd.com/nix-darwin/manual/
- IANA timezone database: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
- macOS defaults reference: https://macos-defaults.com/
- Current codebase: `platform/darwin/settings/keyboard.nix`
