# GNOME Family: Shell Extensions Registry
#
# Purpose: Single source of truth for enabled GNOME Shell extensions.
#          Individual extension modules install packages and configure settings
#          but do NOT set enabled-extensions to avoid dconf merge conflicts.
#          This file uses normal priority (overrides Stylix's lib.mkDefault).
#
# To add an extension: add its UUID to the list below and create a matching
# <extension-name>.nix file for its settings.
{
  lib,
  ...
}: {
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        # Shell theming support (required by Stylix for shell chrome colors)
        "user-theme@gnome-shell-extensions.gcampax.github.com"

        # Keyboard navigation between windows in Activities overview
        "windownavigator@gnome-shell-extensions.gcampax.github.com"

        # Adjustable top bar transparency (opacity from user.style.theme.opacity.applications)
        "transparent-top-bar@ftpix.com"

        # Weather in top panel (configured in settings/user/weather.nix)
        "simple-weather@romanlefler.com"
      ];
    };
  };
}
