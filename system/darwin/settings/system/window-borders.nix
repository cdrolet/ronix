# Window Borders - Homebrew installation
# Installs JankyBorders (FelixKratz/borders) via Homebrew tap
# User-level configuration (launchd agent) is in settings/user/window-borders.nix
{
  config,
  lib,
  ...
}: {
  homebrew.taps = ["FelixKratz/formulae"];
  homebrew.brews = ["borders"];
}
