# Darwin Auto-Update Agent
#
# Purpose: Automatically run `just fresh-install` on a schedule or at login
# Platform: macOS / launchd user agents
# Context: Home-manager (user-level settings, Feature 039)
#
# Reads host.updateSystemFrequency to create a ~/Library/LaunchAgents/ plist:
#   - "on-boot":          runs once at each login (RunAtLoad = true)
#   - "daily" / "weekly": runs on a calendar schedule (3 AM / Sunday 3 AM)
#
# Log output: ~/.local/share/nix-config/auto-update.log
#
# Note: darwin-rebuild switch requires sudo. For unattended operation add
# to /etc/sudoers (or /private/etc/sudoers.d/nix-auto-update):
#   %admin ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild
{
  config,
  lib,
  pkgs,
  ...
}: let
  freq = config.host.updateSystemFrequency;
  hasAutoUpdate = freq != null;

  configDir = "${config.home.homeDirectory}/.config/nix-config";
  logFile = "${config.home.homeDirectory}/.local/share/nix-config/auto-update.log";

  # Self-contained update script: creates log dir, redirects output, runs update
  # launchd captures stdout/stderr via StandardOutPath but the script also
  # redirects so the log path is consistent regardless of how it is invoked.
  updateScript = pkgs.writeShellScript "nix-config-auto-update" ''
    set -euo pipefail

    LOG="${logFile}"
    mkdir -p "$(dirname "$LOG")"
    exec >> "$LOG" 2>&1

    echo ""
    echo "=== $(date -Iseconds) Auto-update started ==="

    if [ ! -d "${configDir}" ]; then
      echo "Error: root flake not found at ${configDir}"
      echo "Expected nix config flake checkout at ~/.config/nix-config"
      exit 1
    fi

    cd "${configDir}"
    ${pkgs.just}/bin/just fresh-install

    echo "=== $(date -Iseconds) Auto-update complete ==="
  '';

  # launchd StartCalendarInterval for scheduled modes
  # Daily: every day at 03:00; Weekly: every Sunday at 03:00
  calendarInterval = {
    "daily" = [{Hour = 3; Minute = 0;}];
    "weekly" = [{Weekday = 0; Hour = 3; Minute = 0;}];
  };
in lib.mkIf hasAutoUpdate {
  # just is a runtime dependency of the update script
  home.packages = [pkgs.just];

  launchd.agents.nix-config-auto-update = {
    enable = true;
    config =
      {
        Label = "com.nix-config.auto-update";
        # bash -l sources /etc/profile → full nix PATH (nix, darwin-rebuild, home-manager)
        ProgramArguments = ["${pkgs.bash}/bin/bash" "-l" "${updateScript}"];
        RunAtLoad = freq == "on-boot";
        # Prevent overlapping runs if a previous one is still going
        ProcessType = "Background";
      }
      // lib.optionalAttrs (freq != "on-boot") {
        StartCalendarInterval = calendarInterval.${freq};
      };
  };
}
