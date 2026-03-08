# Shared Settings: Font Installation & Stylix Font Configuration
#
# Purpose: Install font packages and configure stylix fonts
# Feature: 030-user-font-config
# Platform: Cross-platform
#
# This module handles ONLY font concerns:
# 1. Installs font packages from nixpkgs (auto-translated from family names)
# 2. Configures stylix.fonts for automatic font application across apps
#
# Other stylix options are owned by:
#   theme.nix     — stylix.enable, base16Scheme, polarity, override
#   wallpaper.nix — stylix.image, imageScalingMode
#
# Private fonts (not in nixpkgs) are handled by platform-specific
# private-fonts.nix modules via runtime git repo cloning.
{
  config,
  lib,
  pkgs,
  ...
}: let
  fontsLib = import ../../lib/fonts.nix {inherit lib;};

  # Extract user font configuration
  styleCfg = config.user.style;
  hasStyle = styleCfg != null;
  fontsCfg = if hasStyle then styleCfg.fonts else null;
  hasConfig = fontsCfg != null;
  fontDefaults = if hasConfig then fontsCfg.defaults else null;
  hasDefaults = fontDefaults != null;

  # Font families and sizes per category
  monoFamilies = if hasDefaults then fontDefaults.monospace.families else [];
  monoSize = if hasDefaults then fontDefaults.monospace.size else 12;
  sansFamilies = if hasDefaults then fontDefaults.sansSerif.families else [];
  sansSize = if hasDefaults then fontDefaults.sansSerif.size else 10;
  serifFamilies = if hasDefaults then fontDefaults.serif.families else [];
  serifSize = if hasDefaults then fontDefaults.serif.size else 11;
  emojiFamilies = if hasDefaults then fontDefaults.emoji.families else [];

  hasMonospace = monoFamilies != [];
  hasSansSerif = sansFamilies != [];
  hasSerif = serifFamilies != [];
  hasEmoji = emojiFamilies != [];
  hasAnyFonts = hasMonospace || hasSansSerif || hasSerif || hasEmoji;

  # Collect all font family names
  allFontFamilies =
    if hasDefaults
    then lib.unique (lib.flatten [serifFamilies sansFamilies monoFamilies emojiFamilies])
    else [];

  # Resolve font families to nixpkgs packages (null = not found in nixpkgs)
  resolvedFromDefaults = lib.filter (p: p != null) (
    map (fontsLib.tryResolvePackage pkgs) allFontFamilies
  );

  # Add explicit packages (escape hatch for non-standard naming)
  explicitPackages =
    if hasConfig
    then
      lib.filter (p: p != null) (
        map (name: pkgs.${name} or null) (fontsCfg.packages or [])
      )
    else [];

  # Final package list (deduplicated)
  allPackages = lib.unique (resolvedFromDefaults ++ explicitPackages);

  # Resolve a font to a package for stylix (nixpkgs or placeholder for private fonts)
  resolveFont = name: let
    pkg = fontsLib.tryResolvePackage pkgs name;
  in
    if pkg != null
    then pkg
    else fontsLib.mkPlaceholderFontPackage pkgs name;
in {
  config = lib.mkMerge [
    # Install font packages
    (lib.mkIf (allPackages != []) {
      home.packages = allPackages;
    })

    # Configure stylix fonts
    (lib.mkIf hasAnyFonts {
      stylix.fonts = {
        monospace = lib.mkIf hasMonospace {
          name = builtins.head monoFamilies;
          package = resolveFont (builtins.head monoFamilies);
        };
        sansSerif = lib.mkIf hasSansSerif {
          name = builtins.head sansFamilies;
          package = resolveFont (builtins.head sansFamilies);
        };
        serif = lib.mkIf hasSerif {
          name = builtins.head serifFamilies;
          package = resolveFont (builtins.head serifFamilies);
        };
        emoji = lib.mkIf hasEmoji {
          name = builtins.head emojiFamilies;
          package = resolveFont (builtins.head emojiFamilies);
        };

        sizes = {
          terminal = monoSize;
          applications = sansSize;
          desktop = sansSize;
          popups = sansSize;
        };
      };
    })
  ];
}
