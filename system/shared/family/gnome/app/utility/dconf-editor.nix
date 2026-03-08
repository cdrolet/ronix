# dconf Editor - Low-level GNOME configuration editor
#
# Direct access to GNOME's configuration database (dconf)
# Features: Browse and edit all GNOME settings, advanced configuration
#
# Platform: GNOME desktop environments
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.dconf-editor];
}
