# Locale Configuration (System-Level)
#
# Purpose: Configure timezone and locale from user configuration
# Feature: 025-nixos-settings-modules, 036-standalone-home-manager, 039-segregate-settings
#
# Equivalent Darwin settings: locale.nix (timezone, languages, locale)
#
# All locale fields are optional - system uses platform defaults when not specified.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Access locale config from user schema
  localeCfg = config.user.locale or {};

  # Check which locale fields are specified by user
  hasTimezone = localeCfg ? timezone && localeCfg.timezone != null;
  hasFormat = localeCfg ? format && localeCfg.format != null;
in {
  # ============================================================================
  # Timezone Configuration
  # ============================================================================
  # Uses top-level time.timeZone option (cross-platform with Darwin)
  # IANA timezone identifier (e.g., "America/Toronto", "Europe/Paris")

  time.timeZone = lib.mkIf hasTimezone (lib.mkDefault localeCfg.timezone);

  # ============================================================================
  # System Locale Configuration
  # ============================================================================
  # Sets default locale for the system
  # POSIX locale format: language_REGION.ENCODING (e.g., "en_CA.UTF-8")

  i18n.defaultLocale = lib.mkIf hasFormat (lib.mkDefault localeCfg.format);

  # ============================================================================
  # Extra Locale Settings
  # ============================================================================
  # Fine-grained locale categories for time, currency, measurements

  i18n.extraLocaleSettings = lib.mkIf hasFormat {
    LC_TIME = lib.mkDefault localeCfg.format;
    LC_MONETARY = lib.mkDefault localeCfg.format;
    LC_MEASUREMENT = lib.mkDefault localeCfg.format;
    LC_PAPER = lib.mkDefault localeCfg.format;
  };
}
