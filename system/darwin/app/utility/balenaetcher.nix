# balenaEtcher - USB/SD card image writer
#
# Purpose: Flash OS images to SD cards & USB drives
# Platform: Cross-platform (macOS, Linux, Windows)
# Website: https://www.balena.io/etcher/
# Homebrew-only app: cask installed via darwin.nix extraction
# No home-manager configuration needed
{
  lib,
  configContext ? "home-manager",
  ...
}:
lib.optionalAttrs (configContext == "darwin-system") {
  homebrew.casks = ["balenaetcher"];
}
