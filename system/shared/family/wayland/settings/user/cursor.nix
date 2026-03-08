# Shared Settings: Cursor Theme Configuration
#
# Purpose: Apply user's cursor theme to stylix from user.style.cursor
# Platform: Cross-platform (macOS, Linux)
#
# Owns stylix option:
#   stylix.cursor — from style.cursor (package, name, size)
{
  config,
  lib,
  pkgs,
  ...
}: let
  cursorCfg = config.user.style.cursor or null;
  hasCursor = cursorCfg != null;
in {
  config = lib.mkIf hasCursor {
    stylix.cursor = {
      name = cursorCfg.name;
      package = pkgs.${cursorCfg.package};
      size = cursorCfg.size;
    };
  };
}
