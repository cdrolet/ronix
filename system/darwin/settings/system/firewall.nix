# macOS Application Firewall Configuration
#
# Purpose: Configure macOS application layer firewall for network security
# Source: Migrated from ~/project/dotfiles/scripts/sh/darwin/system.sh (spec 002, item 3)
# Spec: 009-nvram-firewall-security (User Story 1 - Priority P1)
#
# Configuration:
#   - Enable application firewall (globalstate=1)
#   - Enable stealth mode (no response to ICMP/port scans)
#   - Disable firewall logging (reduce log noise)
#
# Method: Uses socketfilterfw command (recommended for macOS Sequoia 15+)
# Note: Direct plist manipulation via system.defaults.alf.* is deprecated/unreliable
#
# Security Impact:
#   - Prevents unauthorized network access
#   - Stealth mode prevents network reconnaissance
#   - Firewall prompts user when applications need network access
#
# Idempotency: All operations check current state before applying changes
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Firewall configuration via activation script
  # Uses socketfilterfw instead of system.defaults.alf (which is unreliable on recent macOS)

  system.activationScripts.configureFirewall = {
    text = ''
      echo "──────────────────────────────────────"
      echo "Configuring macOS Application Firewall"
      echo "──────────────────────────────────────"

      SOCKETFILTERFW="/usr/libexec/ApplicationFirewall/socketfilterfw"

      # Verify socketfilterfw exists
      if [[ ! -x "$SOCKETFILTERFW" ]]; then
        echo "✗ ERROR: socketfilterfw not found at $SOCKETFILTERFW" >&2
        echo "  This should not happen on macOS. Please report this issue." >&2
        exit 0  # Non-blocking error
      fi

      # Enable firewall (idempotent)
      echo "Checking firewall state..."
      CURRENT_STATE=$($SOCKETFILTERFW --getglobalstate)
      if echo "$CURRENT_STATE" | grep -q "Firewall is enabled"; then
        echo "  ✓ Firewall already enabled"
      else
        echo "  → Enabling firewall..."
        if $SOCKETFILTERFW --setglobalstate on 2>&1; then
          echo "  ✓ Firewall enabled successfully"
        else
          echo "  ✗ Failed to enable firewall" >&2
          exit 0  # Non-blocking error
        fi
      fi

      # Enable stealth mode (idempotent)
      echo "Checking stealth mode..."
      STEALTH_STATE=$($SOCKETFILTERFW --getstealthmode)
      if echo "$STEALTH_STATE" | grep -q "Stealth mode enabled"; then
        echo "  ✓ Stealth mode already enabled"
      else
        echo "  → Enabling stealth mode..."
        if $SOCKETFILTERFW --setstealthmode on 2>&1; then
          echo "  ✓ Stealth mode enabled successfully"
        else
          echo "  ✗ Failed to enable stealth mode" >&2
          exit 0  # Non-blocking error
        fi
      fi

      # Disable logging (idempotent)
      echo "Checking logging mode..."
      LOGGING_STATE=$($SOCKETFILTERFW --getloggingmode)
      if echo "$LOGGING_STATE" | grep -q "disabled"; then
        echo "  ✓ Logging already disabled"
      else
        echo "  → Disabling logging..."
        if $SOCKETFILTERFW --setloggingmode off 2>&1; then
          echo "  ✓ Logging disabled successfully"
        else
          echo "  ✗ Failed to disable logging" >&2
          exit 0  # Non-blocking error
        fi
      fi

      # Reload firewall daemon to ensure changes take effect
      echo "Reloading firewall daemon..."
      if pkill -HUP socketfilterfw 2>/dev/null; then
        echo "  ✓ Firewall daemon reloaded"
      else
        echo "  ℹ Firewall daemon reload signal sent (may not be running)"
      fi

      echo ""
      echo "Firewall configuration summary:"
      echo "  Global state: $($SOCKETFILTERFW --getglobalstate)"
      echo "  Stealth mode: $($SOCKETFILTERFW --getstealthmode)"
      echo "  Logging mode: $($SOCKETFILTERFW --getloggingmode)"
      echo "──────────────────────────────────────"
    '';
  };
}
