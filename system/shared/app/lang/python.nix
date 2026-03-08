# Python - High-level programming language
#
# Includes Python 3 interpreter, pip package manager, uv (fast Python package installer),
# and pyright LSP for type checking and IDE features
#
# Platform: Cross-platform
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [
    pkgs.python3
    pkgs.python3Packages.pip
    pkgs.uv
    pkgs.pyright
  ];

  home.shellAliases = {
    python = "${pkgs.python3}/bin/python3";
    pip = "${pkgs.python3}/bin/pip3";
    py = "${pkgs.python3}/bin/python3";
  };
}
