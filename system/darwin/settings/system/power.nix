# Power Management Configuration Module
#
# Configures macOS power management settings via pmset activation scripts.
# Migrated from ~/project/dotfiles/scripts/sh/darwin/system.sh
#
# Source: spec 008-complete-unresolved-migration (User Story 1)
# Parent: spec 002-darwin-system-restructure (unresolved item #2)
#
# Settings configured:
# - standbydelay: Time before entering standby mode (24 hours = 86400 seconds)
#
# References:
# - man pmset: Power Management Settings utility
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Power management configuration via activation script
  #
  # SUDO REQUIREMENT: pmset commands require root privileges
  # Assumes darwin-rebuild switch runs with appropriate privileges
  #
  # IDEMPOTENCY: Checks current value before setting
  # Safe to run multiple times without unnecessary NVRAM writes
  system.activationScripts.configurePower = {
    text = ''
      echo "Configuring power management settings..."

      # Set standby delay to 24 hours (86400 seconds)
      # Purpose: Prevents Mac from entering standby during normal idle periods
      # Standby is a deep sleep mode that reduces power but takes longer to wake
      # Default standby delay is often too short for typical usage patterns
      # Applies to all power sources (-a flag: battery, AC, UPS)

      # Check current pmset value for standbydelay (idempotent)
      current=$(pmset -g | grep "^ standbydelay" | awk '{print $2}' 2>/dev/null)

      # Only set if different (avoids unnecessary NVRAM writes)
      if [ "$current" != "86400" ]; then
        if sudo pmset -a standbydelay 86400 2>/dev/null; then
          echo "pmset: Set standbydelay to 86400 (scope: -a)"
        else
          echo "Warning: Failed to set pmset standbydelay" >&2
        fi
      else
        echo "pmset: standbydelay already set to 86400"
      fi
    '';
  };
}
