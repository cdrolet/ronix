# Shared Settings: Wallpaper Configuration (Stylix Integration)
#
# Purpose: Resolve wallpaper source and set stylix.image + stylix.imageScalingMode
# Platform: Cross-platform (macOS, Linux)
#
# Resolves wallpaper by priority: generate > remote > path
# Fallback: solid-color pixel from base00 when nothing configured
#
# Syncs user/<username>/wallpapers/ from the nix-config repo to
# ~/Pictures/wallpapers/ on every activation (if the folder exists).
# Users can then reference wallpapers via path = "~/Pictures/wallpapers/<file>".
#
# Platform modules (darwin/wallpaper.nix) handle OS-specific application.
# Stylix targets (gnome, wpaperd, sway) auto-apply from stylix.image.
{
  config,
  lib,
  pkgs,
  # Feature 047: userDataRoot = privateConfigRoot/users (mandatory)
  # Passed via extraSpecialArgs from home-manager.nix
  userDataRoot,
  ...
}: let
  themeLib = import ../../lib/theme.nix { inherit lib pkgs; };

  styleCfg = config.user.style;
  hasStyle = styleCfg != null;
  wpCfg = if hasStyle then (styleCfg.wallpaper or null) else null;
  hasWallpaper = wpCfg != null;

  # Source checks
  hasPath = hasWallpaper && wpCfg.path != null;
  hasRemote = hasWallpaper && wpCfg.remote != null;
  hasGenerate = hasWallpaper && wpCfg.generate != null;
  hasScaleMode = hasWallpaper && wpCfg.scaleMode != null;

  # Repo wallpapers sync: copy wallpapers/ to ~/Pictures/wallpapers/
  # Feature 047: userDataRoot = privateConfigRoot/users (mandatory)
  wallpapersSrc = "${toString userDataRoot}/${config.user.name}/wallpapers";
  # Nix-store-addressable path for firstRepoWallpaper
  _userDirPath = userDataRoot;
  hasWallpapersDir = builtins.pathExists wallpapersSrc;

  # Image file extensions (for detecting folder vs file paths)
  imageExts = [".jpg" ".jpeg" ".png" ".webp" ".heic"];

  # Detect cycling folder path: no image extension OR cyclingFrequency set
  isCyclingPath =
    hasPath
    && (
      (wpCfg.cyclingFrequency or null) != null
      || !(lib.any (ext: lib.hasSuffix ext wpCfg.path) imageExts)
    );

  # First image from committed repo wallpapers/ folder (Nix store path = valid stylix.image)
  firstRepoWallpaper =
    if hasWallpapersDir then
      let
        dirContents = builtins.readDir wallpapersSrc;
        imageNames = lib.naturalSort (lib.attrNames (lib.filterAttrs
          (name: type: type == "regular" && lib.any (ext: lib.hasSuffix ext name) imageExts)
          dirContents));
      in
        if imageNames != []
        then _userDirPath + "/${config.user.name}/wallpapers/${lib.head imageNames}"
        else null
    else null;

  # Generate sub-checks
  genCfg = if hasGenerate then wpCfg.generate else null;
  hasColor = hasGenerate && genCfg.color != null;
  hasBrightness = hasGenerate && genCfg.brightness != null;
  hasPattern = hasGenerate && genCfg.pattern != null;

  # Path expansion: convert ~/ to absolute path
  expandPath = path:
    if lib.hasPrefix "~/" path
    then "${config.home.homeDirectory}/${lib.removePrefix "~/" path}"
    else path;

  # Resolve the base image source (before brightness adjustment)
  baseImage =
    if hasRemote then
      pkgs.fetchurl {
        url = wpCfg.remote.url;
        hash = wpCfg.remote.hash;
      }
    else if hasPath && !isCyclingPath then
      expandPath wpCfg.path
    else if isCyclingPath && firstRepoWallpaper != null then
      firstRepoWallpaper
    else
      null;

  # Generate a gradient wallpaper from base16 background colors (base00-base03)
  gradientImage = pkgs.runCommand "gradient-wallpaper.png" {
    nativeBuildInputs = [ pkgs.imagemagick ];
    base00 = config.lib.stylix.colors.withHashtag.base00;
    base01 = config.lib.stylix.colors.withHashtag.base01;
    base02 = config.lib.stylix.colors.withHashtag.base02;
    base03 = config.lib.stylix.colors.withHashtag.base03;
  } ''
    convert -size 3840x2160 \
      \( xc:"$base00" xc:"$base01" xc:"$base02" xc:"$base03" +append \) \
      -filter Gaussian -resize 3840x2160\! \
      png32:$out
  '';

  # Apply brightness adjustment to an image
  adjustBrightness = image: brightness:
    pkgs.runCommand "adjusted-wallpaper.png" {
      nativeBuildInputs = [ pkgs.imagemagick ];
      src = image;
      # ImageMagick -modulate uses percentage (100 = unchanged)
      modulateValue = toString (brightness * 100);
    } ''
      convert "$src" -modulate "$modulateValue" png32:$out
    '';

  # Resolve the color name for solid color generation
  resolvedColor =
    if hasColor then themeLib.resolveColorName genCfg.color
    else "base00";

  # Resolve final wallpaper image by priority
  resolvedImage =
    # Generate takes priority
    if hasGenerate then
      if hasPattern && genCfg.pattern == "gradient" then
        if hasBrightness then adjustBrightness gradientImage genCfg.brightness
        else gradientImage
      else if hasPattern && genCfg.pattern == "solid" then
        config.lib.stylix.pixel resolvedColor
      else if hasColor then
        config.lib.stylix.pixel resolvedColor
      else if hasBrightness && baseImage != null then
        adjustBrightness baseImage genCfg.brightness
      else
        config.lib.stylix.pixel resolvedColor
    # Remote
    else if hasRemote then
      pkgs.fetchurl {
        url = wpCfg.remote.url;
        hash = wpCfg.remote.hash;
      }
    # Local path (file) — use expanded runtime path
    else if hasPath && !isCyclingPath then
      expandPath wpCfg.path
    # Cycling folder — use first committed repo image (Nix store path, valid for stylix.image)
    # wpaperd/osascript will cycle through ~/Pictures/wallpapers/ at runtime
    else if isCyclingPath && firstRepoWallpaper != null then
      firstRepoWallpaper
    # Fallback: solid pixel from background color
    else
      null;

  hasResolvedImage = resolvedImage != null;
in {
  config = lib.mkMerge [
    # Set stylix.image from resolved wallpaper
    (lib.mkIf hasResolvedImage {
      stylix.image = resolvedImage;
    })

    # Fallback pixel when no wallpaper configured
    (lib.mkIf (!hasResolvedImage) {
      stylix.image = lib.mkDefault (config.lib.stylix.pixel "base00");
    })

    # Set scaling mode
    (lib.mkIf hasScaleMode {
      stylix.imageScalingMode = wpCfg.scaleMode;
    })

    # Sync user/<name>/wallpapers/ from the repo to ~/Pictures/wallpapers/
    # Runs on every activation so new wallpapers are picked up after rebuild.
    (lib.mkIf hasWallpapersDir {
      home.activation.syncWallpapers = lib.hm.dag.entryAfter ["writeBoundary" "cloneGitRepos"] ''
        _src="${wallpapersSrc}"
        _dst="$HOME/Pictures/wallpapers"
        $DRY_RUN_CMD mkdir -p "$_dst"
        $DRY_RUN_CMD cp -rf "$_src/." "$_dst/"
      '';
    })
  ];
}
