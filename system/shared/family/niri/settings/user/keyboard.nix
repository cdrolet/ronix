{
  config,
  lib,
  pkgs,
  ...
}: let
  # Import defaults resolution library
  defaults = import ../../../../../../user/lib/defaults.nix {inherit lib pkgs;};

  # Get keyboard layout from user config (use first layout if it's a list)
  keyboardConfig = (config.user.locale or {}).keyboard or null;
  keyboardLayoutRaw =
    if keyboardConfig != null
    then (keyboardConfig.layout or "us")
    else "us";
  keyboardLayout =
    if builtins.isList keyboardLayoutRaw
    then builtins.head keyboardLayoutRaw
    else keyboardLayoutRaw;
in {
  # Create Niri configuration file with keyboard shortcuts
  xdg.configFile."niri/config.kdl" = let
    # Resolve terminal and launcher lazily (after config is evaluated)
    terminal = defaults.getDefault {
      inherit config;
      name = "terminal";
      default = "${pkgs.foot}/bin/foot";
    };
    launcher = defaults.getDefault {
      inherit config;
      name = "launcher";
      default = "${pkgs.fuzzel}/bin/fuzzel";
    };
  in {
    text = ''
      // Niri configuration file
      // Keyboard shortcuts and window management

      input {
        keyboard {
          xkb {
            layout "${keyboardLayout}"
          }
        }
      }

      spawn-at-startup "${pkgs.waybar}/bin/waybar"

      layout {
        gaps 8
        center-focused-column "never"

        preset-column-widths {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
        }
      }

      binds {
        // Window management
        Mod+Q { close-window; }
        Mod+H { focus-column-left; }
        Mod+Left { focus-column-left; }
        Mod+J { focus-window-down; }
        Mod+Down { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+Up { focus-window-up; }
        Mod+L { focus-column-right; }
        Mod+Right { focus-column-right; }

        // Move windows
        Mod+Shift+H { move-column-left; }
        Mod+Shift+Left { move-column-left; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+Down { move-window-down; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+Up { move-window-up; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+Right { move-column-right; }

        // Window resizing and layout
        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+C { center-column; }

        // Workspaces
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }

        // Move windows to workspaces
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }

        // Application launching (uses first available from user.default)
        Mod+Return { spawn "${terminal}"; }
        Mod+Space { spawn "${launcher}"; }
        Mod+D { spawn "${launcher}"; }

        // System controls
        Mod+Shift+E { quit; }
        Mod+Shift+P { power-off-monitors; }

        // Screenshots (if available)
        Print { spawn "screenshot"; }
      }
    '';
  };
}
