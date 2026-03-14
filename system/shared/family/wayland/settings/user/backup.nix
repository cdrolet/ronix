# Linux Backup Service
#
# Purpose: Run nix-backup on a schedule via systemd user service + timer
# Platform: Linux / systemd user services
# Context: Home-manager (user-level settings, Feature 039)
#
# Reads user.backup.schedule to create:
#   - "daily":  systemd timer, runs daily at 02:00 (persistent, 10min jitter)
#   - "weekly": systemd timer, runs every Sunday at 02:00 (persistent)
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

  calendarSpec = {
    "daily" = "daily";
    "weekly" = "weekly";
  };

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
in
  lib.mkIf (hasBackup && hasSchedule) {
    systemd.user.services.nix-config-backup = {
      Unit = {
        Description = "Restic backup to Backblaze B2";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -l ${backupScript}";
      };
    };

    systemd.user.timers.nix-config-backup = {
      Unit.Description = "Timer for Restic backup to Backblaze B2";
      Timer = {
        OnCalendar = calendarSpec.${freq};
        # Run missed backups on next boot (e.g. machine was off at scheduled time)
        Persistent = true;
        # Spread load — avoid exact same second as other timers
        RandomizedDelaySec = "10min";
      };
      Install.WantedBy = ["timers.target"];
    };
  }
