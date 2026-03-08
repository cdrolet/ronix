{
  config,
  lib,
  pkgs,
  ...
}: {
  # Trackpad Settings
  #
  # Purpose: Configure macOS trackpad gestures, clicking, and behavior
  #
  # Options:
  #   - Clicking: Enable tap to click
  #   - TrackpadRightClick: Enable two-finger right-click
  #   - TrackpadThreeFingerDrag: Enable three-finger drag
  #
  # Examples:
  #   # Enable tap to click
  #   system.defaults.trackpad.Clicking = true;

  system.defaults.trackpad = {
    Clicking = lib.mkDefault true; # Tap to click
    TrackpadRightClick = lib.mkDefault true; # Two-finger right-click
    TrackpadThreeFingerDrag = lib.mkDefault false;
  };

  # Additional trackpad settings via NSGlobalDomain
  system.defaults.NSGlobalDomain = {
    "com.apple.mouse.tapBehavior" = lib.mkDefault 1; # Enable tap to click globally
    "com.apple.trackpad.enableSecondaryClick" = lib.mkDefault true; # Enable secondary click
  };
}
