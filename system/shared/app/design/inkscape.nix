# Inkscape - Vector graphics editor
#
# Purpose: Professional vector graphics creation and editing
# Platform: Cross-platform (macOS, Linux, Windows)
# Website: https://inkscape.org/
#
# Features:
#   - SVG-based vector graphics editing
#   - Professional drawing tools
#   - Text and typography support
#   - Path operations and effects
#   - Extensions system
#   - Export to PNG, PDF, EPS, etc.
#
# Installation:
#   - macOS: Via Homebrew cask
#   - Linux: Via nixpkgs
{
  pkgs,
  lib,
  configContext ? "home-manager",
  system ? "",
  ...
}: let
  isLinux = configContext != "darwin-system" && !(lib.hasSuffix "darwin" system);
in
  lib.mkMerge [
    (lib.optionalAttrs (configContext == "darwin-system") {
      homebrew.casks = ["inkscape"];
    })

    (lib.optionalAttrs isLinux {
      home.packages = [pkgs.inkscape];
    })

    {
      home.shellAliases = {
        ink = "inkscape";
      };
    }
  ]
