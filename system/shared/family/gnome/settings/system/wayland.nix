# GNOME Wayland Configuration
#
# Purpose: Enable Wayland display server for GNOME desktop
# System-level configuration (NixOS)
#
# This module enables Wayland session support in GDM and sets environment
# variables for proper Wayland integration with applications.
#
# Wayland benefits:
# - Better performance and security
# - Modern graphics stack
# - Improved multi-monitor support
# - Native high-DPI support
#
# Platform: NixOS (uses services.xserver.displayManager.gdm.wayland)
# Platform-agnostic: Generic NixOS option
#
# Dependencies:
# - desktop/gnome-core.nix (GDM must be enabled)
# - services.xserver.displayManager.gdm.enable = true
#
# Constitutional: <200 lines, uses lib.mkDefault
#
# Usage:
# Automatically imported when host declares family = ["gnome"]
# Wayland enabled by default for better performance
#
# To disable Wayland and use X11:
# {
#   services.xserver.displayManager.gdm.wayland = lib.mkForce false;
# }
#
# Verification:
# After login, check session type: echo $XDG_SESSION_TYPE
# Should output: wayland
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable Wayland session in GDM
  # Users can still select X11 session at login if needed
  # Note: Renamed from services.xserver.displayManager.gdm in NixOS 24.11+
  services.displayManager.gdm = {
    wayland = lib.mkDefault true;
  };

  # Enable Wayland support for Electron-based applications
  # This allows Chrome, VSCode, and other Electron apps to use Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = lib.mkDefault "1";
  };
}
