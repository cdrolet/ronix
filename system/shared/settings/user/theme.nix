# Shared Settings: Theme Configuration (Stylix Integration)
#
# Purpose: Apply user's color theme to stylix from user.style.theme
# Platform: Cross-platform (macOS, Linux)
#
# Owns stylix core options:
#   stylix.enable       — always true (stylix is the theming engine)
#   stylix.base16Scheme — from theme.name or auto-generated from wallpaper
#   stylix.polarity     — from theme.polarity
#   stylix.override     — from theme.color.overrides (aliases resolved to base16)
#   stylix.opacity      — from style.opacity
#
# When theme.color.fromWallpaper = true, no base16Scheme is set,
# letting stylix's genetic algorithm generate a palette from stylix.image.
{
  config,
  lib,
  pkgs,
  ...
}: let
  themeLib = import ../../lib/theme.nix { inherit lib pkgs; };

  styleCfg = config.user.style;
  hasStyle = styleCfg != null;
  themeCfg = if hasStyle then (styleCfg.theme or null) else null;
  hasTheme = themeCfg != null;

  hasName = hasTheme && themeCfg.name != null;
  hasPolarity = hasTheme && themeCfg.polarity != null;
  colorCfg = if hasTheme then (themeCfg.color or null) else null;
  hasColor = colorCfg != null;
  hasOverrides = hasColor && colorCfg.overrides != {};
  colorsFromWallpaper = hasColor && (colorCfg.fromWallpaper or false);

  opacityCfg = if hasTheme then (themeCfg.opacity or null) else null;
  hasOpacity = opacityCfg != null;
in {
  config = lib.mkMerge [
    # Always enable stylix
    {
      stylix.enable = true;
    }

    # Default polarity
    {
      stylix.polarity = lib.mkDefault "either";
    }

    # Default base16 scheme (Nord) — only when NOT generating from wallpaper
    # When colorsFromWallpaper = true, we leave base16Scheme at its option
    # default (priority 1500) which auto-generates from stylix.image
    (lib.mkIf (!colorsFromWallpaper) {
      stylix.base16Scheme = lib.mkDefault "${pkgs.base16-schemes}/share/themes/nord.yaml";
    })

    # Apply base16 scheme from theme name (skip if generating from wallpaper)
    (lib.mkIf (hasName && !colorsFromWallpaper) {
      stylix.base16Scheme = themeLib.resolveScheme themeCfg.name;
    })

    # Apply polarity
    (lib.mkIf hasPolarity {
      stylix.polarity = themeCfg.polarity;
    })

    # Apply color overrides (resolve aliases to base16 names)
    (lib.mkIf hasOverrides {
      stylix.override = themeLib.resolveColors colorCfg.overrides;
    })

    # Apply opacity settings
    (lib.mkIf hasOpacity {
      stylix.opacity = {
        inherit (opacityCfg) applications terminal desktop popups;
      };
    })
  ];
}
