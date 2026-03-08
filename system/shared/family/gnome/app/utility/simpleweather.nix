# SimpleWeather - Weather in GNOME Shell top bar
#
# Purpose: Display current temperature and conditions in the top panel
# Platform: GNOME desktop environments
#
# Shows weather for your current location (auto-detected via IP).
# Temperature and speed units derived from user.locale.format when available.
#
# Extension: https://extensions.gnome.org/extension/8261/simpleweather/
{
  config,
  pkgs,
  lib,
  ...
}: let
  extensionUuid = "simple-weather@romanlefler.com";

  localeCfg = config.user.locale or {};
  hasFormat = localeCfg ? format && localeCfg.format != null;

  # Extract region code from locale (e.g., "en_CA.UTF-8" -> "CA")
  stripEncoding = locale: lib.removeSuffix ".UTF-8" locale;
  getRegion = locale: lib.last (lib.splitString "_" (stripEncoding locale));

  # Only US uses Fahrenheit / imperial
  fahrenheitRegions = ["US"];
  isMetricRegion = locale: !(lib.elem (getRegion locale) fahrenheitRegions);
in {
  home.packages = [pkgs.gnomeExtensions.simpleweather];

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = lib.mkDefault [extensionUuid];
    };

    "org/gnome/shell/extensions/simple-weather" = lib.mkIf hasFormat (
      if isMetricRegion localeCfg.format
      then {
        unit-preset = lib.mkDefault "metric";
        temp-unit = lib.mkDefault "celsius";
        speed-unit = lib.mkDefault "kph";
        distance-unit = lib.mkDefault "km";
        pressure-unit = lib.mkDefault "hPa";
        rain-measurement-unit = lib.mkDefault "mm";
      }
      else {
        unit-preset = lib.mkDefault "us";
        temp-unit = lib.mkDefault "fahrenheit";
        speed-unit = lib.mkDefault "mph";
        distance-unit = lib.mkDefault "miles";
        pressure-unit = lib.mkDefault "inHg";
        rain-measurement-unit = lib.mkDefault "in";
      }
    );
  };
}
