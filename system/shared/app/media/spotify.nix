# Spotify - Music streaming client
#
# Purpose: Cross-platform music streaming application
# Platform: Cross-platform (macOS, Linux)
# Website: https://www.spotify.com/
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
      homebrew.casks = ["spotify"];
    })

    (lib.optionalAttrs isLinux {
      home.packages = [pkgs.spotify];
    })
  ]
