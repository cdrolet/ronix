# Nix Update - System Configuration Update Tool
#
# Purpose: Desktop-launchable TUI menu to manage nix-config
# Options: full update, home-only update, garbage collect, exit
#
# Platform: Cross-platform (macOS, Linux)
# Linux:    .desktop file with Terminal=true for dock integration
# macOS:    Script in PATH for terminal invocation
#
# Dock integration: add "nix-update" to user.workspace.docked
# GNOME fuzzy matching will find nix-update.desktop automatically.
#
# Config dir: $HOME/.config/nix-config (default, override with NIX_CONFIG_DIR)
# State file: $HOME/.local/share/nix-config/last.json (read by just recipes)
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

    BOLD='\033[1m'
    DIM='\033[2m'
    CYAN='\033[1;36m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    RED='\033[1;31m'
    RESET='\033[0m'

    CONFIG_DIR="''${NIX_CONFIG_DIR:-${configDir}}"

    if [ ! -d "$CONFIG_DIR" ]; then
      printf "\n  ''${RED}Error:''${RESET} nix-config not found at %s\n" "$CONFIG_DIR"
      printf "  Set NIX_CONFIG_DIR to your nix-config repository path.\n\n"
      read -rp "  Press Enter to close..." _
      exit 1
    fi

    while true; do
      clear
      printf "\n"
      printf "  ''${CYAN}┌─────────────────────────────────────────────────────────┐''${RESET}\n"
      printf "  ''${CYAN}│''${RESET}               ''${BOLD}Nix Config — Update Tool''${RESET}                  ''${CYAN}│''${RESET}\n"
      printf "  ''${CYAN}└─────────────────────────────────────────────────────────┘''${RESET}\n"
      printf "\n"
      printf "  ''${BOLD}[1]''${RESET}  Full update      ''${DIM}pull + cache clear + rebuild system & home''${RESET}\n"
      printf "  ''${BOLD}[2]''${RESET}  Home update      ''${DIM}pull + cache clear + rebuild home only''${RESET}\n"
      printf "  ''${BOLD}[3]''${RESET}  Garbage collect  ''${DIM}delete old generations''${RESET}\n"
      printf "  ''${BOLD}[4]''${RESET}  Exit\n"
      printf "\n"
      printf "  ''${BOLD}▶ Select [1-4]:''${RESET} "
      read -r choice

      case "$choice" in
        1)
          clear
          printf "\n  ''${GREEN}▶ Running full update...''${RESET}\n\n"
          cd "$CONFIG_DIR"
          just fresh-install
          printf "\n"
          read -rp "  Press Enter to close..." _
          exit 0
          ;;
        2)
          clear
          printf "\n  ''${GREEN}▶ Running home update...''${RESET}\n\n"
          cd "$CONFIG_DIR"
          just fresh-install-home
          printf "\n"
          read -rp "  Press Enter to close..." _
          exit 0
          ;;
        3)
          clear
          printf "\n  ''${YELLOW}▶ Running garbage collection...''${RESET}\n\n"
          cd "$CONFIG_DIR"
          just clean
          printf "\n"
          read -rp "  Press Enter to close..." _
          exit 0
          ;;
        4)
          exit 0
          ;;
        *)
          printf "\n  ''${RED}Invalid choice.''${RESET} Please enter 1, 2, 3, or 4.\n"
          sleep 1
          ;;
      esac
    done
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
      Comment=Update nix configuration (full update, home update, garbage collect)
      Exec=bash -c '"''${TERMINAL:-xterm}" -e ${config.home.homeDirectory}/.local/bin/nix-update'
      Icon=system-software-update
      Terminal=false
      Categories=System;
      Keywords=nix;update;system;rebuild;
    '';
  };
}
