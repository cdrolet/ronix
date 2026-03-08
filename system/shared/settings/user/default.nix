# Shared User-Level Settings
#
# Purpose: Auto-discover and import all cross-platform user-level settings
# Context: Home-manager activation - has home-manager access
# Feature: 039-segregate-settings-directories
#
# These settings are cross-platform and modify user environment.
# They have access to home-manager options (home.*, dconf.*, etc.).
{
  config,
  lib,
  pkgs,
  ...
}: let
  discovery = import ../../lib/discovery.nix {inherit lib;};
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
