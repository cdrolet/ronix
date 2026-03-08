# Caligula - Disk imaging TUI
#
# Purpose: User-friendly terminal UI for disk imaging
# Platform: Cross-platform (macOS, Linux)
# Repository: https://github.com/ifd3f/caligula
#
# Features:
#   - Terminal-based disk imaging interface
#   - USB drive and disk imaging
#   - Read/write disk images
#   - User-friendly TUI (Terminal User Interface)
#   - Lightweight and fast
#
# Use Cases:
#   - Creating bootable USB drives
#   - Disk imaging for backups
#   - Writing ISO files to USB
#   - Disk cloning
#
# Installation: Via nixpkgs (cross-platform)
#
# Note: This is a disk imaging tool, not a container manager
#
# Sources:
#   - https://github.com/ifd3f/caligula
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.caligula];

  # Shell aliases
  home.shellAliases = {
    cali = "caligula";
  };
}
