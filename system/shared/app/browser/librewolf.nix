# LibreWolf - Privacy-focused Firefox fork
#
# Purpose: Firefox-based browser with enhanced privacy defaults and no telemetry
# Platform: Cross-platform (nix-managed, supports aarch64-darwin and aarch64-linux)
# Website: https://librewolf.net/
#
# Bookmarks:
#   Declare bookmarks in user config under user.workspace.bookmarks.
#   Supports individual bookmarks, folders, and separators.
#   See user-schema.nix for the full schema.
{
  config,
  pkgs,
  lib,
  configContext ? "home-manager",
  system ? "",
  ...
}: let
  isLinux = configContext != "darwin-system" && !(lib.hasSuffix "darwin" system);
  bookmarks = (config.user.workspace or {}).bookmarks or [];
in
  lib.mkMerge [
    (lib.optionalAttrs (configContext != "darwin-system") {
      programs.librewolf = {
        enable = true;
        profiles.default = {
          bookmarks.settings = bookmarks;
          extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
            darkreader
            bitwarden
          ];
        };
      };
    })

    (lib.optionalAttrs isLinux {
      xdg.mimeApps.defaultApplications = {
        "text/html" = "librewolf.desktop";
        "x-scheme-handler/http" = "librewolf.desktop";
        "x-scheme-handler/https" = "librewolf.desktop";
        "x-scheme-handler/about" = "librewolf.desktop";
        "x-scheme-handler/unknown" = "librewolf.desktop";
      };
    })
  ]
