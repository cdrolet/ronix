# User Locale Configuration Schema
# Feature: 018-user-locale-config
#
# This file defines the Nix module type schema for user locale configuration fields.
# These types are used to validate user configuration at build time.
{lib, ...}: {
  # User configuration options (to be added to user config schema)
  options.user = {
    # Existing fields (for reference, not defined here)
    # name = lib.mkOption { type = lib.types.str; ... };
    # email = lib.mkOption { type = lib.types.str; ... };
    # fullName = lib.mkOption { type = lib.types.str; ... };

    # New locale configuration fields

    languages = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = lib.mdDoc ''
        Ordered list of preferred languages in ISO 639-1 + ISO 3166-1 format.
        The first language in the list is the primary language, subsequent languages
        are fallback languages.

        Common language codes:
        - "en-US" - English (United States)
        - "en-CA" - English (Canada)
        - "en-GB" - English (United Kingdom)
        - "fr-CA" - French (Canada)
        - "fr-FR" - French (France)
        - "de" - German
        - "es" - Spanish
        - "it" - Italian
        - "pt" - Portuguese
        - "ja" - Japanese
        - "zh-CN" - Chinese (Simplified)

        When not specified, platform defaults are used.
      '';
      example = ["en-CA" "fr-CA"];
    };

    keyboardLayout = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = lib.mdDoc ''
        Ordered list of keyboard layouts using platform-agnostic names.
        The first layout in the list is the default layout, subsequent layouts
        are available for switching.

        Platform-agnostic keyboard layout names are translated to platform-specific
        identifiers by the platform's locale configuration module.

        Supported layouts (initial implementation):
        - "us" - U.S. QWERTY
        - "canadian" - Canadian English
        - "canadian-french" - Canadian French (CSA)
        - "british" - UK layout
        - "dvorak" - Dvorak
        - "colemak" - Colemak
        - "french" - French AZERTY
        - "german" - German QWERTZ
        - "spanish" - Spanish
        - "brazilian" - Brazilian Portuguese

        Additional layouts can be added to the platform's keyboard layout
        translation registry as needed.

        When not specified, platform defaults are used.
      '';
      example = ["us" "canadian-french"];
    };

    timezone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = lib.mdDoc ''
        IANA timezone identifier for the user's timezone.

        Common timezones:
        - "America/Toronto" - Eastern Time (Canada/US East)
        - "America/Vancouver" - Pacific Time (Canada/US West)
        - "America/Chicago" - Central Time (US)
        - "America/New_York" - Eastern Time (US)
        - "America/Los_Angeles" - Pacific Time (US)
        - "Europe/London" - GMT/BST
        - "Europe/Paris" - CET/CEST
        - "Asia/Tokyo" - JST
        - "Australia/Sydney" - AEST/AEDT

        See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
        for a complete list of valid timezone identifiers.

        When not specified, platform defaults are used.
      '';
      example = "America/Toronto";
    };

    locale = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = lib.mdDoc ''
        POSIX locale identifier for regional settings including date format,
        time format, number format, measurement units, and currency.

        Format: language_REGION[.encoding][@modifier]

        Common locales:
        - "en_CA.UTF-8" - English (Canada) - metric, CAD currency, YYYY-MM-DD dates
        - "en_US.UTF-8" - English (US) - imperial, USD currency, MM/DD/YYYY dates
        - "en_GB.UTF-8" - English (UK) - metric, GBP currency, DD/MM/YYYY dates
        - "fr_CA.UTF-8" - French (Canada) - metric, CAD currency, French formatting
        - "fr_FR.UTF-8" - French (France) - metric, EUR currency, French formatting
        - "de_DE.UTF-8" - German (Germany) - metric, EUR currency, German formatting
        - "es_ES.UTF-8" - Spanish (Spain) - metric, EUR currency, Spanish formatting

        The locale setting is independent of the languages setting, allowing
        users to have UI in one language while using regional formatting from
        another locale (e.g., English UI with Canadian date/number formatting).

        When not specified, platform defaults are used.
      '';
      example = "en_CA.UTF-8";
    };
  };
}
