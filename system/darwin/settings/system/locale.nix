# Locale Configuration
# Feature: 018-user-locale-config
#
# Purpose: Configure system locale preferences from user configuration
# - Languages: System UI language preferences
# - Timezone: System timezone (IANA identifier)
# - Regional Locale: Date/time/number format, measurements, currency
#
# Note: Keyboard layouts are configured in keyboard.nix
#
# All locale fields are optional - system uses platform defaults when not specified.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Helper: Get primary user from system config
  primaryUser = config.system.primaryUser or null;

  # Helper: Access locale config from user schema
  localeCfg = config.user.locale or {};

  # Check which locale fields are specified by user
  hasLanguages = localeCfg ? languages && localeCfg.languages != [] && localeCfg.languages != null;
  hasTimezone = localeCfg ? timezone && localeCfg.timezone != null;
  hasFormat = localeCfg ? format && localeCfg.format != null;

  # Helper: Strip .UTF-8 suffix from locale for macOS
  stripEncoding = locale: lib.removeSuffix ".UTF-8" locale;

  # Helper: Extract region code from locale (e.g., "en_CA" -> "CA")
  getRegion = locale: lib.last (lib.splitString "_" (stripEncoding locale));

  # Regions that use imperial measurements (US, Liberia, Myanmar)
  imperialRegions = ["US" "LR" "MM"];

  # Regions that use Fahrenheit (US and some territories)
  fahrenheitRegions = ["US"];

  # Regions that typically use 12-hour time format
  twelveHourRegions = ["US" "CA" "AU" "PH"];

  # Helper: Determine if locale uses metric or imperial measurements
  isMetric = locale: !(lib.elem (getRegion locale) imperialRegions);

  # Helper: Determine if locale uses Celsius
  usesCelsius = locale: !(lib.elem (getRegion locale) fahrenheitRegions);

  # Helper: Determine if locale uses 24-hour time
  uses24Hour = locale: !(lib.elem (getRegion locale) twelveHourRegions);
in {
  # ============================================================================
  # Timezone Configuration
  # ============================================================================
  # Uses top-level time.timeZone option (cross-platform with NixOS)
  # IANA timezone identifier (e.g., "America/Toronto", "Europe/Paris")

  time.timeZone = lib.mkIf hasTimezone (lib.mkDefault localeCfg.timezone);

  # ============================================================================
  # Language Configuration
  # ============================================================================
  # Sets system UI language and fallback languages
  # First language in array is primary, subsequent are fallbacks

  # Use "NSGlobalDomain" not "Apple Global Domain" — nix-darwin doesn't
  # shell-escape the domain parameter, so spaces break the defaults command.
  system.defaults.CustomUserPreferences."NSGlobalDomain" = lib.mkMerge [
    (lib.mkIf hasLanguages {
      AppleLanguages = lib.mkDefault localeCfg.languages;
    })

    # ============================================================================
    # Regional Locale Configuration
    # ============================================================================
    # Sets date/time/number format, currency display
    # POSIX locale format: language_REGION (e.g., "en_CA", "fr_CA")

    (lib.mkIf hasFormat {
      AppleLocale = lib.mkDefault (stripEncoding localeCfg.format);
    })
  ];

  # ============================================================================
  # Regional Settings (derived from locale)
  # ============================================================================
  # Measurement units and temperature scale based on locale region

  system.defaults.NSGlobalDomain = lib.mkIf hasFormat {
    # Measurement units: Centimeters (metric) or Inches (imperial)
    AppleMeasurementUnits = lib.mkDefault (
      if isMetric localeCfg.format
      then "Centimeters"
      else "Inches"
    );

    # Metric units: 1 (metric) or 0 (imperial)
    AppleMetricUnits = lib.mkDefault (
      if isMetric localeCfg.format
      then 1
      else 0
    );

    # Temperature unit: Celsius or Fahrenheit
    AppleTemperatureUnit = lib.mkDefault (
      if usesCelsius localeCfg.format
      then "Celsius"
      else "Fahrenheit"
    );

    # Time format: 1 (24-hour) or 0 (12-hour)
    AppleICUForce24HourTime = lib.mkDefault (uses24Hour localeCfg.format);
  };
}
