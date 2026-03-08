# Shared Hardware Profile: HiDPI 4K 27" Monitor
#
# Purpose: Display scaling for 27" 4K monitors (3840x2160)
# Usage: Add "hidpi-4k-27" to host's hardware list
# Feature: 045-shared-hardware-profiles
#
# Provides:
# - 180 DPI (common HiDPI value for 27" 4K, ~1.875x scaling)
# - GDK 2x scaling for GTK apps
# - Qt auto screen scale factor
{
  config,
  lib,
  pkgs,
  ...
}: {
  # 180 DPI is a common HiDPI value on Linux for 27" 4K (~1.875x scaling)
  services.xserver.dpi = lib.mkDefault 180;

  environment.sessionVariables = {
    GDK_SCALE = lib.mkDefault "2";
    QT_AUTO_SCREEN_SCALE_FACTOR = lib.mkDefault "1";
  };
}
