# Tasks: Shared Hardware Profiles

**Input**: Design documents from `/specs/045-shared-hardware-profiles/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup

**Purpose**: Create shared hardware directory structure and schema changes

- [ ] T001 Create shared hardware directory structure with initial category subdirectories at `system/shared/hardware/vm/`, `system/shared/hardware/graphics/`, `system/shared/hardware/storage/`
- [ ] T002 Add `hardware` field (list of strings, default `[]`) to host schema in `system/shared/lib/host-schema.nix`

______________________________________________________________________

## Phase 2: Foundational (Resolution & Loading)

**Purpose**: Implement the fuzzy resolution function and loading mechanism. MUST complete before user stories.

- [ ] T003 Add `resolveHardwareProfiles` function to `system/shared/lib/discovery.nix` that:
  - Takes a list of hardware profile names and the base path
  - For names containing `/`: resolves directly to `system/shared/hardware/{name}.nix`
  - For bare names: recursively searches all subdirectories under `system/shared/hardware/`
  - If exactly one match: returns the path
  - If multiple matches: throws ambiguity error listing all matching paths
  - If no match: throws not-found error listing available profiles
  - Export the function in the `in { ... }` block
- [ ] T004 Integrate hardware profile loading in `system/nixos/lib/nixos.nix`:
  - Extract `hostData.hardware or []` from host config
  - Call `resolveHardwareProfiles` to get list of paths
  - Insert resolved paths into modules array BEFORE `hardwareModule` (local hardware.nix)
  - Preserve existing `hardwareModule` loading (local hardware.nix loads last for override priority)

**Checkpoint**: Empty `hardware = []` builds successfully, referencing a non-existent profile produces clear error

______________________________________________________________________

## Phase 3: User Story 1 - Reuse Hardware Profiles Across Hosts (Priority: P1)

**Goal**: Extract common VM configuration from existing hosts into shared profiles and reference them

**Independent Test**: `nix flake check` passes; existing VM hosts build with shared profiles instead of duplicated config

### Implementation for User Story 1

- [ ] T005 [P] [US1] Create `system/shared/hardware/vm/qemu-guest.nix` — QEMU guest profile import, systemd-boot, EFI, DHCP networking, SSH with password auth, qemu-guest-agent, vmware guest disable
- [ ] T006 [P] [US1] Create `system/shared/hardware/vm/spice.nix` — SPICE VD agent system daemon, systemd ConditionVirtualization guards
- [ ] T007 [P] [US1] Create `system/shared/hardware/vm/apple-virtualization.nix` — Rosetta for Linux, virtiofs mount for `/run/rosetta`, shared directory virtiofs mount at `/mnt/share`
- [ ] T008 [P] [US1] Create `system/shared/hardware/graphics/virtio-gpu.nix` — modesetting video driver, mesa packages, virtio_gpu and drm kernel modules, libglvnd
- [ ] T009 [P] [US1] Create `system/shared/hardware/storage/standard-partitions.nix` — standard NIXOS/BOOT/SWAP partition layout by label, ext4 root, vfat boot
- [ ] T010 [US1] Update `system/nixos/host/avf-gnome/default.nix` to add `hardware = ["qemu-guest" "spice" "apple-virtualization" "standard-partitions"]`
- [ ] T011 [US1] Slim down `system/nixos/host/avf-gnome/hardware.nix` to only host-specific settings (hostPlatform, HiDPI display, SSH firewall port) — remove everything now in shared profiles
- [ ] T012 [US1] Update `system/nixos/host/qemu-niri/default.nix` to add `hardware = ["qemu-guest" "spice" "virtio-gpu" "standard-partitions"]`
- [ ] T013 [US1] Slim down `system/nixos/host/qemu-niri/hardware.nix` to only host-specific settings (hostPlatform, serial console, SSH firewall port) — remove everything now in shared profiles
- [ ] T014 [US1] Run `nix flake check` to verify all configurations build correctly

**Checkpoint**: Both VM hosts build using shared profiles. Duplicated config eliminated.

______________________________________________________________________

## Phase 4: User Story 2 - Organize Profiles by Category (Priority: P2)

**Goal**: Verify that subdirectory organization works with fuzzy resolution

**Independent Test**: Bare names resolve correctly; ambiguous names produce clear errors

### Implementation for User Story 2

- [ ] T015 [US2] Verify bare name resolution works end-to-end: host using `"qemu-guest"` correctly resolves to `vm/qemu-guest.nix` (covered by T010-T014 builds)
- [ ] T016 [US2] Verify full path resolution works: temporarily test `"vm/qemu-guest"` in a host config and confirm it builds

**Checkpoint**: Both bare names and full paths resolve correctly

______________________________________________________________________

## Phase 5: User Story 3 - Host Local Hardware.nix Overrides (Priority: P1)

**Goal**: Confirm that host's local hardware.nix values override shared profile values

**Independent Test**: A shared profile value set with `lib.mkDefault` is overridden by a host's local hardware.nix value set without `mkDefault`

### Implementation for User Story 3

- [ ] T017 [US3] Verify override priority is correct: `avf-gnome/hardware.nix` sets `nixpkgs.hostPlatform` which is NOT in any shared profile — confirm no conflicts
- [ ] T018 [US3] Verify that if a shared profile and local hardware.nix set the same option, the local value wins (e.g., both set `services.qemuGuest.enable` — local should override shared `lib.mkDefault`)

**Checkpoint**: Override hierarchy confirmed: shared settings -> shared profiles -> local hardware.nix

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T019 [P] Update `CLAUDE.md` to document the shared hardware profiles directory and `hardware` host field
- [ ] T020 [P] Update `system/shared/family/README.md` if any references to hardware need updating
- [ ] T021 Run `nix flake check` final validation
- [ ] T022 Commit and push

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Phase 1 (schema and directory must exist)
- **User Story 1 (Phase 3)**: Depends on Phase 2 (resolution and loading must work)
- **User Story 2 (Phase 4)**: Depends on Phase 3 (needs profiles to exist for testing)
- **User Story 3 (Phase 5)**: Depends on Phase 3 (needs profiles and hosts using them)
- **Polish (Phase 6)**: Depends on all stories complete

### Parallel Opportunities

- T005, T006, T007, T008, T009 can all run in parallel (different files, no dependencies)
- T010+T011 and T012+T013 can run in parallel (different hosts)
- T019, T020 can run in parallel (different documentation files)

______________________________________________________________________

## Parallel Example: User Story 1 Profile Creation

```
# Launch all shared profile creations together:
T005: Create system/shared/hardware/vm/qemu-guest.nix
T006: Create system/shared/hardware/vm/spice.nix
T007: Create system/shared/hardware/vm/apple-virtualization.nix
T008: Create system/shared/hardware/graphics/virtio-gpu.nix
T009: Create system/shared/hardware/storage/standard-partitions.nix

# Then update hosts in parallel:
T010+T011: Update avf-gnome
T012+T013: Update qemu-niri
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (directory + schema)
1. Complete Phase 2: Foundational (resolution + loading)
1. Complete Phase 3: User Story 1 (create profiles, update hosts)
1. **STOP and VALIDATE**: `nix flake check`
1. Both VM hosts should build with shared profiles

### Incremental Delivery

1. Setup + Foundational -> Infrastructure ready
1. User Story 1 -> Shared profiles work, duplication eliminated (MVP)
1. User Story 2 -> Fuzzy resolution verified
1. User Story 3 -> Override priority confirmed
1. Polish -> Documentation updated, committed

______________________________________________________________________

## Notes

- All shared profiles MUST use `lib.mkDefault` for every setting
- All shared profiles MUST include header documentation (purpose, usage)
- All shared profiles MUST be \<200 lines
- The `resolveHardwareProfiles` function reuses patterns from `findAppInPath` in discovery.nix
- Existing `system/nixos/settings/system/hardware.nix` (universal firmware/graphics) is NOT modified
- Existing `system/nixos/settings/system/virtualization.nix` (system-level VM services) is NOT modified — shared profiles handle host-specific VM config, not system-wide defaults
