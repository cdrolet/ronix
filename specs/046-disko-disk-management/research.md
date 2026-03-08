# Research: Disko Declarative Disk Management

**Feature**: 046-disko-disk-management
**Date**: 2026-02-07

## R1: Disko Configuration Format

**Decision**: Use disko's `disko.devices` Nix expression format for all storage profiles.

**Rationale**: Disko declares partitions, filesystems, encryption, and mount points in a single Nix expression. The same config is used at install time (partitioning) and runtime (fileSystems generation). This eliminates the sync problem between shell scripts and Nix declarations.

**Key points**:

- Partitions declared under `disko.devices.disk.<name>.content.partitions`
- Each partition has `size`, `type`, and `content` (filesystem, luks, swap, etc.)
- Disko auto-generates `fileSystems`, `swapDevices`, and `boot.initrd.luks.devices` from the declaration
- Must use `nixos-generate-config --no-filesystems` to avoid conflicts

**Alternatives considered**:

- Keep shell scripts + Nix declarations (current approach) — rejected: sync problem persists
- Use nixos-anywhere — too opinionated, handles remote deployment not just disk layout

## R2: Flake Input and Module Integration

**Decision**: Add disko as a flake input with `inputs.nixpkgs.follows = "nixpkgs"`. Import `disko.nixosModules.disko` in `nixos.nix` for all NixOS hosts.

**Rationale**: Disko module must be available to all NixOS configurations for `fileSystems` auto-generation. Hosts without storage profiles simply don't declare `disko.devices` — the module is a no-op.

**Integration point**: `system/nixos/lib/nixos.nix` adds `inputs.disko.nixosModules.disko` to the modules list, alongside the existing shared hardware profile loading.

## R3: Storage Profile Location and Structure

**Decision**: Replace existing `system/shared/hardware/storage/*.nix` files with disko-format configs. Keep them in the same location.

**Rationale**: Storage profiles are already loaded via the hardware profile system (Feature 045). Changing their internal format from manual `fileSystems` declarations to `disko.devices` declarations is transparent to the loading mechanism.

**Files affected**:

- `system/shared/hardware/storage/standard-partitions.nix` — rewrite to disko format
- `system/shared/hardware/storage/luks-encrypted.nix` — rewrite to disko format

## R4: Disk Device Specification

**Decision**: Use a parameterized approach — disko configs accept a default device path that can be overridden per-host. Auto-detection logic (VirtIO vs SCSI vs NVMe) moves into the disko config as a function argument with a sensible default.

**Rationale**: Disko does not auto-detect disk devices. The current `init-disk.sh` auto-detects `/dev/vda` vs `/dev/sda`. We preserve this by using a function parameter with a default that checks common device paths, or hosts can explicitly set their device.

**Approach**: Storage profiles accept `{ disks ? [ "/dev/vda" ], ... }` as a module argument. The `install-remote.sh` script detects the disk device and passes it via `--disk main /dev/<detected>` when using `disko-install`, or hosts can hardcode via `_module.args.disks`.

## R5: Install Script Integration

**Decision**: Replace the `init-disk` flag and `init-disk.sh` lookup in `install-remote.sh` with a disko call. Use `nix run github:nix-community/disko/latest -- --mode destroy,format,mount` followed by `nixos-install`.

**Rationale**: `disko-install` (single command) is simpler but requires the flake to be accessible. Since `install-remote.sh` already clones the repo, we can use the two-step approach: disko partitions/mounts, then `nixos-install --flake`.

**Changes to `install-remote.sh`**:

1. Remove `init-disk.sh` lookup logic
1. Auto-detect disk device (preserve existing VirtIO/SCSI detection, add NVMe)
1. If host has a storage profile, run disko to partition/format/mount
1. Remove `init-disk` CLI argument — disk initialization is automatic when storage profile exists
1. Keep confirmation prompt before destructive operations

## R6: LUKS Encryption in Disko

**Decision**: Use `content.type = "luks"` nested inside a partition, with interactive passphrase (no keyfile/TPM for now).

**Rationale**: Matches the spec's scope (passphrase-based LUKS). Disko handles both install-time `cryptsetup luksFormat` and runtime `boot.initrd.luks.devices` generation from the same config.

**Structure**:

- Boot partition: unencrypted vfat (required for systemd-boot)
- LUKS partition: contains ext4 root filesystem
- Swap: separate LUKS partition with swap inside

## R7: Conflict Detection Between Storage Profiles

**Decision**: Add validation in `resolveHardwareProfiles` or at the nixos.nix level to detect multiple storage profiles. Storage profiles in `system/shared/hardware/storage/` are mutually exclusive.

**Rationale**: Declaring both `standard-partitions` and `luks-encrypted` would produce conflicting `fileSystems` declarations. Build-time detection is better than runtime failure.

**Approach**: Check that at most one profile from the `storage/` category is resolved. Throw a clear error if multiple are found.

## R8: Removal of Legacy Files

**Decision**: Delete `system/nixos/lib/init-disk.sh` after migration. Remove `init-disk` argument handling from `install-remote.sh`.

**Rationale**: With disko as single source of truth, the shell script and its integration points are dead code. Keeping them would reintroduce the sync problem.
