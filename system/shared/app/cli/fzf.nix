{
  config,
  pkgs,
  lib,
  ...
}: {
  # fzf - Command-line fuzzy finder
  # Interactive filter for command-line
  # Dependencies: None

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    defaultCommand = "${pkgs.fd}/bin/fd --type f";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
    ];
  };
}
