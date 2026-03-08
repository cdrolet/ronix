# Arena Chess GUI
#
# Purpose: Free graphical chess interface for engine analysis and gameplay
# Platform: Linux (nixpkgs)
#
# Arena is a free chess GUI that assists in:
# - Analyzing chess positions with engines
# - Playing against chess engines
# - Testing and comparing chess engines
# - Managing chess games and databases
#
# Features:
# - Supports UCI and Winboard chess engines
# - Multi-engine analysis
# - Opening book support
# - PGN game management
# - Tournament mode for engine testing
#
# Constitutional: <200 lines, uses lib.mkDefault
#
# Usage:
# Add "arena" to user.workspace.applications array
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Install Arena chess GUI
  home.packages = [pkgs.arena];

  # Shell aliases for convenience
  home.shellAliases = {
    chess-arena = "arena";
  };
}
