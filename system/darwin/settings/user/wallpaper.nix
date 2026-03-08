# Darwin Settings: Wallpaper Configuration
#
# Purpose: Apply wallpaper to macOS desktop via osascript
# Feature: 033-user-wallpaper-config
#
# Reads user.style.wallpaper and applies to macOS desktop.
# stylix.image is set by the shared wallpaper.nix module.
# This module only handles macOS-specific desktop application.
#
# Sources:
#   path (file)   — set single static wallpaper via System Events
#   path (folder) — enable macOS native cycling via System Events
#                   (pictures folder + picture rotation + change interval)
#   remote        — download at activation, then set as single image
#   generate      — use stylix store path as single image
#
# macOS picture rotation modes (System Events Desktop):
#   0 = never  1 = timed interval  2 = on login  3 = on wake from sleep
{
  config,
  lib,
  pkgs,
  ...
}: let
  styleCfg = config.user.style or {};
  wpCfg = styleCfg.wallpaper or null;
  hasWallpaper = wpCfg != null;

  hasPath = hasWallpaper && wpCfg.path != null;
  hasRemote = hasWallpaper && wpCfg.remote != null;
  hasGenerate = hasWallpaper && wpCfg.generate != null;
  hasAnySource = hasPath || hasRemote || hasGenerate;

  # Path expansion
  expandPath = path:
    if lib.hasPrefix "~/" path
    then "${config.home.homeDirectory}/${lib.removePrefix "~/" path}"
    else path;

  localPath = if hasPath then expandPath wpCfg.path else null;
  storeImage = config.stylix.image;

  # Cycling — only relevant for path source
  cycleFreq =
    if hasPath && (wpCfg.cyclingFrequency or null) != null
    then wpCfg.cyclingFrequency
    else "daily";

  # macOS picture rotation mode: 1=timed interval, 2=on login
  darwinRotation = if cycleFreq == "on-login" then 2 else 1;

  # Timed interval in seconds (ignored when rotation=2)
  darwinInterval =
    if cycleFreq == "every-5min" then 300
    else if cycleFreq == "every-30min" then 1800
    else if cycleFreq == "hourly" then 3600
    else 86400; # daily (default)

  # File extension validation — skip warning when cyclingFrequency is set
  # (path is intentionally a folder in that case)
  validExtensions = [".jpg" ".jpeg" ".png" ".heic" ".webp"];
  hasValidExtension = path:
    lib.any (ext: lib.hasSuffix ext (lib.toLower path)) validExtensions;

  warnings =
    lib.optional (
      hasPath
      && (wpCfg.cyclingFrequency or null) == null
      && !hasValidExtension localPath
    ) "Wallpaper has unsupported extension: ${localPath}. Supported: ${lib.concatStringsSep ", " validExtensions}";
in {
  inherit warnings;

  home.activation.setDarwinWallpaper = lib.mkIf hasAnySource (
    config.lib.dag.entryAfter ["writeBoundary" "cloneGitRepos"] (
      if hasRemote then
        # Download from URL at activation time and set as single image
        ''
          WALLPAPER_DIR="${config.home.homeDirectory}/.cache/wallpaper"
          mkdir -p "$WALLPAPER_DIR"
          WALLPAPER="$WALLPAPER_DIR/current"

          if ! [ -f "$WALLPAPER" ]; then
            echo "Downloading wallpaper from ${wpCfg.remote.url}..." >&2
            $DRY_RUN_CMD ${lib.getExe pkgs.curl} -fsSL -o "$WALLPAPER" "${wpCfg.remote.url}"
          fi

          if [ -f "$WALLPAPER" ]; then
            $DRY_RUN_CMD /usr/bin/osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER\""
            [[ -v VERBOSE ]] && echo "Darwin wallpaper set from remote URL"
          else
            echo "Warning: Failed to download wallpaper" >&2
          fi
        ''
      else if hasGenerate then
        # Use store path from stylix.image (generated wallpaper)
        ''
          WALLPAPER="${storeImage}"
          if [ -f "$WALLPAPER" ]; then
            $DRY_RUN_CMD /usr/bin/osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER\""
            [[ -v VERBOSE ]] && echo "Darwin wallpaper set from generated image"
          fi
        ''
      else
        # Local path: detect folder vs file at runtime
        # Folder → macOS native cycling (pictures folder + rotation interval)
        # File   → single static wallpaper
        ''
          WALLPAPER="${localPath}"

          if [ -d "$WALLPAPER" ]; then
            $DRY_RUN_CMD /usr/bin/osascript \
              -e 'tell application "System Events"' \
              -e 'tell every desktop' \
              -e "set pictures folder to POSIX file \"$WALLPAPER\"" \
              -e "set picture rotation to ${toString darwinRotation}" \
              -e "set change interval to ${toString darwinInterval}" \
              -e "set random order to true" \
              -e 'end tell' \
              -e 'end tell'
            [[ -v VERBOSE ]] && echo "Darwin wallpaper cycling enabled: $WALLPAPER (${cycleFreq})"
          elif [ -f "$WALLPAPER" ]; then
            $DRY_RUN_CMD /usr/bin/osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER\""
            [[ -v VERBOSE ]] && echo "Darwin wallpaper set: $WALLPAPER"
          else
            echo "Warning: Wallpaper path not found: $WALLPAPER" >&2
          fi
        ''
    )
  );
}
