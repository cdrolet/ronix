# Wayland Clipboard Utilities
#
# Purpose: Install wl-clipboard (wl-copy / wl-paste) for Wayland sessions
# Platform: All Wayland compositors (GNOME, Niri, Hyprland, etc.)
# Context: User-level (home-manager)
#
# Provides:
#   wl-copy  — copy stdin or file to Wayland clipboard
#   wl-paste — paste Wayland clipboard to stdout
#
# These are user-space tools; no system-level package needed.
# Previously duplicated across hardware/graphics/desktop.nix and
# hardware/cpu/amd-gpu.nix — centralised here for all Wayland hosts.
{pkgs, ...}: {
  home.packages = [pkgs.wl-clipboard];
}
