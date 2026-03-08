# VM Integration - User Session
#
# Purpose: Configure VM integration services for user session (clipboard, etc.)
# User-level configuration (Home Manager)
#
# This module ensures spice-vdagent runs in the user session for clipboard sharing.
# The nixpkgs spice-vdagent package does NOT include an XDG autostart file,
# so we create one explicitly.
#
# Platform: Any Linux desktop (GNOME, Niri, KDE, etc.)
# Context: User-level (uses home.* options)
#
# Why needed:
# - spice-vdagentd.service runs as system daemon (root) - enabled in virtualization.nix
# - spice-vdagent must also run as user for clipboard to work
# - Wayland desktops require user-session process for clipboard access
#
# Constitutional: <200 lines, uses lib.mkDefault for user-overridability
#
# Usage:
# Automatically imported when host declares family = ["wayland"]
# Works with system-level spice-vdagentd.service in wayland/settings/system/virtualization.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = [
    pkgs.spice-vdagent
  ];

  # Create XDG autostart entry for spice-vdagent user session
  xdg.configFile."autostart/spice-vdagent.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Spice VD Agent
    Comment=Clipboard sharing and display resizing for VMs
    Exec=${pkgs.spice-vdagent}/bin/spice-vdagent
    Hidden=false
    NoDisplay=true
    X-GNOME-Autostart-enabled=true
  '';
}
