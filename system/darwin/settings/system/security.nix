# Security & Privacy Configuration
#
# Purpose: Configure security settings, access control, and network identity
# Source: Migrated from ~/project/dotfiles/scripts/sh/darwin/system.sh (spec 002, item 4)
# Spec: 009-nvram-firewall-security (User Story 2 - Priority P2)
#
# Configuration:
#   - Disable guest account (prevents unauthenticated access)
#   - Set per-host NetBIOS hostname for SMB/CIFS network identification
#
# Security Impact:
#   - Guest account disabled prevents unauthorized local access
#   - Custom hostname improves network identification and security policies
#
# Idempotency: All operations check current state before applying changes
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  #
  # Configuration
  #

  config = {
    # Screen saver and security settings
    system.defaults.screensaver = {
      askForPassword = mkDefault true; # Require password after screen saver
      askForPasswordDelay = mkDefault 0; # Immediate password prompt
    };

    # Guest account (use nix-darwin's built-in option)
    system.defaults.loginwindow = {
      GuestEnabled = mkDefault false; # Disable guest account for security
    };

    # Privacy settings
    system.defaults.CustomUserPreferences = {
      "com.apple.CrashReporter" = {
        DialogType = mkDefault "none"; # Disable crash reporter dialog
      };
    };
  };
}
