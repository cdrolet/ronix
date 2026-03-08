# Context Schema
#
# Purpose: Define the _configContext option for build context detection
# Usage: Import this in all configuration entry points (darwin.nix, nixos.nix, home-manager.nix)
#
# This option is set by the platform libraries to indicate which build stage we're in:
# - "darwin-system": nix-darwin system build (Stage 1)
# - "nixos-system": NixOS system build (Stage 1)
# - "home-manager": Standalone home-manager build (Stage 2)
{lib, ...}: {
  options._configContext = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [
      "darwin-system"
      "nixos-system"
      "home-manager"
    ]);
    default = null;
    internal = true;
    description = ''
      Build context marker indicating which stage/system we're building.

      - "darwin-system": nix-darwin system configuration (Stage 1)
      - "nixos-system": NixOS system configuration (Stage 1)
      - "home-manager": Standalone home-manager configuration (Stage 2)

      This is used by modules to conditionally activate based on build context.
      For example, modules using home.activation should only run in "home-manager" context.
    '';
  };
}
