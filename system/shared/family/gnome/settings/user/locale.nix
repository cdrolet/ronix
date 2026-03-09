# GNOME Family: Locale-Derived Settings
#
# Purpose: Configure GNOME desktop region/locale and app preferences
# Feature: 018-user-locale-config
#
# Sets:
# - GNOME region format (date, time, currency, measurements)
# - Temperature units for GNOME Weather
# Mirrors Darwin locale.nix logic for locale-to-unit derivation.
{
  config,
  lib,
  ...
}: let
  localeCfg = config.user.locale or {};
  hasFormat = localeCfg ? format && localeCfg.format != null;

  # Extract region code from locale (e.g., "en_CA.UTF-8" -> "CA")
  stripEncoding = locale: lib.removeSuffix ".UTF-8" locale;
  getRegion = locale: lib.last (lib.splitString "_" (stripEncoding locale));

  # Only US uses Fahrenheit
  fahrenheitRegions = ["US"];
  usesCelsius = locale: !(lib.elem (getRegion locale) fahrenheitRegions);

  # GWeather temperature-unit: "centigrade", "fahrenheit", or "default"
  tempUnit =
    if usesCelsius localeCfg.format
    then "centigrade"
    else "fahrenheit";
in {
  dconf.settings = {
    # Automatic timezone via geoclue2 (service enabled in settings/system/geolocation.nix)
    "org/gnome/desktop/datetime" = {
      automatic-timezone = lib.mkDefault true;
    };
  } // lib.optionalAttrs hasFormat {
    # GNOME region format (controls date/time/currency/measurement display in GNOME apps)
    # Without this, GNOME ignores the system i18n.defaultLocale for desktop apps
    "org/gnome/system/locale" = {
      region = lib.mkDefault localeCfg.format;
    };

    # GWeather temperature unit
    "org/gnome/GWeather4" = {
      temperature-unit = lib.mkDefault tempUnit;
    };
  };
}
