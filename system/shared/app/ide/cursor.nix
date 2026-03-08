# Cursor - AI-first code editor
#
# Purpose: VSCode fork with built-in AI pair programming
# Platform: Cross-platform (macOS, Linux)
# Website: https://cursor.com/
#
# Features:
#   - AI chat and code generation
#   - Codebase understanding
#   - VSCode compatibility
#   - Built-in AI pair programming
#
# Installation:
#   - Darwin: Via Homebrew cask (code-cursor not yet in nixpkgs for Darwin)
#   - Linux: pkgs.code-cursor (nixpkgs unstable, added 2025)
{
  pkgs,
  lib,
  configContext ? "home-manager",
  ...
}:
  lib.mkMerge [
    (lib.optionalAttrs (configContext == "darwin-system") {
      homebrew.casks = ["cursor"];
    })

    (lib.optionalAttrs (configContext == "home-manager") {
      home.packages = lib.mkIf pkgs.stdenv.isLinux [pkgs.code-cursor];
    })
  ]
