# Shared Hardware Profile: QEMU Guest
#
# Purpose: Common QEMU guest configuration for NixOS VMs
# Usage: Add "qemu-guest" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - QEMU guest profile (virtio drivers, ballooning, etc.)
# - UEFI boot loader (systemd-boot)
# - DHCP networking
# - SSH with password authentication
# - QEMU guest agent
# - VMware guest disabled (prevents conflicts)
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Boot loader configuration (UEFI with systemd-boot)
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Networking
  networking.useDHCP = lib.mkDefault true;

  # VM-specific settings
  virtualisation.vmware.guest.enable = lib.mkDefault false;

  # Enable QEMU guest agent for host-guest communication
  services.qemuGuest.enable = lib.mkDefault true;

  # Enable SSH for remote access
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PermitRootLogin = lib.mkDefault "no";
      PasswordAuthentication = lib.mkDefault true;
    };
  };
  networking.firewall.allowedTCPPorts = lib.mkDefault [22];
}
