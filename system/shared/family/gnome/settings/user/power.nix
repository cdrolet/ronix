# GNOME Family: Power Settings
#
# Purpose: Configure GNOME power management and screen timeout via dconf
# Feature: 025-nixos-settings-modules
#
# Settings include:
# - Screen dimming and blank timeout
# - Suspend behavior (disabled in VMs via config.host.virtualMachine)
# - Lock screen (disabled in VMs — no security benefit, just friction)
# - Power button action
{
  config,
  lib,
  pkgs,
  ...
}: let
  isVM = config.host.virtualMachine or false;

  # VMs should never suspend — it freezes the guest and has no power saving benefit
  sleepType =
    if isVM
    then "nothing"
    else "suspend";
in {
  dconf.settings = {
    # ============================================================================
    # Screen Timeout Settings
    # ============================================================================

    "org/gnome/desktop/session" = {
      # Idle delay before screen dims (seconds)
      # 300 = 5 minutes
      idle-delay = lib.mkDefault (lib.hm.gvariant.mkUint32 300);
    };

    # ============================================================================
    # Power Management Settings
    # ============================================================================

    "org/gnome/settings-daemon/plugins/power" = {
      # Screen blank timeout on AC power (seconds)
      # 1800 = 30 minutes
      sleep-inactive-ac-timeout = lib.mkDefault 1800;
      sleep-inactive-ac-type = lib.mkDefault sleepType;

      # Screen blank timeout on battery (seconds)
      # 900 = 15 minutes
      sleep-inactive-battery-timeout = lib.mkDefault 900;
      sleep-inactive-battery-type = lib.mkDefault sleepType;

      # Dim screen when idle
      idle-dim = lib.mkDefault true;

      # Power button action
      power-button-action = lib.mkDefault "interactive";
    };

    # ============================================================================
    # Lock Screen (disabled in VMs)
    # ============================================================================

    "org/gnome/desktop/screensaver" = lib.mkIf isVM {
      lock-enabled = false;
    };

    "org/gnome/desktop/lockdown" = lib.mkIf isVM {
      disable-lock-screen = true;
    };
  };
}
