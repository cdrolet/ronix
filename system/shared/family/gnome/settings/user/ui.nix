# GNOME Family: UI Settings
#
# Purpose: Configure GNOME desktop appearance via dconf and GTK
# Feature: 025-nixos-settings-modules
#
# Settings include:
# - Color scheme (dark mode)
# - GTK theme preferences
# - Font rendering
# - Animation preferences
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ============================================================================
  # GTK Theme Settings
  # ============================================================================

  # GTK theme configuration for consistent appearance across GTK3 and GTK4 apps
  # Note: We use dconf color-scheme instead of gtk-application-prefer-dark-theme
  # to avoid warnings with libadwaita apps (like Ghostty)
  gtk = {
    enable = true;
  };

  # ============================================================================
  # Desktop Interface Settings
  # ============================================================================

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      # Dark mode
      color-scheme = lib.mkDefault "prefer-dark";

      # Font rendering for crisp text
      font-antialiasing = lib.mkDefault "rgba";
      font-hinting = lib.mkDefault "slight";

      # Enable animations (set to false for better performance)
      enable-animations = lib.mkDefault true;

      # Clock format (24-hour)
      clock-format = lib.mkDefault "24h";
      clock-show-weekday = lib.mkDefault true;
    };
  };
}
