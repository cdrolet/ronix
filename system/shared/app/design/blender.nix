# Blender - 3D creation suite
#
# Purpose: Professional 3D modeling, animation, and rendering
# Platform: Cross-platform (macOS, Linux, Windows)
# Website: https://www.blender.org/
#
# Features:
#   - 3D modeling (sculpting, retopology)
#   - Animation and rigging
#   - Rendering (Cycles, Eevee)
#   - Video editing
#   - VFX and compositing
#   - Game development (game engine)
#   - Python scripting
#
# Installation:
#   - macOS: Via Homebrew cask
#   - Linux: Via nixpkgs
#
# Sources:
#   - https://formulae.brew.sh/cask/blender
{
  pkgs,
  lib,
  configContext ? "home-manager",
  system ? "",
  ...
}: let
  isLinux = configContext != "darwin-system" && !(lib.hasSuffix "darwin" system);
  # Blender has no binary cache for aarch64-linux; building from source takes hours
  isLinuxX86 = isLinux && lib.hasPrefix "x86_64" system;
in
  lib.mkMerge [
    (lib.optionalAttrs (configContext == "darwin-system") {
      homebrew.casks = ["blender"];
    })

    (lib.optionalAttrs isLinuxX86 {
      home.packages = [pkgs.blender];
    })

    {
      home.shellAliases = {
        blend = "blender";
      };
    }
  ]
