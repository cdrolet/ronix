# Zoom - Video conferencing
#
# Purpose: Video meetings, webinars, and collaboration
# Platform: Cross-platform (macOS, Linux, Windows)
# Website: https://zoom.us/
#
# Features:
#   - HD video and audio conferencing
#   - Screen sharing and collaboration
#   - Virtual backgrounds
#   - Recording and transcription
#   - Breakout rooms
#
# Installation:
#   - macOS: Via Homebrew cask
#   - Linux: Via nixpkgs (zoom-us)
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
      homebrew.casks = ["zoom"];
    })

    (lib.optionalAttrs isLinux {
      home.packages = [pkgs.zoom-us];
    })
  ]
