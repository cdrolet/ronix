# GIMP - GNU Image Manipulation Program
#
# Purpose: Advanced image editing and photo retouching
# Platform: Cross-platform (macOS, Linux, Windows)
# Website: https://www.gimp.org/
#
# Features:
#   - Photo retouching and enhancement
#   - Layer-based editing
#   - Selection and masking tools
#   - Filters and effects
#   - Color correction
#   - Plugin system
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
      homebrew.casks = ["gimp"];
    })

    (lib.optionalAttrs isLinux {
      home.packages = [pkgs.gimp];
    })

    {
      home.shellAliases = {
        gimp3 = "gimp";
      };
    }
  ]
