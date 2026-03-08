{
  config,
  pkgs,
  lib,
  ...
}: {
  # Atuin - Magical shell history
  # Replaces shell history search with a SQLite database for better search and sync
  # Bound to Ctrl-R only (arrow keys use zsh history-substring-search)

  programs.atuin = {
    enable = true;
    enableZshIntegration = false;

    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
      filter_mode = "global";
      style = "compact";
      inline_height = 20;
      show_preview = true;
      exit_mode = "return-query";
    };
  };

  # Manual zsh integration: Ctrl-R only, no arrow key bindings
  programs.zsh.initContent = ''
    # Atuin - Ctrl-R only (arrow keys reserved for history-substring-search)
    eval "$(atuin init zsh --disable-up-arrow)"
  '';
}
