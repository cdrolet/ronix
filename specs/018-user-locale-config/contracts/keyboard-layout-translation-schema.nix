# Keyboard Layout Translation Registry Schema
# Feature: 018-user-locale-config
#
# This file defines the structure for the keyboard layout translation registry.
# The registry maps platform-agnostic keyboard layout names to platform-specific
# identifiers and metadata.
{lib, ...}: {
  # Keyboard layout entry type for darwin platform
  darwinKeyboardLayoutType = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.unsigned;
        description = lib.mdDoc ''
          macOS KeyboardLayout ID number.

          This is the integer identifier used by macOS to reference keyboard layouts.
          IDs can be discovered by manually configuring the layout in System Preferences
          and then running:

          ```bash
          defaults read com.apple.HIToolbox AppleSelectedInputSources
          ```

          A value of `null` indicates the ID has not yet been discovered and needs
          to be determined through the discovery procedure.
        '';
        example = 0;
      };

      name = lib.mkOption {
        type = lib.types.str;
        description = lib.mdDoc ''
          macOS keyboard layout display name.

          This is the human-readable name that appears in System Preferences.
          The name must match exactly what macOS expects for the layout to be
          properly configured.

          Common names:
          - "U.S." - U.S. layout
          - "Canadian" - Canadian English
          - "Canadian-CSA" - Canadian French (CSA standard)
          - "British" - UK layout
          - "Dvorak" - Dvorak layout
          - "Colemak" - Colemak layout
        '';
        example = "U.S.";
      };
    };
  };

  # Complete keyboard layout translation registry type
  keyboardLayoutRegistryType = lib.types.submodule {
    options = {
      darwin = lib.mkOption {
        type = lib.types.attrsOf darwinKeyboardLayoutType;
        description = lib.mdDoc ''
          Darwin (macOS) keyboard layout mappings.

          Maps platform-agnostic keyboard layout names to darwin-specific
          layout objects containing the KeyboardLayout ID and display name.

          Platform-agnostic names should be:
          - Lowercase
          - Kebab-case (words separated by hyphens)
          - Descriptive and intuitive
          - Consistent across platforms when possible
        '';
        example = {
          us = {
            id = 0;
            name = "U.S.";
          };
          canadian = {
            id = 29;
            name = "Canadian";
          };
          dvorak = {
            id = null;
            name = "Dvorak";
          };
        };
      };

      # Future platforms can be added here:
      # nixos = lib.mkOption { ... };
      # linux = lib.mkOption { ... };
    };
  };
}
