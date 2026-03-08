# Linux Family: tmux Terminal Multiplexer
# Terminal session manager with split panes and windows
#
# Platform: Linux family (cross-platform)
# Category: Terminal utilities
{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.tmux = {
    enable = true;

    # Basic tmux settings
    keyMode = "vi";
    escapeTime = 0;
    historyLimit = 10000;

    # Enable mouse support
    mouse = true;

    # Terminal settings
    terminal = "screen-256color";
  };

  # Shell aliases for tmux
  home.shellAliases = {
    ta = "tmux attach";
    tl = "tmux list-sessions";
    tn = "tmux new-session -s";
  };
}
