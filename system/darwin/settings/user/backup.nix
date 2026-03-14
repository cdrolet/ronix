# Darwin Backup Agent
#
# Purpose: Run nix-backup on a schedule via launchd user agent
# Platform: macOS / launchd user agents
# Context: Home-manager (user-level settings, Feature 039)
#
# Reads user.backup.schedule to create a ~/Library/LaunchAgents/ plist:
#   - "daily":  every day at 02:00 (1 hour before auto-update at 03:00)
#   - "weekly": every Sunday at 02:00
#
# Requires: backup.nix (shared) to have installed ~/.local/bin/nix-backup
# Log output: ~/.local/share/nix-config/backup.log
{
  config,
  lib,
  pkgs,
  ...
}: let
  backupCfg = config.user.backup or null;
  hasBackup = backupCfg != null;
  freq = if hasBackup then (backupCfg.schedule or null) else null;
  hasSchedule = freq != null;

  home = config.home.homeDirectory;
  logFile = "${home}/.local/share/nix-config/backup.log";
  backupBin = "${home}/.local/bin/nix-backup";

  backupScript = pkgs.writeShellScript "nix-config-backup" ''
    set -euo pipefail

    LOG="${logFile}"
    mkdir -p "$(dirname "$LOG")"
    exec >> "$LOG" 2>&1

    echo ""
    echo "=== $(date -Iseconds) Backup started ==="

    ${backupBin}

    echo "=== $(date -Iseconds) Backup complete ==="
  '';

  calendarInterval = {
    "daily" = [{Hour = 2; Minute = 0;}];
    "weekly" = [{Weekday = 0; Hour = 2; Minute = 0;}];
  };
in
  lib.mkIf (hasBackup && hasSchedule) {
    launchd.agents.nix-config-backup = {
      enable = true;
      config = {
        Label = "com.nix-config.backup";
        # bash -l sources /etc/profile → full nix PATH
        ProgramArguments = ["${pkgs.bash}/bin/bash" "-l" "${backupScript}"];
        RunAtLoad = false;
        ProcessType = "Background";
        StartCalendarInterval = calendarInterval.${freq};
      };
    };
  }
