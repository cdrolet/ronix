{
  config,
  pkgs,
  lib,
  ...
}: {
  # procs - Modern replacement for ps
  # Shows process information with color and formatting
  # Dependencies: None

  home.packages = [pkgs.procs];

  # Shell aliases
  home.shellAliases = {
    ps = "${pkgs.procs}/bin/procs";
    procs-tree = "${pkgs.procs}/bin/procs --tree";
  };
}
