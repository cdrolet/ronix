# Quickstart: Shared Hardware Profiles

## Creating a Hardware Profile

1. Create a file under `system/shared/hardware/{category}/{name}.nix`:

```nix
# system/shared/hardware/vm/qemu-guest.nix
#
# Purpose: Common QEMU guest configuration for NixOS VMs
# Usage: Add "vm/qemu-guest" to host's hardware list
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

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  services.qemuGuest.enable = lib.mkDefault true;
  networking.useDHCP = lib.mkDefault true;
}
```

2. Reference it from a host's `default.nix`:

```nix
# system/nixos/host/my-vm/default.nix
{ ... }:
{
  name = "my-vm";
  architecture = "aarch64";
  family = ["linux" "gnome"];
  hardware = ["qemu-guest" "spice"];  # Bare names - auto-resolved from subdirectories
  virtualMachine = true;
  applications = [];
  settings = ["default"];
}
```

Full paths also work: `hardware = ["vm/qemu-guest" "vm/spice"];`
If a bare name is ambiguous (exists in multiple categories), use the full path.

3. Add host-specific overrides in `hardware.nix` (optional):

```nix
# system/nixos/host/my-vm/hardware.nix
# Only machine-unique settings (filesystems, platform, etc.)
{ config, lib, pkgs, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "ext4";
  };
}
```

4. Verify: `nix flake check`

## Available Categories

| Category | Purpose |
|------------|--------------------------------------|
| `vm/` | Virtual machine guest configuration |
| `graphics/`| GPU drivers and display settings |
| `storage/` | Disk layout and filesystem config |

## Rules

- All settings must use `lib.mkDefault`
- One concern per file, \<200 lines
- Include header comment with purpose and usage
- Host's local `hardware.nix` always overrides shared profiles
