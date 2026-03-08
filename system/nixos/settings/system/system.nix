# System Settings
#
# Purpose: Configure boot loader, Nix settings, and garbage collection
# Feature: 025-nixos-settings-modules
#
# Equivalent Darwin settings: system.nix (Nix settings)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ============================================================================
  # Boot Loader
  # ============================================================================
  # systemd-boot for UEFI systems

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # ============================================================================
  # Nix Settings
  # ============================================================================
  # Enable flakes and optimize store

  nix.settings = {
    experimental-features = lib.mkDefault ["nix-command" "flakes"];
    auto-optimise-store = lib.mkDefault true;
    download-buffer-size = lib.mkDefault 268435456; # 256MB (default is 64MB)
  };

  # ============================================================================
  # Garbage Collection
  # ============================================================================
  # Automatic cleanup of old generations

  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 30d";
  };

  # ============================================================================
  # System State Version
  # ============================================================================
  # NixOS compatibility version - determines which package/service versions to use
  # This should match the NixOS release version and should NOT be changed after
  # initial installation as it affects system behavior and compatibility.
  # See: https://nixos.org/manual/nixos/stable/options.html#opt-system.stateVersion

  system.stateVersion = "25.05"; # NixOS 25.05 (latest stable as of 2025-01)
}
