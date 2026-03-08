# GNOME Tweaks - GNOME customization tool
#
# Advanced configuration tool for GNOME desktop
# Features: Theme customization, extensions management, window behavior
#
# Platform: GNOME desktop environments
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.gnome-tweaks];
}
