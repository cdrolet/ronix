# GNOME Global Keyboard Shortcuts
#
# Purpose: Configure global keyboard shortcuts for GNOME Shell
# User-level configuration (dconf settings via home-manager)
#
# This module sets up keyboard shortcuts for quick access to GNOME features:
# - Ctrl+Alt+Space: Open Activities Overview (application launcher)
#
# Platform: Cross-platform (home-manager dconf.settings)
# Works on any Linux distribution with GNOME
#
# Dependencies:
# - GNOME desktop environment (from desktop/gnome-core.nix)
# - home-manager dconf module
#
# Constitutional: <200 lines, uses lib.mkDefault
#
# Usage:
# Automatically imported when host declares family = ["gnome"]
# Shortcuts configured at user-level (each user can override)
#
# To override shortcuts in user config:
# {
#   dconf.settings."org/gnome/shell/keybindings".toggle-overview = lib.mkForce ["<Super>space"];
# }
#
# Keybinding syntax:
# - <Ctrl> = Control key
# - <Alt> = Alt key
# - <Super> = Windows/Command key
# - <Shift> = Shift key
# - Multiple modifiers: <Ctrl><Alt>space
#
# GNOME Shell keybinding schemas:
# - org.gnome.shell.keybindings: Shell features (overview, screenshots, notifications)
# - org.gnome.desktop.wm.keybindings: Window manager (close, minimize, maximize)
#
# Reference:
# - Activities Overview: Main GNOME launcher/search interface
# - Accessed via Super key or configured shortcut
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Configure GNOME Shell keybindings (user-level dconf settings)
  dconf.settings = {
    "org/gnome/shell/keybindings" = {
      # Ctrl+Alt+Space to open Activities Overview (application launcher)
      # This provides quick access to search, launch apps, switch windows
      toggle-overview = lib.mkDefault ["<Ctrl><Alt>space"];
    };
  };
}
