# GNOME Family: Dash to Panel Extension
#
# Purpose: Combine top bar and dock into a single bottom taskbar,
#          similar to waybar/polybar on wlroots compositors.
# Extension UUID: dash-to-panel@jderose9.github.com
# Note: Extension must be listed in extensions.nix enabled-extensions
{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = [ pkgs.gnomeExtensions.dash-to-panel ];

  dconf.settings = {
    "org/gnome/shell/extensions/dash-to-panel" = {
      # Single bottom panel (waybar-style)
      panel-positions = lib.mkDefault ''{"0":"BOTTOM"}'';
      panel-sizes = lib.mkDefault ''{"0":40}'';

      # Taskbar: show favorites + running apps
      show-favorites = lib.mkDefault true;
      show-running-apps = lib.mkDefault true;
      group-apps = lib.mkDefault true;

      # Running app indicator dots
      dot-style-focused = lib.mkDefault "DOTS";
      dot-style-unfocused = lib.mkDefault "DOTS";

      # Hover previews
      show-tooltip = lib.mkDefault true;

      # Hide app menu (redundant with taskbar)
      show-appmenu = lib.mkDefault false;
    };
  };
}
