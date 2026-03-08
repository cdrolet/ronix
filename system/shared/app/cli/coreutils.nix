{
  config,
  pkgs,
  lib,
  ...
}: {
  # GNU Core Utilities - Essential command-line tools
  # Provides GNU versions of common Unix utilities
  # Dependencies: None

  home.packages = [pkgs.coreutils];

  # Shell aliases for GNU versions (use mkDefault so eza/etc can override)
  home.shellAliases = {
    ls = lib.mkDefault "${pkgs.coreutils}/bin/ls --color=auto";
    ll = lib.mkDefault "${pkgs.coreutils}/bin/ls -alF --color=auto";
    la = lib.mkDefault "${pkgs.coreutils}/bin/ls -A --color=auto";
  };
}
