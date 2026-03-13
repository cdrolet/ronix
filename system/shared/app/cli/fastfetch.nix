# fastfetch - System information tool
#
# Purpose: Display system info with stylix-themed colors
# Colors:  Applied manually from config.lib.stylix.colors (no stylix auto-target)
#          Keys and title use base0D (blue), separator uses base03 (subtle)
#
# Platform: Cross-platform (Linux, macOS)
{
  config,
  pkgs,
  lib,
  ...
}: let
  c = config.lib.stylix.colors;

  # Convert a stylix base16 hex string (e.g. "88c0d0") to fastfetch SGR truecolor
  # Fastfetch display.color accepts "38;2;R;G;B" for 24-bit foreground colors
  hexDigits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };
  hexByte = s: off:
    hexDigits.${lib.toLower (builtins.substring off 1 s)} * 16
    + hexDigits.${lib.toLower (builtins.substring (off + 1) 1 s)};
  toSGR = hex: let
    r = toString (hexByte hex 0);
    g = toString (hexByte hex 2);
    b = toString (hexByte hex 4);
  in "38;2;${r};${g};${b}";
in {
  programs.fastfetch = {
    enable = true;
    settings = {
      display = {
        separator = "  ";
        color = {
          keys = toSGR c.base0D; # blue
          title = toSGR c.base0D;
          separator = toSGR c.base03; # subtle
        };
      };
      modules = [
        "Title"
        "Separator"
        {type = "OS";}
        {type = "Host";}
        {type = "Kernel";}
        {type = "Uptime";}
        {type = "Packages";}
        {type = "Shell";}
        {type = "Terminal";}
        "Separator"
        {type = "CPU";}
        {type = "GPU";}
        {type = "Memory";}
        {type = "Disk";}
        "Separator"
        "Colors"
      ];
    };
  };

  home.shellAliases = {
    sysinfo = "${pkgs.fastfetch}/bin/fastfetch";
  };
}
