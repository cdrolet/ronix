# NixOS System-Level Settings
#
# Purpose: Auto-discover and import all system-level nixos settings
# Context: System build (nixos-rebuild) - no home-manager access
# Feature: 039-segregate-settings-directories
#
# These settings modify system-level state and require system rebuild to apply.
# They have NO access to home-manager options (no `home.*` available).
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
