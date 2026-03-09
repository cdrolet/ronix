# GNOME Family: Display Settings
#
# Purpose: Configure display scaling from host.display.scale
# Use case: HiDPI monitors, VMs with high-resolution virtual displays
#
# Integer scaling only (1 = 100%, 2 = 200%).
# For fractional scaling (150%, 175%) enable mutter experimental features instead.
{
  config,
  lib,
  ...
}: let
  scale = config.host.display.scale or null;
in
  lib.mkIf (scale != null) {
    dconf.settings."org/gnome/desktop/interface" = {
      scaling-factor = lib.mkDefault scale;
    };
  }
