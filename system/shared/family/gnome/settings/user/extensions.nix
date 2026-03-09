# GNOME Family: Shell Extensions Registry
#
# Purpose: Single source of truth for enabled GNOME Shell extensions.
#          Individual extension modules (blur-my-shell.nix, dash-to-panel.nix)
#          install packages and configure settings but do NOT set enabled-extensions
#          to avoid dconf merge conflicts.
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
        # Blur + transparency for panel, overview, and app windows
        "blur-my-shell@aunetx"

        # Waybar-style bottom taskbar (replaces separate top bar + dock)
        "dash-to-panel@jderose9.github.com"

        # Shell theming support (required by Stylix for shell chrome colors)
        "user-theme@gnome-shell-extensions.gcampax.github.com"
      ];

      # Disable the vanilla dock (dash-to-panel replaces it)
      disabled-extensions = lib.mkDefault [
        "dash-to-dock@micxgx.gmail.com"
      ];
    };
  };
}
