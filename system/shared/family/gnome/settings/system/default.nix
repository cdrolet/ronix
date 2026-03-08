# GNOME Family System-Level Settings
#
# Purpose: Auto-discover and import all GNOME system-level settings
# Context: System build (nixos-rebuild) - no home-manager access
# Feature: 039-segregate-settings-directories
#
# These settings install GNOME desktop components and require system rebuild.
# They have NO access to home-manager options (no `home.*` available).
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
