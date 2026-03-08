# Dock Configuration Module
#
# Dock configuration using user-defined dock layout from user.workspace.docked field.
# Uses helper library functions from lib/dock.nix for declarative, idempotent configuration.
#
# Feature: 023-user-dock-config
# Source: spec 007-complete-dock-migration (original), spec 023-user-dock-config (refactor)
#
# The dock layout is now defined in user configuration:
#   user.workspace.docked = [ "zen" "brave" "|" "zed" "/Downloads" ];
#
# If user.workspace.docked is empty or not specified, dock configuration is unchanged.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Import darwin dock helper library
  dockLib = import ../../lib/dock.nix {inherit pkgs lib;};

  # Feature 036: Access user config directly from schema
  userConfig = config.user or {};
  primaryUser = userConfig.name or "charles";

  # Get user's docked configuration (empty list if not specified)
  userDocked = (userConfig.workspace or {}).docked or [];

  # Check if user has defined dock items
  hasDockConfig = userDocked != [];
in {
  # Dock preferences via nix-darwin (13 settings)
  # These apply regardless of dock items configuration
  system.defaults.dock = {
    show-recents = false; # Disable recent apps
    show-process-indicators = true; # Show indicator lights for running apps
    launchanim = false; # Disable app opening animations
    autohide-delay = 0.0; # Remove auto-hide delay
    autohide-time-modifier = 0.0; # Remove auto-hide animation time
    autohide = true; # Enable auto-hide Dock
    showhidden = true; # Make hidden apps translucent
    mineffect = "scale"; # Set minimize animation to scale
    tilesize = 36; # Set Dock icon size to 36px
    minimize-to-application = true; # Minimize windows into app icon
    expose-animation-duration = 0.1; # Speed up Mission Control animations
    expose-group-apps = false; # Don't group windows by application in Mission Control
    mru-spaces = false; # Don't automatically rearrange Spaces
  };

  # Dock items via activation script - only if user has defined docked items
  system.activationScripts.configureDock = lib.mkIf hasDockConfig {
    text = ''
      # Additional Dock preferences not available in nix-darwin (2 settings)
      defaults write com.apple.dock mouse-over-hilite-stack -bool true
      defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

      # Clear existing Dock items
      ${dockLib.mkDockClear}

      # Add dock items from user configuration
      ${dockLib.mkDockFromUserConfig userDocked primaryUser}

      # Restart Dock to apply all changes
      ${dockLib.mkDockRestart}
    '';
  };
}
