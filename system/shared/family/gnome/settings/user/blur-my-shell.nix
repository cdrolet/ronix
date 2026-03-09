# GNOME Family: Blur my Shell Extension
#
# Purpose: Add blur and transparency effects to GNOME Shell panels, overview,
#          and app windows. Maps stylix opacity.applications to panel brightness.
# Extension UUID: blur-my-shell@aunetx
# Note: Extension must be listed in extensions.nix enabled-extensions
{
  config,
  lib,
  pkgs,
  ...
}: let
  appOpacity = (config.user.style or {}).opacity.applications or 0.9;
in {
  home.packages = [ pkgs.gnomeExtensions.blur-my-shell ];

  dconf.settings = {
    # Panel (top bar) blur
    "org/gnome/shell/extensions/blur-my-shell/panel" = {
      blur = lib.mkDefault true;
      sigma = lib.mkDefault 20;
      brightness = lib.mkDefault appOpacity;
    };

    # Activities overview blur
    "org/gnome/shell/extensions/blur-my-shell/overview" = {
      blur = lib.mkDefault true;
      sigma = lib.mkDefault 30;
      brightness = lib.mkDefault 0.6;
    };

    # Application windows blur (overview only — avoids readability issues)
    "org/gnome/shell/extensions/blur-my-shell/applications" = {
      blur = lib.mkDefault true;
      sigma = lib.mkDefault 10;
      brightness = lib.mkDefault appOpacity;
      blur-on-overview = lib.mkDefault true;
    };
  };
}
