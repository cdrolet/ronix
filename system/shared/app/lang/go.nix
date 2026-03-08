# Go - Statically typed, compiled programming language
#
# Includes Go compiler, build tools, module support, and gopls LSP
# Designed for building simple, reliable, and efficient software
#
# Platform: Cross-platform
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [
    pkgs.go
    pkgs.gopls
  ];

  # Set GOPATH to user's home directory
  home.sessionVariables = {
    GOPATH = "$HOME/go";
  };

  home.shellAliases = {
    go-version = "${pkgs.go}/bin/go version";
  };
}
