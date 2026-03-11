# Nix Update - System Configuration Update Tool
#
# Purpose: Desktop-launchable tool to update nix-config (fresh-install)
# Runs:    git pull + clear cache + rebuild + install (just fresh-install)
#
# Platform: Cross-platform (macOS, Linux)
# Linux:    .desktop file with Terminal=true for dock integration
# macOS:    Script in PATH for terminal invocation
#
# Dock integration: add "nix-update" to user.workspace.docked
# GNOME fuzzy matching will find nix-update.desktop automatically.
#
# Config dir: $HOME/.config/nix-config (default, override with NIX_CONFIG_DIR)
# State file: $HOME/.local/share/nix-config/last.json (read by just fresh-install)
{
  config,
  pkgs,
  lib,
  ...
}: let
  configDir = "${config.home.homeDirectory}/.config/nix-config";

  scriptText = ''
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_DIR="''${NIX_CONFIG_DIR:-${configDir}}"

    echo "======================================"
    echo "  Nix Config — System Update"
    echo "======================================"
    echo ""
    echo "This will:"
    echo "  • Pull latest changes from git"
    echo "  • Clear Nix evaluation caches"
    echo "  • Rebuild and install configuration"
    echo ""

    read -rp "Proceed with update? [y/N] " confirm
    case "$confirm" in
      [yY] | [yY][eE][sS]) ;;
      *) echo "Cancelled."; read -rp "Press Enter to close..." _; exit 0 ;;
    esac

    echo ""

    if [ ! -d "$CONFIG_DIR" ]; then
      echo "Error: nix-config not found at $CONFIG_DIR"
      echo "Set NIX_CONFIG_DIR to your nix-config repository path."
      exit 1
    fi

    cd "$CONFIG_DIR"
    just fresh-install

    echo ""
    read -rp "Press Enter to close..." _
  '';
in {
  # just is a runtime dependency: the script calls `just fresh-install`
  home.packages = [pkgs.just];

  # Install the update script
  home.file.".local/bin/nix-update" = {
    text = scriptText;
    executable = true;
  };

  # Linux: .desktop file for GNOME/FreeDesktop dock and app launcher
  # Uses $TERMINAL session variable (set by the active terminal app, e.g. ghostty).
  # Falls back to xterm if unset. Closes automatically when script exits.
  home.file.".local/share/applications/nix-update.desktop" = lib.mkIf pkgs.stdenv.isLinux {
    text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Nix Update
      Comment=Update system configuration (git pull + rebuild + install)
      Exec=bash -c '"''${TERMINAL:-xterm}" -e ${config.home.homeDirectory}/.local/bin/nix-update'
      Icon=system-software-update
      Terminal=false
      Categories=System;
      Keywords=nix;update;system;rebuild;
    '';
  };
}
