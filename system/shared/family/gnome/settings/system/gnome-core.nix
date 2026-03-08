# GNOME Core Desktop Environment
#
# Purpose: Enable GNOME desktop environment with core applications
# System-level configuration (NixOS)
#
# This module installs the complete GNOME desktop environment including:
# - GNOME Shell (core desktop interface)
# - GNOME Control Center (system settings)
# - GDM (GNOME Display Manager)
# - Core GNOME apps (nautilus, calculator, calendar, etc.)
#
# Platform: NixOS (uses services.xserver.* options)
# Platform-agnostic: Generic NixOS options, platform lib handles translation
#
# Dependencies:
# - NixOS system with services.xserver support
# - X11/Wayland display server (configured separately in wayland.nix)
#
# Constitutional: <200 lines, uses lib.mkDefault for user-overridability
#
# Usage:
# Automatically imported when host declares family = ["gnome"]
# No manual configuration needed - desktop installs system-wide
#
# Example override:
# {
#   services.xserver.desktopManager.gnome.enable = lib.mkForce false;
# }
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable X server (required for GDM)
  services.xserver.enable = lib.mkDefault true;

  # Enable GNOME desktop environment (system-level)
  # This installs GNOME Shell, Control Center, and display manager
  # Note: Renamed from services.xserver.desktopManager.gnome in NixOS 24.11+
  services.desktopManager.gnome = {
    enable = lib.mkDefault true;
  };

  # GDM (GNOME Display Manager) - system-level login
  # Note: Renamed from services.xserver.displayManager.gdm in NixOS 24.11+
  services.displayManager.gdm = {
    enable = lib.mkDefault true;
    # Disable auto-suspend to prevent SSH connection issues in VMs
    # This matches NixOS ISO behavior for better VM experience
    autoSuspend = lib.mkDefault false;
  };

  # Enable GNOME core applications (nautilus, calculator, etc.)
  # Includes essential desktop utilities
  services.gnome = {
    core-apps.enable = lib.mkDefault true;

    # Developer tools: dconf-editor, devhelp, d-spy, gnome-builder, sysprof
    # Disabled by default - most users don't need development tools
    core-developer-tools.enable = lib.mkDefault false;

    # GNOME games collection (19+ games)
    # Disabled by default to reduce system size
    games.enable = lib.mkDefault false;
  };

  # Enable GNOME keyring services
  # Required for desktop integration and user experience
  services.gnome.gnome-keyring.enable = lib.mkDefault true;

  # GNOME Shell extensions — user-theme required by Stylix for shell theming
  environment.systemPackages = [ pkgs.gnome-shell-extensions ];

  # Exclude unwanted GNOME packages from default installation
  # Reduces system size and removes rarely-used applications
  environment.gnome.excludePackages = lib.mkDefault (with pkgs; [
    # Remove getting started tour (not needed after first use)
    gnome-tour

    # Remove user documentation (available online at wiki.gnome.org)
    gnome-user-docs

    # Remove GNOME Web browser (users typically install Firefox/Chrome)
    epiphany

    # Optional: Add more packages to exclude here
    # Examples:
    snapshot # GNOME Camera (not needed on desktops/VMs)
    gnome-music # If using different music player
    simple-scan # If not using scanner

    # gnome-photos     # If using different photo manager
  ]);
}
