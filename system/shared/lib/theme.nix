# Helper Library: Theme Color Alias Resolution
#
# Purpose: Map friendly color names to base16 identifiers for stylix
# Usage: Imported by system/shared/settings/user/theme.nix
# Platform: Cross-platform (macOS, Linux)
#
# Provides:
#   aliasToBase16 - mapping of friendly names → base16 names
#   resolveColorName - resolve a single alias or base16 name to base16 name
#   resolveColors - convert mixed alias/base16 attrs to pure base16 attrs
#   resolveScheme - convert theme name to base16-schemes file path
{ lib, pkgs }:

let
  # Friendly color name → base16 identifier mapping
  aliasToBase16 = {
    background = "base00";
    foreground = "base05";
    black = "base00";
    white = "base07";
    red = "base08";
    orange = "base09";
    yellow = "base0A";
    green = "base0B";
    cyan = "base0C";
    blue = "base0D";
    purple = "base0E";
    magenta = "base0E";
    brown = "base0F";
  };

  # Valid base16 names (base00 through base0F)
  validBase16Names = map (n: "base0${n}") [
    "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "A" "B" "C" "D" "E" "F"
  ];

  # Resolve a single color key to its base16 name
  resolveKey = key:
    if builtins.elem key validBase16Names then key
    else aliasToBase16.${key} or (throw "Unknown color alias: ${key}. Use base16 names (base00-base0F) or aliases: ${builtins.concatStringsSep ", " (builtins.attrNames aliasToBase16)}");

  # Strip leading # from hex color value
  stripHash = value:
    if lib.hasPrefix "#" value then lib.removePrefix "#" value else value;

in {
  inherit aliasToBase16;

  # Resolve a single color name (alias or base16) to its base16 identifier
  # "background" → "base00", "base0D" → "base0D", "red" → "base08"
  resolveColorName = resolveKey;

  # Convert mixed alias/base16 color attrs to pure base16 attrs for stylix.override
  # Example: { background = "#2e3440"; red = "#bf616a"; base02 = "#4c566a"; }
  #       → { base00 = "2e3440"; base08 = "bf616a"; base02 = "4c566a"; }
  resolveColors = colors:
    lib.mapAttrs' (key: value:
      lib.nameValuePair (resolveKey key) (stripHash value)
    ) colors;

  # Convert a theme name to a base16-schemes file path
  # "Nord" → "${pkgs.base16-schemes}/share/themes/nord.yaml"
  # "Catppuccin Mocha" → "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml"
  resolveScheme = name:
    let
      normalized = lib.toLower (builtins.replaceStrings [" "] ["-"] name);
    in "${pkgs.base16-schemes}/share/themes/${normalized}.yaml";
}
