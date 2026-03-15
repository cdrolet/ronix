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
#
# Extensions (via NUR rycee):
#   ublock-origin  - Advanced ad/tracker blocker
#   darkreader     - Dark mode for all websites
#   bitwarden      - Password manager
{
  config,
  pkgs,
  lib,
  configContext ? "home-manager",
  system ? "",
  ...
}: let
  isLinux = configContext != "darwin-system" && !(lib.hasSuffix "darwin" system);

  # NUR firefox-addons — available only when pkgs.nur overlay is applied.
  # Guard with hasAttr to avoid evaluation errors in contexts without NUR
  # (e.g. darwin-system overlay extraction, nix flake check without user-host-config).
  nurAddons =
    if pkgs != null && pkgs ? nur && pkgs.nur ? repos && pkgs.nur.repos ? rycee
    then pkgs.nur.repos.rycee.firefox-addons
    else null;

  extensions =
    if nurAddons != null
    then
      with nurAddons; [
        ublock-origin
        darkreader
        bitwarden
      ]
    else [];
in
  lib.mkMerge [
    (lib.optionalAttrs (configContext != "darwin-system") {
      programs.librewolf = {
        enable = true;
        profiles.default = {
          # Access config.user.workspace inside the option value (lazy), not in the
          # top-level let block (eager), to avoid infinite recursion during module evaluation.
          bookmarks.settings = (config.user.workspace or {}).bookmarks or [];

          # Firefox extensions installed via NUR rycee repository.
          # autoDisableScopes = 0 ensures extensions are enabled automatically
          # without requiring manual approval in the browser's add-on manager.
          extensions.packages = extensions;
        };

        # Prevent Firefox from auto-disabling externally-installed extensions.
        settings."extensions.autoDisableScopes" = 0;
      };

      stylix.targets.librewolf.profileNames = [ "default" ];
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
