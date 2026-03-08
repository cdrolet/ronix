# Keyboard Settings
#
# Purpose: Configure system-wide keyboard behavior and layouts
# Feature: 018-user-locale-config (keyboard layouts from user config)
#
# Note:
#   - Application-specific keyboard shortcuts belong in their respective modules
#   - Language and locale settings are configured in locale.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Import keyboard layout translation registry
  layoutRegistry = import ../../lib/keyboard-layout-translation.nix;

  # Helper: Get primary user from system config
  primaryUser = config.system.primaryUser or null;

  # Helper: Access locale config from user schema
  localeCfg = config.user.locale or {};

  # Check if keyboard layout is specified by user
  keyboardConfig = localeCfg.keyboard or null;
  keyboardLayout =
    if keyboardConfig != null
    then (keyboardConfig.layout or null)
    else null;
  hasKeyboardLayout = keyboardLayout != null && keyboardLayout != [];

  # Helper: Translate platform-agnostic keyboard layout name to darwin layout object
  translateLayout = layoutName: let
    layout = layoutRegistry.darwin.${layoutName} or null;
  in
    if layout == null
    then
      throw ''
        Unknown keyboard layout: '${layoutName}'

        Available layouts: ${lib.concatStringsSep ", " (lib.attrNames layoutRegistry.darwin)}

        To add a new layout:
        1. Open System Preferences → Keyboard → Input Sources
        2. Add the desired layout
        3. Run: defaults read com.apple.HIToolbox AppleSelectedInputSources
        4. Extract the KeyboardLayout ID
        5. Update system/darwin/lib/keyboard-layout-translation.nix
      ''
    else if layout.id == null
    then
      throw ''
        Keyboard layout '${layoutName}' has not been fully configured (ID is null).

        Discovery procedure:
        1. Open System Preferences → Keyboard → Input Sources
        2. Add the '${layout.name}' layout
        3. Run: defaults read com.apple.HIToolbox AppleSelectedInputSources
        4. Find the entry for '${layout.name}' and note the KeyboardLayout ID
        5. Update system/darwin/lib/keyboard-layout-translation.nix:
           ${layoutName} = { id = <discovered-id>; name = "${layout.name}"; };
      ''
    else {
      InputSourceKind = "Keyboard Layout";
      "KeyboardLayout ID" = layout.id;
      "KeyboardLayout Name" = layout.name;
    };
in {
  # ============================================================================
  # Keyboard Behavior
  # ============================================================================

  system.defaults.NSGlobalDomain = {
    # Keyboard repeat settings (system-wide)
    KeyRepeat = lib.mkDefault 2; # Fast repeat rate
    InitialKeyRepeat = lib.mkDefault 10; # Moderate delay

    # Keyboard behavior
    ApplePressAndHoldEnabled = lib.mkDefault false; # Disable press-and-hold for key repeat
    AppleKeyboardUIMode = lib.mkDefault 3; # Full keyboard access for controls
  };

  # ============================================================================
  # Keyboard Layout Configuration
  # ============================================================================
  # Sets available keyboard layouts using platform-agnostic names
  # Layouts are translated to darwin-specific identifiers via translation layer

  system.defaults.CustomUserPreferences."com.apple.HIToolbox" = lib.mkIf hasKeyboardLayout {
    AppleSelectedInputSources = lib.mkDefault (
      map translateLayout keyboardLayout
    );
  };
}
