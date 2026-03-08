# Nix - Declarative package manager and configuration language
#
# Includes nixd LSP for IDE features like autocomplete, diagnostics, and formatting
# The Nix language itself is provided by the system
#
# Platform: Cross-platform
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.nixd];

  home.shellAliases = {
    nixd-version = "${pkgs.nixd}/bin/nixd --version";
  };
}
