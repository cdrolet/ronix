{
  config,
  lib,
  pkgs,
  ...
}: let
  # Read user docked apps
  dockedApps = (config.user.workspace or {}).docked or [];
  hasDocked = dockedApps != [];
  # Stylix base16 colors (no # prefix)
  c = config.lib.stylix.colors;
in {
  # Install and configure Waybar
  programs.waybar = {
    enable = lib.mkDefault true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;

        # Module layout
        modules-left = ["niri/workspaces" "niri/window"];
        modules-center = lib.mkIf hasDocked ["custom/favorites"];
        modules-right = ["tray" "clock"];

        # Niri workspaces module
        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
          };
        };

        # Current window title
        "niri/window" = {
          format = "{title}";
          max-length = 50;
          rewrite = {
            "(.*) — Mozilla Firefox" = "🌎 $1";
            "(.*) - Ghostty" = " $1";
          };
        };

        # System tray
        tray = {
          spacing = 10;
        };

        # Clock
        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%Y-%m-%d}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#${c.base09}'><b>{}</b></span>";
              days = "<span color='#${c.base0F}'><b>{}</b></span>";
              weeks = "<span color='#${c.base0B}'><b>W{}</b></span>";
              weekdays = "<span color='#${c.base0A}'><b>{}</b></span>";
              today = "<span color='#${c.base08}'><b><u>{}</u></b></span>";
            };
          };
        };
      };
    };

    # Waybar styling using stylix base16 colors
    # E6 = ~90% opacity, 4D = ~30% opacity (hex alpha suffix)
    style = ''
      * {
        font-family: monospace;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: #${c.base00}E6;
        color: #${c.base05};
        border-bottom: 2px solid #${c.base0D};
      }

      #workspaces {
        margin: 0 4px;
      }

      #workspaces button {
        padding: 0 8px;
        background: transparent;
        color: #${c.base05};
        border: none;
        border-radius: 0;
      }

      #workspaces button.active {
        background: #${c.base0D}4D;
        color: #${c.base0D};
      }

      #workspaces button.urgent {
        background: #${c.base08}4D;
        color: #${c.base08};
      }

      #window {
        padding: 0 10px;
        color: #${c.base05};
      }

      #tray {
        padding: 0 10px;
      }

      #clock {
        padding: 0 10px;
        color: #${c.base0D};
        font-weight: bold;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #${c.base08};
      }
    '';
  };
}
