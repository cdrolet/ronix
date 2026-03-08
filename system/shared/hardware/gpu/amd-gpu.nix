# Shared Hardware Profile: AMD GPU
#
# Purpose: AMD GPU support (amdgpu driver, Vulkan, VA-API video acceleration)
# Usage: Add "amd-gpu" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - Hardware graphics acceleration (OpenGL/Vulkan via DRI)
# - AMD amdgpu kernel driver
# - Vulkan support (via mesa RADV driver)
# - VA-API hardware video decoding (H.264, H.265, VP9, AV1)
#
# Use this for any host with an AMD GPU (integrated or discrete).
# This profile supersedes "base-gpu" — no need to include both.
# Pair with "amd" (cpu/amd.nix) for full AMD platform support.
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Hardware graphics acceleration (OpenGL, Vulkan, DRI)
  hardware.graphics = {
    enable = lib.mkDefault true;
    enable32Bit = lib.mkDefault true;
  };

  # amdgpu kernel module
  boot.initrd.kernelModules = ["amdgpu"];

  # VA-API for hardware video decoding
  hardware.graphics.extraPackages = with pkgs; [
    libva
    libvdpau-va-gl
  ];

  # GPU verification tools
  environment.systemPackages = with pkgs; [
    vulkan-tools
    libva-utils
  ];

  # Use amdgpu modesetting driver
  services.xserver.videoDrivers = lib.mkDefault ["amdgpu"];
}
