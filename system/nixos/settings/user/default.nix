# NixOS User-Level Settings
#
# Purpose: Auto-discover and import all user-level nixos settings
# Context: Home-manager activation - has home-manager access
# Feature: 039-segregate-settings-directories
#
# These settings modify user environment and apply during home-manager activation.
# They have access to home-manager options (home.*, dconf.*, etc.).
{
  config,
  lib,
  pkgs,
  ...
}: let
  discovery = import ../../../shared/lib/discovery.nix {inherit lib;};
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
