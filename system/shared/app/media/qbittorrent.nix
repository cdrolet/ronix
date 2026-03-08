# qBittorrent - BitTorrent client
#
# Purpose: Cross-platform, open-source BitTorrent client
# Platform: Cross-platform (macOS, Linux, Windows, FreeBSD)
# Website: https://www.qbittorrent.org/
#
# Features:
#   - Open-source alternative to uTorrent
#   - Built-in torrent search engine
#   - Sequential downloading
#   - Advanced RSS support with filters
#   - Web UI for remote control
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
      homebrew.casks = ["qbittorrent"];
    })

    (lib.optionalAttrs isLinux {
      home.packages = [pkgs.qbittorrent];

      home.shellAliases = {
        qbt = "qbittorrent";
      };

      xdg.mimeApps.defaultApplications = {
        "application/x-bittorrent" = "org.qbittorrent.qBittorrent.desktop";
        "x-scheme-handler/magnet" = "org.qbittorrent.qBittorrent.desktop";
      };
    })
  ]
