# Window Borders - Active window border highlighting for macOS
# Adds colored border around active window, useful with tiling window managers
# Implementation: JankyBorders (FelixKratz/borders)
#
# System-level setting - applies to all users
# Works well with: aerospace (tiling window manager)
#
# Homebrew installation (tap + brew) is in settings/system/window-borders.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Launch borders with configuration
  # Using launchd to start borders on login with color and width settings
  launchd.agents.borders = {
    enable = true;
    config = {
      ProgramArguments = [
        "/opt/homebrew/bin/borders"
        "active_color=0xffe1e3e4"
        "inactive_color=0xff494d64"
        "width=5.0"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/borders.log";
      StandardErrorPath = "/tmp/borders.err";
    };
  };
}
