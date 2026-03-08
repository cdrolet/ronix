{
  config,
  pkgs,
  lib,
  ...
}: {
  # eza - Modern replacement for ls
  # Feature-rich file listing with colors and icons
  # Dependencies: None

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    git = true;
    icons = "auto"; # Changed from boolean to string to avoid deprecation warning
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };

  # Shell aliases
  home.shellAliases = {
    ls = "${pkgs.eza}/bin/eza";
    ll = "${pkgs.eza}/bin/eza -l";
    la = "${pkgs.eza}/bin/eza -la";
    lt = "${pkgs.eza}/bin/eza --tree";
  };
}
