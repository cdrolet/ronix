# GNOME Family: Transparent Top Bar Extension
#
# Purpose: Adjustable transparency for the GNOME top panel
# Extension: https://extensions.gnome.org/extension/3960/transparent-top-bar-adjustable-transparency/
# UUID: transparent-top-bar@ftpix.com (registered in extensions.nix)
#
# Opacity mapped from user.style.theme.opacity.applications (0.0–1.0) → integer (0–255).
# Defaults to fully opaque (255) when opacity is not configured.
{
  config,
  pkgs,
  lib,
  ...
}: let
  themeCfg = (config.user.style or {}).theme or null;
  opacityCfg = if themeCfg != null then themeCfg.opacity or null else null;
  appOpacity = if opacityCfg != null then opacityCfg.applications else 1.0;

  # Convert 0.0–1.0 float to 0–255 integer
  opacityInt = builtins.floor (appOpacity * 255);
in {
  home.packages = [pkgs.gnomeExtensions.transparent-top-bar-adjustable-transparency];

  dconf.settings."org/gnome/shell/extensions/transparent-top-bar" = {
    opacity = lib.mkDefault opacityInt;
  };
}
