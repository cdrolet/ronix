# Zed - High-performance code editor
#
# Modern, collaborative code editor built in Rust
# Features: Fast performance, built-in collaboration, AI assistance
#
# Platform: Cross-platform (macOS, Linux)
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Install zed package (includes desktop file: dev.zed.Zed.desktop)
  home.packages = [pkgs.zed-editor];

  home.shellAliases = {
    zed = "${pkgs.zed-editor}/bin/zed";
  };
}
