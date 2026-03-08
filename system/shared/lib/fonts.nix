# Font Helper Library
#
# Purpose: Font package resolution and private font placeholder derivations
# Feature: 030-user-font-config
# Platform: Cross-platform
#
# Provides utilities for:
# - Translating font family names to nixpkgs package names
# - Creating placeholder derivations for private fonts (stylix compatibility)
#
# Private fonts are cloned at runtime via activation scripts (per-user SSH keys).
# Placeholder derivations allow stylix to reference them as packages without
# requiring build-time access to private repositories.
{lib}: let
  # Translate font family name to nixpkgs package name candidate
  # "Fira Code" -> "fira-code"
  toPackageName = name:
    lib.toLower (builtins.replaceStrings [" "] ["-"] name);

  # Try multiple naming conventions to resolve a font family to a nixpkgs package
  # Returns the package derivation or null if not found
  tryResolvePackage = pkgs: name: let
    base = toPackageName name;
    underscore = builtins.replaceStrings ["-"] ["_"] base;
    # Split on first dash to try "{first}-fonts-{rest}" pattern
    # e.g., "noto-color-emoji" → "noto-fonts-color-emoji"
    parts = lib.splitString "-" base;
    infixFonts =
      if builtins.length parts >= 2
      then (builtins.head parts) + "-fonts-" + (builtins.concatStringsSep "-" (builtins.tail parts))
      else null;
    candidates = [
      base # fira-code
      "${base}-font" # hack-font
      "${base}-fonts" # noto-fonts
      underscore # fira_code
      "${underscore}_fonts" # dejavu_fonts
    ] ++ lib.optional (infixFonts != null) infixFonts; # noto-fonts-color-emoji
    found = lib.findFirst (c: pkgs ? ${c}) null candidates;
  in
    if found != null
    then pkgs.${found}
    else null;

  # Create a placeholder font derivation for private/runtime-installed fonts
  # The derivation is empty — actual font files are deployed by activation scripts.
  # This satisfies stylix's package requirement without build-time repo access.
  mkPlaceholderFontPackage = pkgs: name:
    pkgs.runCommand "${toPackageName name}-placeholder" {} ''
      mkdir -p $out/share/fonts
    '';
in {
  inherit toPackageName tryResolvePackage mkPlaceholderFontPackage;
}
