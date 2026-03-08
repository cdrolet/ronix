# Keyboard Layout Translation Registry
# Feature: 018-user-locale-config
#
# Maps platform-agnostic keyboard layout names to darwin-specific identifiers.
# This enables cross-platform user configurations while maintaining platform-specific
# implementation details in the platform library.
#
# VALIDATION:
# ===========
# This translation registry MUST:
# 1. Provide translations for ALL layouts defined in system/shared/lib/keyboard-layouts.nix
# 2. NOT define translations for layouts not in the shared registry
# 3. Validation is enforced at build time by system/darwin/settings/locale.nix
#
# DISCOVERY PROCEDURE for missing KeyboardLayout IDs:
# ===================================================
#
# 1. Open System Preferences → Keyboard → Input Sources
# 2. Click the [+] button to add a new input source
# 3. Find and add the desired keyboard layout
# 4. Open Terminal and run:
#    defaults read com.apple.HIToolbox AppleSelectedInputSources
# 5. Find the entry for your layout in the output:
#    {
#        InputSourceKind = "Keyboard Layout";
#        "KeyboardLayout ID" = 16300;
#        "KeyboardLayout Name" = Dvorak;
#    }
# 6. Note the "KeyboardLayout ID" value
# 7. Update this file with the discovered ID
# 8. Rebuild your configuration to test
#
# NOTE: Layout names in this registry match the platform-agnostic names from
# system/shared/lib/keyboard-layouts.nix (lowercase, kebab-case), while macOS
# uses specific names. The translation layer handles this mapping.
let
  # Import shared keyboard layout registry
  sharedLayouts = import ../../shared/lib/keyboard-layouts.nix;

  # Darwin-specific translations
  darwinTranslations = {
    us = {
      id = 0;
      name = "U.S.";
    };

    canadian-english = {
      id = 29;
      name = "Canadian";
    };

    canadian-french = {
      id = 80;
      name = "Canadian-CSA";
    };
  };

  # Validation: Check all shared layouts have translations
  sharedLayoutNames = builtins.attrNames sharedLayouts.layouts;
  translatedLayoutNames = builtins.attrNames darwinTranslations;

  missingTranslations =
    builtins.filter
    (layout: !(builtins.elem layout translatedLayoutNames))
    sharedLayoutNames;

  # Validation: Check no unknown layouts in translations
  unknownTranslations =
    builtins.filter
    (layout: !(builtins.elem layout sharedLayoutNames))
    translatedLayoutNames;

  # Generate validation errors if needed
  validationErrors =
    (
      if missingTranslations != []
      then ["Missing darwin translations for shared layouts: ${builtins.concatStringsSep ", " missingTranslations}"]
      else []
    )
    ++ (
      if unknownTranslations != []
      then ["Darwin translations defined for unknown layouts (not in shared registry): ${builtins.concatStringsSep ", " unknownTranslations}"]
      else []
    );

  # Throw error if validation fails
  validated =
    if validationErrors != []
    then
      throw ''
        Keyboard layout translation validation failed:
        ${builtins.concatStringsSep "\n" validationErrors}

        Shared layouts defined in system/shared/lib/keyboard-layouts.nix: ${builtins.concatStringsSep ", " sharedLayoutNames}
        Darwin translations defined: ${builtins.concatStringsSep ", " translatedLayoutNames}
      ''
    else darwinTranslations;
in {
  darwin = validated;
}
