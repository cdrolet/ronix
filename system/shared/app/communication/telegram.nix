# Telegram - Cloud-based messaging
#
# Purpose: Fast, secure, and cloud-based messaging platform
# Platform: Cross-platform (macOS, Linux, Windows, mobile)
# Website: https://telegram.org/
#
# Features:
#   - Cloud-based message sync
#   - Secret chats with E2E encryption
#   - Groups and channels (up to 200,000 members)
#   - File sharing (up to 2GB per file)
#   - Voice and video calls
#   - Bots and automation
#
# Installation:
#   - macOS: Via Homebrew cask
#   - Linux: Via nixpkgs (telegram-desktop)
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
      homebrew.casks = ["telegram"];
    })

    (lib.optionalAttrs isLinux {
      home.packages = [pkgs.telegram-desktop];

      home.shellAliases = {
        tg = "telegram-desktop";
      };
    })
  ]
