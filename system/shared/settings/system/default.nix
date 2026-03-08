# Shared System-Level Settings
#
# Purpose: Auto-discover and import all cross-platform system-level settings
# Context: System build (darwin-rebuild/nixos-rebuild) - no home-manager access
# Feature: 039-segregate-settings-directories
#
# These settings are cross-platform and modify system-level state.
# They have NO access to home-manager options (no `home.*` available).
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
