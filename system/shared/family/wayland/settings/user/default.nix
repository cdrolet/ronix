# Linux Family User-Level Settings
#
# Purpose: Auto-discover and import all Linux user-level settings
# Context: Home-manager activation - has home-manager access
# Feature: 039-segregate-settings-directories
#
# These settings are shared across Linux distributions for user environment.
# They have access to home-manager options (home.*, dconf.*, etc.).
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
