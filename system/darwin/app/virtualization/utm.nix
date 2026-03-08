# UTM - Virtual Machine Manager
#
# Purpose: macOS virtualization using QEMU and Apple's Virtualization.framework
# Platform: Darwin only (macOS)
# Website: https://mac.getutm.app/
#
# Features:
#   - Run Windows, Linux, and other OS on macOS
#   - Supports both emulation (x86 on ARM) and virtualization (ARM on ARM)
#   - Uses Apple's Virtualization.framework for better performance
#   - Rosetta for Linux: run x86_64 binaries in ARM Linux VMs
#   - Simple GUI interface
#
# Installation: Via Homebrew cask (GUI application)
{
  config,
  lib,
  configContext ? "home-manager",
  ...
}: let
  isVM = config.host.virtualMachine or false;
in
  lib.mkMerge [
    # Homebrew cask installation (darwin system context only, skip in VMs)
    (lib.optionalAttrs (configContext == "darwin-system" && !isVM) {
      homebrew.casks = ["utm"];
      # Enable Rosetta 2 for x86_64 translation
      # Required for Rosetta in Linux VMs via UTM's Apple Virtualization backend
      system.rosetta.enable = lib.mkDefault true;
    })

    # Configuration (home-manager context)
    {
      # No additional home-manager configuration needed
      # UTM is configured through its GUI
    }
  ]
