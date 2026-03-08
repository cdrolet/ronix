# Tasks: Disko Declarative Disk Management

**Input**: Design documents from `/specs/046-disko-disk-management/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup

**Purpose**: Add disko flake input and NixOS module integration

- [ ] T001 Add disko flake input to `flake.nix` with `inputs.nixpkgs.follows = "nixpkgs"`
- [ ] T002 Import `inputs.disko.nixosModules.disko` in `system/nixos/lib/nixos.nix` module list (before shared hardware modules)
- [ ] T003 Run `nix flake check` to verify disko module loads without errors

**Checkpoint**: Disko module available to all NixOS hosts, no behavior change yet

______________________________________________________________________

## Phase 2: Foundational (Storage Conflict Detection)

**Purpose**: Add build-time validation that prevents multiple storage profiles on the same host

- [ ] T004 Add storage conflict detection to `system/shared/lib/discovery.nix`: after resolving hardware profiles, check that at most one resolved path is under `storage/` subdirectory — throw clear error if multiple found
- [ ] T005 Run `nix flake check` to verify conflict detection doesn't break existing hosts (which each have exactly one storage profile)

**Checkpoint**: Multiple storage profiles on a host produce a build-time error

______________________________________________________________________

## Phase 3: User Story 1 - Single Source of Truth (Priority: P1)

**Goal**: Rewrite standard-partitions.nix to disko format — same config used for install-time partitioning and runtime fileSystems

**Independent Test**: `nix flake check` passes; host using `standard-partitions` builds correctly with disko-generated fileSystems

### Implementation for User Story 1

- [ ] T006 [US1] Rewrite `system/shared/hardware/storage/standard-partitions.nix` to disko format: parameterized device (`disks` argument with `/dev/vda` default), GPT table, ESP boot partition (512M, vfat, `/boot`), root partition (remaining minus 8G, ext4, `/`), swap partition (8G)
- [ ] T007 [US1] Update `system/nixos/host/avf-gnome/default.nix` if needed — verify `"standard-partitions"` still resolves correctly
- [ ] T008 [US1] Update `system/nixos/host/qemu-niri/default.nix` if needed — verify `"standard-partitions"` still resolves correctly
- [ ] T009 [US1] Run `nix flake check` to verify both hosts build with disko-generated fileSystems

**Checkpoint**: Standard partition layout defined once in disko format, generates runtime config automatically

______________________________________________________________________

## Phase 4: User Story 2 - LUKS Encrypted Layout (Priority: P1)

**Goal**: Rewrite luks-encrypted.nix to disko format with LUKS containers for root and swap

**Independent Test**: `nix flake check` passes; a host using `luks-encrypted` builds correctly with disko-generated fileSystems + initrd.luks config

### Implementation for User Story 2

- [ ] T010 [US2] Rewrite `system/shared/hardware/storage/luks-encrypted.nix` to disko format: parameterized device, GPT table, ESP boot partition (512M, vfat, `/boot`), LUKS root partition (remaining minus 8G, cryptroot → ext4, `/`), LUKS swap partition (8G, cryptswap → swap)
- [ ] T011 [US2] Run `nix flake check` to verify LUKS profile builds correctly (no host uses it yet, but module must evaluate)

**Checkpoint**: LUKS encrypted layout defined once in disko format, single source of truth

______________________________________________________________________

## Phase 5: User Story 3 - Install Script Integration (Priority: P2)

**Goal**: Replace init-disk.sh logic in install-remote.sh with disko call

**Independent Test**: `install-remote.sh` can partition a disk using the host's disko storage profile without `init-disk` flag

### Implementation for User Story 3

- [ ] T012 [US3] Add disk device auto-detection function to `install-remote.sh`: check `/dev/vda` (VirtIO), `/dev/sda` (SCSI), `/dev/nvme0n1` (NVMe) in order, return first found
- [ ] T013 [US3] Replace `init-disk` flag and `init-disk.sh` lookup logic in `install-remote.sh` with disko-based partitioning: detect if host has a storage profile (check for `disko.devices` in flake eval), run `nix run github:nix-community/disko/latest -- --mode destroy,format,mount` with detected device, keep confirmation prompt before destructive operations
- [ ] T014 [US3] Update `install-remote.sh` usage/help text and examples to remove `init-disk` references
- [ ] T015 [US3] Update `install-remote.sh` comment at top of file (curl example) to remove `init-disk`
- [ ] T016 [US3] Delete `system/nixos/lib/init-disk.sh`

**Checkpoint**: Install script uses disko for disk initialization, no separate shell script needed

______________________________________________________________________

## Phase 6: User Story 4 - Auto-Detect Disk Device (Priority: P2)

**Goal**: Storage profiles work across different disk types without host-specific changes

**Independent Test**: Same storage profile resolves correct device on VirtIO and NVMe without config changes

### Implementation for User Story 4

- [ ] T017 [US4] Verify `standard-partitions.nix` disko config accepts `disks` parameter override via `_module.args.disks` — document in profile header comment
- [ ] T018 [US4] Verify `luks-encrypted.nix` disko config accepts `disks` parameter override — document in profile header comment

**Checkpoint**: Disk device is parameterized and auto-detected by install script

______________________________________________________________________

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T019 [P] Update `CLAUDE.md` to document disko integration and storage profile format change
- [ ] T020 [P] Update `specs/046-disko-disk-management/quickstart.md` with final install workflow
- [ ] T021 Run `nix flake check` final validation
- [ ] T022 Commit and push

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Phase 1 (disko module must be available)
- **User Story 1 (Phase 3)**: Depends on Phase 2 (conflict detection in place)
- **User Story 2 (Phase 4)**: Depends on Phase 2 (can run parallel with US1)
- **User Story 3 (Phase 5)**: Depends on Phase 3 (needs disko profiles to exist for install script)
- **User Story 4 (Phase 6)**: Depends on Phase 3+4 (verification of parameterization)
- **Polish (Phase 7)**: Depends on all stories complete

### Parallel Opportunities

- T007 and T008 can run in parallel (different host files)
- US1 and US2 can run in parallel (different storage profile files)
- T019 and T020 can run in parallel (different documentation files)
- T012-T015 are sequential (same file: install-remote.sh)

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (disko input + module)
1. Complete Phase 2: Foundational (conflict detection)
1. Complete Phase 3: User Story 1 (standard-partitions in disko format)
1. **STOP and VALIDATE**: `nix flake check`, verify VM hosts build

### Incremental Delivery

1. Setup + Foundational → disko available
1. US1 (standard-partitions) → verify VM builds
1. US2 (luks-encrypted) → ready for physical hosts
1. US3 (install script) → seamless install workflow
1. US4 (device detection) → portable across hardware
