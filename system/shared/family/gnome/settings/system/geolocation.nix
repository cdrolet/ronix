# GNOME Family: Geolocation and Automatic Timezone
#
# Purpose: Enable location services for automatic timezone detection
#
# geoclue2: system location provider (used by GNOME and automatic-timezoned)
# automatic-timezoned: daemon that updates time.timeZone based on geoclue2 location
#
# User-side dconf toggle is in settings/user/locale.nix
{lib, ...}: {
  services.geoclue2.enable = lib.mkDefault true;
  services.automatic-timezoned.enable = lib.mkDefault true;
}
