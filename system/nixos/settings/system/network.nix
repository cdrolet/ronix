# Network Settings (System-Level)
#
# Purpose: Configure NetworkManager and DNS defaults
# Feature: 025-nixos-settings-modules, 036-standalone-home-manager, 039-segregate-settings
#
# Equivalent Darwin settings: network.nix (network discovery, DNS)
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Feature 036: Access host config directly from schema
  hostConfig = config.host or {};
  hasHostName = hostConfig ? name && hostConfig.name != null;
in {
  # ============================================================================
  # NetworkManager
  # ============================================================================
  # Desktop-friendly network management with GUI applet support

  networking.networkmanager.enable = lib.mkDefault true;

  # ============================================================================
  # Hostname
  # ============================================================================
  # Set from host configuration if available

  networking.hostName = lib.mkIf hasHostName (lib.mkDefault hostConfig.name);

  # ============================================================================
  # DNS Configuration
  # ============================================================================
  # Fallback DNS servers (Cloudflare and Google)

  networking.nameservers = lib.mkDefault ["1.1.1.1" "8.8.8.8"];
}
