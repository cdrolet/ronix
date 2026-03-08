# macchina - Fast system information tool
#
# A modern replacement for neofetch/fastfetch written in Rust
# Displays system information in a clean, customizable format
#
# Platform: Cross-platform (Linux, macOS)
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.macchina];

  home.shellAliases = {
    sysinfo = "${pkgs.macchina}/bin/macchina";
  };
}
