{
  config,
  lib,
  pkgs,
  ...
}: {
  # System-Wide Settings
  #
  # Purpose: Configure general system behavior, text substitutions, and global preferences

  # Disable nix-darwin's Nix daemon management to avoid conflicts with
  # Determinate Nix or other standalone Nix installers
  nix.enable = lib.mkDefault false;
  #
  # Options:
  #   - NSAutomaticCapitalizationEnabled: Auto-capitalize words
  #   - NSAutomaticDashSubstitutionEnabled: Auto-substitute dashes
  #   - NSAutomaticPeriodSubstitutionEnabled: Add period with double-space
  #   - NSAutomaticQuoteSubstitutionEnabled: Use smart quotes
  #   - NSAutomaticSpellingCorrectionEnabled: Auto-correct spelling
  #
  # Examples:
  #   # Disable all automatic text substitutions
  #   system.defaults.NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
  #   system.defaults.NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;

  system.defaults.NSGlobalDomain = {
    # Disable automatic text substitutions
    NSAutomaticCapitalizationEnabled = lib.mkDefault false;
    NSAutomaticDashSubstitutionEnabled = lib.mkDefault false;
    NSAutomaticPeriodSubstitutionEnabled = lib.mkDefault false;
    NSAutomaticQuoteSubstitutionEnabled = lib.mkDefault false;
    NSAutomaticSpellingCorrectionEnabled = lib.mkDefault false;

    # Show all file extensions (duplicated in finder for clarity)
    AppleShowAllExtensions = lib.mkDefault true;
  };

  # Additional system preferences via CustomUserPreferences
  system.defaults.CustomUserPreferences = {
    # LaunchServices settings
    "com.apple.LaunchServices" = {
      LSQuarantine = lib.mkDefault false; # Disable open confirmation dialog for downloaded apps
    };

    # Global system behavior (use NSGlobalDomain — nix-darwin doesn't
    # shell-escape the domain, so spaces in "Apple Global Domain" break defaults)
    "NSGlobalDomain" = {
      NSQuitAlwaysKeepsWindows = lib.mkDefault false; # Disable resume system-wide
    };
  };
}
