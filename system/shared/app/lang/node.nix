# Node.js - JavaScript runtime environment
#
# Includes npm (Node Package Manager), npx (package runner), and TypeScript LSP
# Used for JavaScript/TypeScript development and running JS-based tools
#
# Platform: Cross-platform
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [
    pkgs.nodejs
    pkgs.nodePackages.typescript-language-server
  ];

  home.shellAliases = {
    node-version = "${pkgs.nodejs}/bin/node --version";
    npm-version = "${pkgs.nodejs}/bin/npm --version";
  };
}
