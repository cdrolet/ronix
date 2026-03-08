# Hardware Field Schema Contract
#
# This contract defines the expected schema for the `hardware` field
# added to host-schema.nix for Feature 045.
#
# Usage in host default.nix:
#   hardware = ["qemu-guest" "spice" "virtio-gpu"];          # Bare names (fuzzy resolved)
#   hardware = ["vm/qemu-guest" "graphics/virtio-gpu"];      # Full paths (direct resolved)
#
# Resolution:
#   "qemu-guest"     -> searches all subdirs -> system/shared/hardware/vm/qemu-guest.nix
#   "vm/qemu-guest"  -> direct resolve      -> system/shared/hardware/vm/qemu-guest.nix
#   Ambiguous names (multiple matches) -> build error
{
  hardware = {
    type = "lib.types.listOf lib.types.str";
    default = [];
    description = ''
      List of shared hardware profiles to load.
      Bare names are resolved by searching all subdirectories.
      Full paths (with category/) resolve directly.
      Ambiguous bare names (matching multiple categories) cause a build error.
      Profiles are loaded before the host's local hardware.nix.
    '';
    example = ["qemu-guest" "spice" "standard-partitions"];
  };
}
