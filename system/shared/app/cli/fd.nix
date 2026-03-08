{
  config,
  pkgs,
  lib,
  ...
}: {
  # fd - Fast and user-friendly alternative to find
  # Simple syntax for finding files and directories
  # Dependencies: None

  programs.fd = {
    enable = true;
    hidden = false;
    ignores = [
      ".git/"
      "node_modules/"
      "*.pyc"
    ];
  };

  # Shell aliases
  home.shellAliases = {
    find = "${pkgs.fd}/bin/fd";
  };
}
