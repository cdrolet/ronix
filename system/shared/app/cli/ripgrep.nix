{
  config,
  pkgs,
  lib,
  ...
}: {
  # ripgrep - Fast line-oriented search tool
  # Recursively searches directories for regex patterns
  # Dependencies: None

  programs.ripgrep = {
    enable = true;
    arguments = [
      "--max-columns=150"
      "--max-columns-preview"
      "--glob=!.git/*"
      "--smart-case"
    ];
  };

  # Shell aliases
  home.shellAliases = {
    rg = "${pkgs.ripgrep}/bin/rg";
    grep = "${pkgs.ripgrep}/bin/rg";
  };
}
