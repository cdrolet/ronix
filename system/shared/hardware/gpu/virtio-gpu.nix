# Shared Hardware Profile: Virtio GPU
#
# Purpose: GPU support for Wayland compositors in QEMU VMs
# Usage: Add "virtio-gpu" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - Virtio GPU kernel modules (virtio_gpu, drm)
# - Modesetting video driver for DRI/EGL
# - Mesa and libglvnd for OpenGL support
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Graphics support
  hardware.graphics = {
    enable = lib.mkDefault true;
    package = pkgs.mesa;
  };

  # Modesetting driver for DRI/EGL support (required for Wayland compositors in QEMU)
  services.xserver.videoDrivers = ["modesetting"];

  # Mesa and libglvnd for OpenGL
  environment.systemPackages = with pkgs; [
    libglvnd
    mesa
  ];

  # Load virtio GPU drivers
  boot.kernelModules = ["virtio_gpu" "drm"];
}
