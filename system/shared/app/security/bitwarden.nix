# Bitwarden - Password manager
#
# Purpose: Secure and free password manager for all devices
# Platform: Cross-platform (macOS, Linux, Windows)
# Website: https://bitwarden.com/
#
# Features:
#   - End-to-end encrypted password vault
#   - Cross-device sync
#   - Browser integration
#   - Secure password generator
#   - Two-factor authentication
#   - Free tier with unlimited passwords
#
# Installation:
#   - macOS: Via Homebrew cask
#   - Linux: Via nixpkgs (bitwarden-desktop)
{
  pkgs,
  lib,
  configContext ? "home-manager",
  system ? "",
  ...
}: let
  isDarwin = configContext != "darwin-system" && lib.hasSuffix "darwin" system;
  isLinux = configContext != "darwin-system" && !(lib.hasSuffix "darwin" system);
in
  lib.mkMerge [
    (lib.optionalAttrs (configContext == "darwin-system") {
      homebrew.casks = ["bitwarden"];
    })

    (lib.optionalAttrs isDarwin {
      home.shellAliases = {
        bw-desktop = "open -a Bitwarden";
      };
    })

    (lib.optionalAttrs isLinux {
      home.packages = [pkgs.bitwarden-desktop];
    })
  ]
