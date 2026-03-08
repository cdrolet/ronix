# Linux Family: htop Process Monitor
# System process viewer and manager
#
# Platform: Linux family (cross-platform)
# Category: System monitoring
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Install htop for interactive process monitoring
  home.packages = [pkgs.htop];

  # Shell alias for common usage
  home.shellAliases = {
    htop-cpu = "htop --sort-key PERCENT_CPU";
    htop-mem = "htop --sort-key PERCENT_MEM";
  };
}
