# Research: Shared Hardware Profiles

**Feature**: 045-shared-hardware-profiles
**Date**: 2026-02-07

## R1: Hardware Profile Loading Order

**Decision**: Shared hardware profiles are loaded BEFORE the host's local `hardware.nix`.

**Rationale**: This follows the existing hierarchical pattern (shared settings -> family settings -> host-specific). The host's local `hardware.nix` loads last, giving it natural override priority via NixOS module merging. Shared profiles use `lib.mkDefault` so any value set without `mkDefault` in the local file wins automatically.

**Alternatives considered**:

- Load profiles AFTER local hardware.nix: Rejected - would invert the override hierarchy and require `lib.mkForce` in local files to override shared values.
- Load profiles alongside family settings: Rejected - hardware profiles are orthogonal to families (a GNOME host and a Niri host might share the same VM hardware profile).

## R2: Profile Resolution Strategy

**Decision**: Fuzzy resolution with ambiguity detection. Bare names (`"qemu-guest"`) are resolved by searching all subdirectories recursively. Full paths (`"vm/qemu-guest"`) resolve directly. If a bare name matches files in multiple subdirectories, the build fails with an ambiguity error.

**Rationale**: Host configs should be concise. Subdirectories are for human organization, not for making host configs verbose. The existing `findAppInPath` function in `discovery.nix` already implements recursive directory search by name — the same pattern applies here. Ambiguity errors ensure correctness when profile names collide across categories.

**Resolution algorithm**:

1. If the name contains `/` (e.g., `"vm/qemu-guest"`): resolve directly as `system/shared/hardware/vm/qemu-guest.nix`
1. If the name is bare (e.g., `"qemu-guest"`): search all subdirectories for `qemu-guest.nix`
   - If exactly one match: use it
   - If multiple matches: error with list of matches, user must use full path
   - If no match: error with list of available profiles

**Alternatives considered**:

- Direct path only (always require `"vm/qemu-guest"`): Rejected - makes host configs unnecessarily verbose. The category is for browsing, not referencing.
- Auto-discovery (load all profiles in a category): Rejected - too implicit, hosts should explicitly opt into specific hardware profiles.
- Wildcard support (`"vm/*"`): Rejected - unnecessary complexity for a small number of profiles.

## R3: Where to Place Shared Hardware Directory

**Decision**: `system/shared/hardware/` (top-level under shared, not under settings or family).

**Rationale**: Hardware profiles are orthogonal to both families and settings:

- Not family-specific: A VM profile applies regardless of whether the host uses GNOME or Niri.
- Not settings: Settings are auto-discovered via `default.nix` and apply to all hosts of a type. Hardware profiles are explicitly selected per-host.
- Parallel to existing `system/shared/app/`, `system/shared/settings/`, `system/shared/lib/`.

**Alternatives considered**:

- `system/shared/settings/system/hardware/`: Rejected - settings auto-import everything; hardware profiles should be explicitly selected.
- `system/shared/family/linux/hardware/`: Rejected - not all profiles are Linux-family-specific, and not all Linux hosts need the same hardware.
- `system/nixos/hardware/`: Rejected - while currently NixOS-only, the shared location allows future platforms to reuse profiles if applicable.

## R4: Validation of Missing Profiles

**Decision**: Use `builtins.pathExists` check with `throw` for missing profiles at evaluation time.

**Rationale**: Consistent with existing validation patterns in the codebase (e.g., `validateFamilyExists` in discovery.nix). Fails fast with a clear error message.

**Alternatives considered**:

- Silent skip: Rejected - dangerous, typos would silently omit critical hardware configuration.
- Warning without error: Rejected - hardware misconfiguration can make systems unbootable.

## R5: Subdirectory Depth

**Decision**: One level of nesting only (e.g., `vm/qemu-guest.nix`, not `vm/apple/utm.nix`).

**Rationale**: Keeps the structure flat and simple. With ~5-10 initial profiles, deeper nesting adds complexity without benefit. Can be relaxed later if the profile count grows significantly.

## R6: Existing Duplication Analysis

**Decision**: Extract common VM configuration from both host `hardware.nix` files into shared profiles.

**Analysis of current duplication between `avf-gnome/hardware.nix` and `qemu-niri/hardware.nix`**:

| Configuration | avf-gnome | qemu-niri | Shareable? |
|---------------|----------------------|--------------|------------|
| QEMU guest profile import | Yes | Yes | Yes -> `vm/qemu-guest.nix` |
| systemd-boot + EFI | Yes | Yes | Yes -> `vm/qemu-guest.nix` |
| NIXOS/BOOT/SWAP partitions | Yes | Yes | Yes -> `storage/standard-partitions.nix` |
| DHCP networking | Yes | Yes | Yes -> `vm/qemu-guest.nix` |
| vmware.guest.enable = false | Yes | Yes | Yes -> `vm/qemu-guest.nix` |
| qemuGuest.enable | Yes | Yes | Yes -> `vm/qemu-guest.nix` |
| spice-vdagentd.enable | Yes | Yes | Yes -> `vm/spice.nix` |
| SSH with password auth | Yes | Yes | Yes -> `vm/qemu-guest.nix` |
| nixpkgs.hostPlatform | Yes (aarch64) | Yes (aarch64) | No - host-specific |
| Rosetta + virtiofs | Yes | No | Yes -> `vm/apple-virtualization.nix` |
| Serial console | No | Yes | Could be in qemu-guest |
| Graphics (modesetting, mesa) | No | Yes | Yes -> `graphics/virtio-gpu.nix` |
| HiDPI display settings | Yes | No | No - host-specific |

## R7: Host Schema Integration

**Decision**: Add `hardware` as a list of strings to `host-schema.nix`, defaulting to `[]`.

**Rationale**: Follows the same pattern as `family`, `applications`, and `settings` fields. Empty default ensures full backward compatibility.

**Implementation**: Resolution happens in `nixos.nix` (same as `hardwareModule` resolution), not in `config-loader.nix`, keeping the loader simple and platform-agnostic.
