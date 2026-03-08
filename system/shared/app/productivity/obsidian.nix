# Obsidian - Knowledge base and note-taking app
#
# Markdown-based note-taking with powerful linking and graph view
# Features: Local-first, extensible with plugins, bidirectional links
#
# Platform: Cross-platform (macOS, Linux, Windows)
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.obsidian];

  home.shellAliases = {
    obsidian = "${pkgs.obsidian}/bin/obsidian";
  };
}
