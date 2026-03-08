{
  config,
  lib,
  pkgs,
  ...
}: {
  # Homebrew Package Manager
  #
  # Enable nix-darwin's homebrew module for managing macOS packages
  # Individual packages are declared in other settings modules (e.g., aerospace.nix, window-borders.nix)
  #
  # This module only handles the global homebrew configuration.

  # Enable homebrew integration
  homebrew.enable = true;

  # Automatically run brew cleanup on activation
  homebrew.onActivation.cleanup = lib.mkDefault "zap";

  # Auto-update homebrew and packages
  homebrew.onActivation.autoUpdate = lib.mkDefault true;
  homebrew.onActivation.upgrade = lib.mkDefault true;
}
