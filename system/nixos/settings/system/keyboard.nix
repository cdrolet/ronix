# NixOS Keyboard Settings (System-Level)
#
# Purpose: Configure keyboard repeat rate, layout, and Mac-style modifier remapping
# Feature: 025-nixos-settings-modules, 044-keyboard-config-restructure
#
# Equivalent Darwin settings: system/darwin/settings/system/keyboard.nix
#
# This module:
# 1. Sets keyboard repeat rate (delay and interval)
# 2. Sets keyboard layout from user.locale.keyboard.layout
# 3. Conditionally swaps Super/Ctrl keys based on user.locale.keyboard.macStyleMappings
#
# Mac-style remapping makes Linux keyboard behavior consistent with macOS:
# - Left Super (Win) -> Left Ctrl (for Ctrl+C, Ctrl+V, etc.)
# - Left Ctrl -> Left Super (for desktop switching, etc.)
# - Right Super (Win) -> Right Ctrl
# - Right Ctrl -> Right Super
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Access locale config from user schema
  localeCfg = config.user.locale or {};
  keyboardConfig = localeCfg.keyboard or null;
  userKeyboardLayout =
    if keyboardConfig != null
    then (keyboardConfig.layout or null)
    else null;
  hasKeyboardLayout = userKeyboardLayout != null && userKeyboardLayout != [];

  # Mac-style modifier remapping (default: true)
  macStyleMappings =
    if keyboardConfig != null
    then (keyboardConfig.macStyleMappings or true)
    else true;

  # Convert keyboard layout names to XKB layout and variant codes
  # XKB uses separate fields for layout and variant
  # Note: ca (base) = French Canadian, ca(eng) = English Canadian
  layoutMap = {
    "canadian-english" = {
      layout = "ca";
      variant = "eng";
    };
    "canadian-french" = {
      layout = "ca";
      variant = "fr";
    };
    "us" = {
      layout = "us";
      variant = "";
    };
    "uk" = {
      layout = "gb";
      variant = "";
    };
  };

  # Convert all layouts from user config to XKB format
  xkbMappings =
    if hasKeyboardLayout
    then
      map (name:
        layoutMap.${
          name
        } or {
          layout = "us";
          variant = "";
        })
      userKeyboardLayout
    else [
      {
        layout = "us";
        variant = "";
      }
    ];

  # Extract layouts and variants (comma-separated for multiple layouts)
  xkbLayouts = map (m: m.layout) xkbMappings;
  xkbVariants = map (m: m.variant) xkbMappings;

  xkbLayout = lib.concatStringsSep "," xkbLayouts;
  xkbVariant = lib.concatStringsSep "," xkbVariants;
in {
  # ============================================================================
  # X11 Keyboard Repeat Settings
  # ============================================================================
  # Controls how fast keys repeat when held down
  #
  # Darwin equivalents:
  #   InitialKeyRepeat = 10 -> autoRepeatDelay = 200ms
  #   KeyRepeat = 2 -> autoRepeatInterval = 25ms

  services.xserver = {
    autoRepeatDelay = lib.mkDefault 200; # Delay before repeat starts (ms)
    autoRepeatInterval = lib.mkDefault 25; # Interval between repeats (ms)
  };

  # ============================================================================
  # XKB Layout Configuration
  # ============================================================================
  # Set keyboard layout and variants from user configuration
  # Multiple layouts are comma-separated (e.g., "ca,ca" with variants ",fr")

  services.xserver.xkb.layout = lib.mkIf hasKeyboardLayout (lib.mkDefault xkbLayout);
  services.xserver.xkb.variant = lib.mkIf hasKeyboardLayout (lib.mkDefault xkbVariant);

  # ============================================================================
  # XKB Modifier Remapping (conditional on keyboard.macStyleMappings)
  # ============================================================================
  # When macStyleMappings = true, swaps Super and Ctrl keys:
  #   ctrl:swap_lwin_lctl - Swap Left Win (Super) with Left Ctrl
  #   ctrl:swap_rwin_rctl - Swap Right Win (Super) with Right Ctrl
  # When macStyleMappings = false, no modifier swap is applied.

  services.xserver.xkb.options = lib.mkDefault (
    if macStyleMappings
    then
      lib.concatStringsSep "," [
        "ctrl:swap_lwin_lctl"
        "ctrl:swap_rwin_rctl"
      ]
    else ""
  );

  # ============================================================================
  # Console Keyboard
  # ============================================================================
  # Apply X keyboard configuration to the Linux console (TTY)

  console.useXkbConfig = lib.mkDefault true;
}
