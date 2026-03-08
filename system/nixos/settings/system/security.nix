# Security Settings
#
# Purpose: Configure firewall, sudo, and privilege escalation
# Feature: 025-nixos-settings-modules
#
# Equivalent Darwin settings: security.nix (firewall, guest account)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ============================================================================
  # Firewall Configuration
  # ============================================================================
  # Equivalent to Darwin's socketfilterfw settings

  networking.firewall = {
    enable = lib.mkDefault true;
    allowPing = lib.mkDefault false; # Stealth mode equivalent
  };

  # ============================================================================
  # Sudo Configuration
  # ============================================================================
  # Privilege escalation settings

  security.sudo = {
    enable = lib.mkDefault true;
    wheelNeedsPassword = lib.mkDefault true;
  };

  # ============================================================================
  # Polkit Configuration
  # ============================================================================
  # Desktop privilege escalation (GUI prompts)

  security.polkit.enable = lib.mkDefault true;
}
