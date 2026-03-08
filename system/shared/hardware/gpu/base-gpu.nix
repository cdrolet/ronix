# Shared Hardware Profile: Base GPU
#
# Purpose: Enable hardware graphics acceleration (OpenGL/DRI) for any physical GPU
# Usage: Add "base-gpu" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - Hardware graphics acceleration (OpenGL via DRI)
#
# Use this for hosts with a generic or Intel GPU.
# Not needed for headless servers.
# Note: amd-gpu supersedes this — no need to include both.
# Note: virtio-gpu supersedes this for VMs — no need to include both.
# Note: Wayland clipboard (wl-clipboard) is provided by the wayland family.
{
  lib,
  ...
}: {
  hardware.graphics.enable = lib.mkDefault true;
}
