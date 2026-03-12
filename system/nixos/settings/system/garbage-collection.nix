# NixOS System Settings: Garbage Collection
#
# Purpose: Configure automatic Nix store garbage collection from host schedule.
# Reads: host.schedule.garbageCollection.{frequency, olderThan}
#
# Defaults (when not set in host config):
#   frequency = "weekly"
#   olderThan = "30d"
#
# Set frequency = null in host config to disable automatic GC entirely.
{
  config,
  lib,
  ...
}: let
  gc = config.host.schedule.garbageCollection;
  enabled = gc.frequency != null;
  ageOption = lib.optionalString (gc.olderThan != null) "--delete-older-than ${gc.olderThan}";
in {
  nix.gc = {
    automatic = lib.mkDefault enabled;
    dates = lib.mkIf enabled (lib.mkDefault gc.frequency);
    options = lib.mkIf (enabled && gc.olderThan != null) (lib.mkDefault ageOption);
  };
}
