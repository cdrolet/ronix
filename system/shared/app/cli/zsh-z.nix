{
  config,
  pkgs,
  lib,
  ...
}: {
  # zsh-z - Directory jumping based on frecency
  # Tracks your most used directories and lets you jump with 'z <pattern>'
  # Dependencies: zsh

  home.packages = [pkgs.zsh-z];

  programs.zsh.initContent = ''
    # zsh-z plugin
    source ${pkgs.zsh-z}/share/zsh-z/zsh-z.plugin.zsh

    # Data file location
    export ZSHZ_DATA="''${ZSH_CACHE:-$HOME/.cache/zsh}/z"
  '';

  home.shellAliases = {
    j = "z";
  };
}
