# Shared Settings: Icon Theme Configuration
#
# Purpose: Apply user's icon theme to stylix from user.style.icon
# Platform: Cross-platform (macOS, Linux)
#
# Owns stylix options:
#   stylix.icons.enable  — true when icon config is set
#   stylix.icons.package — from style.icon.package
#   stylix.icons.dark    — from style.icon.darkName
#   stylix.icons.light   — from style.icon.lightName
{
  config,
  lib,
  pkgs,
  ...
}: let
  iconCfg = config.user.style.icon or null;
  hasIcon = iconCfg != null;
in {
  config = lib.mkIf hasIcon {
    stylix.icons = {
      enable = true;
      package = pkgs.${iconCfg.package};
      dark = iconCfg.darkName;
      light = iconCfg.lightName;
    };
  };
}
