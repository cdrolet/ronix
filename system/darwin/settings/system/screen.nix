{
  config,
  lib,
  pkgs,
  ...
}: {
  # Screen/Display Settings
  #
  # Purpose: Configure screenshots, display resolution, and screen behavior
  # Migrated from ~/project/dotfiles/scripts/sh/darwin/system.sh (HiDPI)
  #
  # Options:
  #   - location: Where to save screenshots
  #   - type: Screenshot file format (png, jpg, pdf, etc.)
  #   - disable-shadow: Disable shadow in window screenshots
  #
  # Examples:
  #   # Save PNG screenshots to Pictures folder without shadows
  #   system.defaults.screencapture.location = "~/Pictures/Screenshots";
  #   system.defaults.screencapture.type = "png";
  #   system.defaults.screencapture.disable-shadow = true;
  #
  # Source: spec 008-complete-unresolved-migration (User Story 2)
  # Parent: spec 002-darwin-system-restructure (unresolved item #5)

  system.defaults.screencapture = {
    location = lib.mkDefault "~/Desktop"; # Save to desktop
    type = lib.mkDefault "png";
    disable-shadow = lib.mkDefault true; # Disable shadow in screenshots
  };

  # Additional screen settings
  system.defaults.NSGlobalDomain = {
    AppleFontSmoothing = lib.mkDefault 2; # Enable subpixel font rendering
  };

  # Enable HiDPI display modes for external displays
  #
  # SUDO REQUIREMENT: Modifies /Library/Preferences/ (system-wide preference)
  # Assumes darwin-rebuild switch runs with appropriate privileges
  #
  # EFFECT TIMING: Takes effect after logout/reboot (requires WindowServer restart)
  # No immediate impact on current session
  #
  # PURPOSE: Enables Retina-like scaled resolutions for non-Apple displays
  # Adds additional "Scaled" resolution options in System Settings > Displays
  # Only beneficial when external display is connected
  # No negative impact on built-in displays
  #
  # IDEMPOTENCY: Checks current value before writing (read-before-write pattern)
  # Safe to run multiple times without unnecessary disk writes
  system.activationScripts.enableHiDPI = {
    text = ''
      echo "Configuring HiDPI display modes..."

      # Check if HiDPI is already enabled
      current_value=$(defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled 2>/dev/null || echo "0")

      # Only write if not already enabled (idempotency)
      if [ "$current_value" != "1" ]; then
        if sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true 2>/dev/null; then
          echo "Enabled HiDPI display modes (takes effect after logout)"
        else
          echo "Warning: Failed to enable HiDPI display modes" >&2
        fi
      else
        echo "HiDPI display modes already enabled"
      fi
    '';
  };
}
