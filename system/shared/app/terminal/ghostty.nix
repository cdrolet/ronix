# Ghostty - Modern terminal emulator
#
# Fast GPU-accelerated terminal with modern features.
# Fonts are applied automatically by stylix via programs.ghostty.settings.
#
# Installation:
#   - Darwin: Via Homebrew cask
#   - Linux: Via nixpkgs
{
  config,
  pkgs,
  lib,
  configContext ? "home-manager",
  system ? "",
  ...
}: let
  isLinux = configContext != "darwin-system" && !(lib.hasSuffix "darwin" system);
in
  lib.mkMerge [
    (lib.optionalAttrs (configContext == "darwin-system") {
      homebrew.casks = ["ghostty"];
    })

    (lib.optionalAttrs (configContext != "darwin-system") {
      programs.ghostty = {
        enable = true;
        package =
          if isLinux
          then pkgs.ghostty
          else null;
        settings = {
          # Window settings
          window-padding-x = 10;
          window-padding-y = 10;

          # Shell integration
          shell-integration = "detect";

          # Cursor
          cursor-style = "block";
          cursor-style-blink = false;

          # Mac-style copy/paste (works with Super/Ctrl swap)
          keybind = [
            "ctrl+c=copy_to_clipboard"
            "ctrl+v=paste_from_clipboard"
          ];
        };
      };

      home.sessionVariables.TERMINAL = lib.mkDefault "ghostty";

      dconf.settings."org/gnome/desktop/default-applications/terminal" = {
        exec = lib.mkDefault "ghostty";
        exec-arg = lib.mkDefault "-e";
      };
    })
  ]
