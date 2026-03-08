# Bruno - Opensource API client
#
# Fast, Git-friendly alternative to Postman
# Features: Collections stored as plain text files, no cloud sync required
#
# Platform: Cross-platform (macOS, Linux, Windows)
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.bruno];

  home.shellAliases = {
    bruno = "${pkgs.bruno}/bin/bruno";
  };
}
