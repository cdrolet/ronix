# GNOME Family User-Level Settings
#
# Purpose: Auto-discover and import all GNOME user-level settings
# Context: Home-manager activation - has home-manager access
# Feature: 039-segregate-settings-directories
#
# These settings configure GNOME user preferences (dconf, GTK, themes).
# They have access to home-manager options (home.*, dconf.*, gtk.*, etc.).
{
  config,
  lib,
  pkgs,
  ...
}: let
  discovery = import ../../../../lib/discovery.nix {inherit lib;};
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
