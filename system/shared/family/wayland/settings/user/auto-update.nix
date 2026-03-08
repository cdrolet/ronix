# Linux Auto-Update Service
#
# Purpose: Automatically run `just fresh-install` on a schedule or at boot
# Platform: Linux / systemd user services
# Context: Home-manager (user-level settings, Feature 039)
#
# Reads host.updateSystemFrequency to create:
#   - "on-boot":          systemd user service, starts at login
#   - "daily" / "weekly": systemd user timer + service (3 AM, persistent)
#
# Log output: ~/.local/share/nix-config/auto-update.log
#
# Note: System-level activation (nixos-rebuild switch) requires passwordless sudo.
# Add to /etc/sudoers:
#   %wheel ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
{
  config,
  lib,
  pkgs,
  ...
}: let
  freq = config.host.updateSystemFrequency;
  hasAutoUpdate = freq != null;
  isScheduled = hasAutoUpdate && freq != "on-boot";

  configDir = "${config.home.homeDirectory}/.config/nix-config";
  logFile = "${config.home.homeDirectory}/.local/share/nix-config/auto-update.log";

  # Map host frequency to systemd OnCalendar spec
  calendarSpec = {
    "daily" = "daily";
    "weekly" = "weekly";
  };

  # Self-contained update script: creates log dir, redirects output, runs update
  updateScript = pkgs.writeShellScript "nix-config-auto-update" ''
    set -euo pipefail

    LOG="${logFile}"
    mkdir -p "$(dirname "$LOG")"
    exec >> "$LOG" 2>&1

    echo ""
    echo "=== $(date -Iseconds) Auto-update started ==="

    if [ ! -d "${configDir}" ]; then
      echo "Error: nix-config not found at ${configDir}"
      echo "Set NIX_CONFIG_DIR to override the default path."
      exit 1
    fi

    cd "${configDir}"
    ${pkgs.just}/bin/just fresh-install

    echo "=== $(date -Iseconds) Auto-update complete ==="
  '';
in {
  # just is a runtime dependency of the update script
  home.packages = lib.mkIf hasAutoUpdate [pkgs.just];

  # Service: runs the update (driven by timer for scheduled, or started directly for on-boot)
  systemd.user.services.nix-config-auto-update = lib.mkIf hasAutoUpdate {
    Unit = {
      Description = "Automatic nix-config system update";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "oneshot";
      # bash -l sources /etc/profile → full nix PATH (nix, nixos-rebuild, home-manager)
      ExecStart = "${pkgs.bash}/bin/bash -l ${updateScript}";
    };
    # on-boot: service starts at login (no timer needed)
    Install.WantedBy = lib.optional (freq == "on-boot") "default.target";
  };

  # Timer: drives scheduled updates (daily / weekly)
  systemd.user.timers.nix-config-auto-update = lib.mkIf isScheduled {
    Unit.Description = "Timer for automatic nix-config system update";
    Timer = {
      OnCalendar = calendarSpec.${freq};
      # Run missed timers on next boot (e.g. machine was off at scheduled time)
      Persistent = true;
      # Spread load — avoid all machines updating at exactly the same second
      RandomizedDelaySec = "5min";
    };
    Install.WantedBy = ["timers.target"];
  };
}
