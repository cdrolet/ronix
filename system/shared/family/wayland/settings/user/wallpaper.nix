# Linux Family Settings: Wallpaper Cycling via wpaperd
#
# Purpose: Enable wpaperd for Wayland wallpaper display. When the user has a
#          wallpapers/ folder in the repo, configure wpaperd to cycle through
#          ~/Pictures/wallpapers/ (synced from repo by shared wallpaper.nix).
#          Otherwise, let stylix control wpaperd normally (single static image).
#
# Platform: Linux / Wayland (wlr-layer-shell: Niri, Sway, River, etc.)
#           GNOME does not support wlr-layer-shell — GNOME hosts should add:
#             services.wpaperd.enable = lib.mkForce false;
#
# Color palette (fromWallpaper = true) is build-time and independent of cycling.
# stylix.image is still used for all other stylix targets (terminal, GTK, etc.)
# wpaperd simply cycles different images visually at runtime.
#
# stylix.targets.wpaperd is disabled ONLY when folder cycling is active —
# otherwise stylix manages wpaperd normally from stylix.image.
{
  config,
  lib,
  pkgs,
  # Feature 047: userDataRoot = privateConfigRoot/users (mandatory)
  userDataRoot,
  ...
}: let
  styleCfg = config.user.style or {};
  wpCfg = styleCfg.wallpaper or null;
  hasWallpaper = wpCfg != null;

  # Check if the user has a wallpapers/ folder in the private config repo.
  # Feature 047: userDataRoot = privateConfigRoot/users (mandatory)
  userName = config.user.name;
  wallpapersInRepo = "${toString userDataRoot}/${userName}/wallpapers";
  hasCycling = builtins.pathExists wallpapersInRepo;

  # Cycling frequency — default to "daily" when not set
  cycleFreq =
    if hasWallpaper && (wpCfg.cyclingFrequency or null) != null
    then wpCfg.cyclingFrequency
    else "daily";

  # Map cycling frequency to wpaperd duration string
  wpaperdDuration =
    if cycleFreq == "on-login" then "999d"    # effectively static per session
    else if cycleFreq == "every-5min" then "5m"
    else if cycleFreq == "every-30min" then "30m"
    else if cycleFreq == "hourly" then "1h"
    else "1d";                                  # daily (default)

  wallpapersDir = "${config.home.homeDirectory}/Pictures/wallpapers";
in {
  home.packages = [pkgs.wpaperd];
  services.wpaperd.enable = true;

  # When cycling: take control of wpaperd config (folder + duration).
  # When not cycling: stylix manages wpaperd from stylix.image as normal.
  stylix.targets.wpaperd.enable = lib.mkIf hasCycling (lib.mkForce false);

  xdg.configFile."wpaperd/config.toml" = lib.mkIf hasCycling {
    text = ''
      [output.any]
      path = "${wallpapersDir}"
      sorting = "random"
      duration = "${wpaperdDuration}"
    '';
  };

  # Ensure ~/Pictures/wallpapers/ exists so wpaperd can start.
  # Seeds with stylix.image if empty (e.g. before repo wallpapers are synced).
  home.activation.ensureWallpapersDir = lib.mkIf hasCycling (
    lib.hm.dag.entryAfter ["writeBoundary" "cloneGitRepos"] ''
      _dir="${wallpapersDir}"
      $DRY_RUN_CMD mkdir -p "$_dir"
      if [ -z "$(ls -A "$_dir" 2>/dev/null)" ]; then
        $DRY_RUN_CMD cp "${config.stylix.image}" "$_dir/stylix-fallback.png"
      fi
    ''
  );
}
