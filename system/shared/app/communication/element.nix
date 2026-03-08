# Element - Matrix client
#
# Purpose: Feature-rich client for the Matrix decentralized communication protocol
# Platform: Cross-platform (macOS, Linux, Windows)
# Website: https://element.io/
#
# Features:
#   - End-to-end encrypted messaging
#   - Voice and video calls
#   - File sharing
#   - Community and workspace organization
#   - Self-hosted server support
#   - Bridge to other chat platforms
#   - Open protocol (Matrix)
#
# Installation:
#   - macOS: Via Homebrew cask
#   - Linux: Via nixpkgs (element-desktop)
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
      homebrew.casks = ["element"];
    })

    (lib.optionalAttrs isLinux {
      home.packages = [pkgs.element-desktop];
    })
  ]
