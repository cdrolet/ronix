# GNOME Family: Keyboard Settings
#
# Purpose: Configure GNOME keyboard shortcuts and input sources via dconf
# Feature: 025-nixos-settings-modules
#
# Settings include:
# - Window management shortcuts
# - Application switching
# - Input source configuration
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ============================================================================
  # Window Management Keybindings
  # ============================================================================

  dconf.settings = {
    # ============================================================================
    # Input Sources (Keyboard Layouts)
    # ============================================================================
    # Configure keyboard layouts from user.locale.keyboard.layout
    # Uses XKB identifiers: ('xkb', 'layout') or ('xkb', 'layout+variant')

    "org/gnome/desktop/input-sources" = let
      # Convert user keyboard layouts to GNOME input source tuples
      # Each source is a tuple of (type, identifier)
      # Note: ca (base) = French Canadian, ca+eng = English Canadian
      layoutMap = {
        "canadian-english" = {
          type = "xkb";
          id = "ca+eng";
        };
        "canadian-french" = {
          type = "xkb";
          id = "ca";
        }; # Base ca layout is French Canadian
        "us" = {
          type = "xkb";
          id = "us";
        };
        "uk" = {
          type = "xkb";
          id = "gb";
        };
      };

      keyboardConfig = (config.user.locale or {}).keyboard or null;
      userLayouts =
        if keyboardConfig != null
        then (keyboardConfig.layout or [])
        else [];
      hasLayouts = userLayouts != null && userLayouts != [];
      macStyleMappings =
        if keyboardConfig != null
        then (keyboardConfig.macStyleMappings or true)
        else true;

      # Convert to GNOME input source tuples
      # For dconf, just use a list of tuples directly
      inputSources =
        if hasLayouts
        then
          map (name: let
            mapping =
              layoutMap.${
                name
              } or {
                type = "xkb";
                id = "us";
              };
          in
            lib.hm.gvariant.mkTuple [mapping.type mapping.id])
          userLayouts
        else [lib.hm.gvariant.mkTuple ["xkb" "us"]];
    in
      lib.mkIf hasLayouts {
        sources = inputSources;

        # Apply XKB options through GNOME (GNOME overrides system xkb.options)
        # Must be set here or GNOME resets them to empty
        # Conditional on keyboard.macStyleMappings
        xkb-options = lib.mkDefault (
          if macStyleMappings
          then [
            "ctrl:swap_lwin_lctl"
            "ctrl:swap_rwin_rctl"
          ]
          else []
        );
      };

    "org/gnome/desktop/wm/keybindings" = {
      # Close window (Super+Q like macOS Cmd+Q)
      close = lib.mkDefault ["<Super>q"];

      # Minimize window
      minimize = lib.mkDefault ["<Super>m"];

      # Toggle maximize
      toggle-maximized = lib.mkDefault ["<Super>Up"];

      # Application switching (Super+Tab like macOS Cmd+Tab)
      switch-applications = lib.mkDefault ["<Super>Tab"];
      switch-applications-backward = lib.mkDefault ["<Shift><Super>Tab"];

      # Window switching within application
      switch-windows = lib.mkDefault ["<Alt>Tab"];
      switch-windows-backward = lib.mkDefault ["<Shift><Alt>Tab"];
    };

    # ============================================================================
    # Workspace Navigation
    # ============================================================================

    "org/gnome/desktop/wm/keybindings" = {
      # Workspace switching
      switch-to-workspace-left = lib.mkDefault ["<Super>Left"];
      switch-to-workspace-right = lib.mkDefault ["<Super>Right"];
    };

    # ============================================================================
    # Shell Keybindings
    # ============================================================================

    "org/gnome/shell/keybindings" = {
      # Toggle overview (like macOS Mission Control)
      toggle-overview = lib.mkDefault ["<Super>space"];
    };
  };
}
