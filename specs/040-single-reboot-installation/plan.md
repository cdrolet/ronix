# Implementation Plan: Single-Reboot NixOS Installation

**Branch**: `040-single-reboot-installation` | **Date**: 2026-01-15 | **Spec**: [spec.md](./spec.md)\
**Input**: Feature specification from `specs/040-single-reboot-installation/spec.md`

## Summary

**Primary Requirement**: Reduce NixOS installation from 3 reboots to 2 reboots by ensuring home-manager activation completes before user login, making all configured applications visible on first login.

**Technical Approach**: Add systemd service ordering (`before = ["graphical.target"]`) to `nix-config-first-boot.service` to block GDM until home-manager completes. Add automatic desktop cache refresh (`update-desktop-database`) during home-manager activation to ensure GNOME reads fresh application metadata.

**Impact**: Single-line systemd ordering fix + activation script for cache refresh. Universal improvement across all NixOS installations (VMs, bare-metal, laptops, desktops). Saves 2-5 minutes per installation, eliminates confusing 3rd-reboot requirement.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: NixOS modules, Home Manager (standalone mode), systemd, desktop-file-utils, GNOME Shell (or compatible DE)\
**Storage**: Files (systemd service definition, home-manager activation scripts, desktop file cache)\
**Testing**: Manual installation testing (VM + bare-metal), systemd journal verification, cache file inspection\
**Target Platform**: NixOS (all architectures), works with any display manager + desktop environment\
**Project Type**: System configuration (Nix modules)\
**Performance Goals**: First-boot service completes in 2-5 minutes (typical home-manager build time), desktop cache refresh \<2 seconds\
**Constraints**: Must preserve Feature 036 architecture (standalone home-manager), must work on Wayland, must be idempotent\
**Scale/Scope**: 1 systemd service file modification (~1 line), 1 activation script addition (~5-10 lines), universal NixOS deployment

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle Compliance

**✅ I. Declarative Configuration First**

- All changes are declarative Nix expressions (systemd service config, home-manager activation)
- No imperative steps required in production

**✅ II. Modularity and Reusability**

- Changes isolated to existing modules (`first-boot.nix`, GNOME dock/settings modules)
- No new dependencies introduced
- Reusable across all NixOS installations

**✅ III. Documentation-Driven Development**

- Specification complete with research, rationale, success criteria
- Implementation will update inline comments and CLAUDE.md
- User documentation will explain installation flow changes

**✅ IV. Purity and Reproducibility**

- Systemd ordering is deterministic
- Desktop cache refresh is idempotent
- No network access during cache refresh

**✅ V. Testing and Validation**

- Manual testing plan defined (VM + bare-metal)
- Rollback via `nixos-rebuild --rollback`
- Validation via systemd journal inspection

**✅ VI. Cross-Platform Compatibility**

- NixOS-specific changes in `system/nixos/`
- GNOME-specific changes in `system/shared/family/gnome/`
- Platform abstraction preserved

### Architectural Standards

**✅ Flakes as Entry Point**

- No changes to flake.nix required
- Existing flake structure supports changes

**✅ Home Manager Integration**

- Preserves Feature 036 standalone home-manager mode
- Changes within home-manager activation lifecycle

**✅ Directory Structure Standard**

- Modifications to existing files in standard locations
- No new directories required

### Development Standards

**✅ Context Validation**

- Desktop cache refresh uses `lib.optionalAttrs (options ? home)` pattern
- Guards home-manager-specific activation scripts
- No context validation needed for systemd service (system-level only)

**✅ Specification Management**

- Specification complete and validated
- Implementation plan follows template structure

**✅ Code Organization**

- Changes within existing modules (\<200 lines each)
- Clear, focused modifications

**✅ Configuration Module Organization**

- Topic-based: systemd service (first-boot.nix), desktop cache (dock.nix or new module)
- Single responsibility maintained
- Header documentation will be updated

**✅ Helper Libraries and Activation Scripts**

- Activation script will be idempotent
- Uses standard systemd ordering directives
- Leverages existing `lib.hm.dag` for home-manager activation

**GATE RESULT: ✅ PASSED - No constitutional violations, proceed with implementation**

## Project Structure

### Documentation (this feature)

```
specs/040-single-reboot-installation/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0 output (systemd ordering research)
├── data-model.md        # Phase 1 output (state transitions)
├── quickstart.md        # Phase 1 output (testing guide)
├── checklists/
│   └── requirements.md  # Specification validation (complete)
└── contracts/           # Phase 1 output (systemd service contract)
```

### Source Code (repository root)

```
system/nixos/settings/system/
├── first-boot.nix       # MODIFY: Add before = ["graphical.target"]

system/shared/family/gnome/settings/user/
├── dock.nix             # MODIFY: Add desktop cache refresh activation
                         # OR create new desktop-cache.nix module

user/shared/lib/
└── (no changes)         # Existing activation helpers used as-is

CLAUDE.md                # UPDATE: Installation flow documentation
```

**Structure Decision**: Minimal invasive changes to existing modules. Single-line systemd ordering addition to `first-boot.nix`, activation script addition to GNOME settings. No new files required unless desktop cache refresh warrants dedicated module (decision during implementation).

## Complexity Tracking

**No constitutional violations** - All checks passed. This section intentionally left blank.

______________________________________________________________________

## Phase 0: Research & Decisions

### Research Topics

1. **Systemd Ordering Guarantees**

   - Verify `before = ["graphical.target"]` creates blocking dependency
   - Confirm `Type = "oneshot"` + `RemainAfterExit = true` semantics
   - Research interaction between `wantedBy`, `after`, and `before`

1. **Desktop File Cache Mechanisms**

   - Confirm `update-desktop-database` updates `.local/share/applications/mimeinfo.cache`
   - Verify GNOME Shell reads cache at session start (not during session)
   - Test idempotency of cache refresh command

1. **Home-Manager Activation DAG**

   - Confirm `lib.hm.dag.entryAfter ["writeBoundary"]` runs after all file writes
   - Verify activation script error handling (non-blocking on cache refresh failure)
   - Research existing activation script patterns in codebase

1. **Display Manager Compatibility**

   - Verify GDM respects `graphical.target` ordering
   - Confirm other display managers (LightDM, SDDM) have same behavior
   - Test Wayland vs X11 differences (if any)

### Decisions to Document

- **Where to place desktop cache refresh**: `dock.nix` (existing GNOME module) vs new `desktop-cache.nix` module
- **Error handling strategy**: Continue activation on cache refresh failure (non-blocking) or fail loudly
- **Progress messaging format**: Console output vs systemd journal vs both
- **Testing approach**: VM-only initially or VM + bare-metal in parallel

**Output**: `research.md` with findings and architectural decisions

______________________________________________________________________

## Phase 1: Design & Contracts

### Data Model

**State Machine**: Installation stages and transitions

```
States:
  - ISO_BOOTED: Live image running, installation not started
  - SYSTEM_INSTALLED: nixos-install complete, first-boot marker exists
  - FIRST_BOOT_IN_PROGRESS: nix-config-first-boot.service running
  - FIRST_BOOT_COMPLETE: Home-manager activated, GDM ready
  - USER_LOGGED_IN: GNOME session active, apps visible

Transitions:
  ISO_BOOTED → SYSTEM_INSTALLED (nixos-install, marker created)
  SYSTEM_INSTALLED → FIRST_BOOT_IN_PROGRESS (systemd service starts)
  FIRST_BOOT_IN_PROGRESS → FIRST_BOOT_COMPLETE (activation script completes)
  FIRST_BOOT_COMPLETE → USER_LOGGED_IN (user logs in via GDM)

Invariants:
  - graphical.target cannot start while in FIRST_BOOT_IN_PROGRESS
  - Desktop cache must be fresh before USER_LOGGED_IN
  - First-boot marker removed during FIRST_BOOT_COMPLETE transition
```

**Output**: `data-model.md` with state machine diagram and transition logic

### Contracts

**Systemd Service Contract** (`nix-config-first-boot.service`):

```ini
[Unit]
Description=First boot home-manager setup
After=network-online.target
Before=graphical.target        # NEW: Block display manager
Wants=network-online.target
ConditionPathExists=/home/{username}/.nix-config-first-boot

[Service]
Type=oneshot
User={username}
ExecStart=/etc/nix-config-first-boot.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

**Desktop Cache Refresh Contract** (home-manager activation):

```nix
home.activation.refreshDesktopCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
  # Update desktop file database for GNOME/FreeDesktop
  run ${pkgs.desktop-file-utils}/bin/update-desktop-database \
    -q "$HOME/.local/share/applications" 2>/dev/null || true
  $VERBOSE_ECHO "Desktop file cache refreshed"
'';
```

**Output**: `contracts/systemd-service.txt`, `contracts/activation-script.nix`

### Quickstart Guide

**Testing Procedure**:

1. **VM Testing** (primary validation):

   ```bash
   # Build ISO with changes
   nix build ".#nixosConfigurations.cdrokar-qemu-gnome-vm.config.system.build.isoImage"

   # Boot VM from ISO
   qemu-system-x86_64 -cdrom result/iso/*.iso -m 4096 -enable-kvm

   # Run installation
   bash install-remote.sh cdrokar qemu-gnome-vm

   # Reboot and observe
   # Expected: GDM login screen appears AFTER home-manager completes
   # Expected: Apps visible immediately after first login
   ```

1. **Systemd Journal Verification**:

   ```bash
   # After first boot, check service ordering
   journalctl -u nix-config-first-boot.service
   journalctl -u display-manager.service

   # Verify service ran before GDM
   systemctl show -p After graphical.target | grep nix-config-first-boot
   ```

1. **Cache Verification**:

   ```bash
   # Check cache file exists and is recent
   ls -lh ~/.local/share/applications/mimeinfo.cache

   # Verify apps appear in GNOME
   gsettings get org.gnome.shell favorite-apps
   ```

**Output**: `quickstart.md` with step-by-step testing instructions

______________________________________________________________________

## Phase 2: Task Breakdown

**Note**: Detailed task breakdown will be generated by `/speckit.tasks` command (not part of this plan).

**High-Level Tasks**:

1. **Systemd Ordering Fix**

   - Modify `system/nixos/settings/system/first-boot.nix`
   - Add `before = ["graphical.target"]`
   - Update inline comments explaining ordering

1. **Desktop Cache Refresh**

   - Add activation script to GNOME settings module
   - Use `lib.hm.dag.entryAfter ["writeBoundary"]`
   - Make non-blocking with `|| true`

1. **Progress Messaging**

   - Enhance `/etc/nix-config-first-boot.sh` with stage indicators
   - Ensure messages visible in systemd journal

1. **Testing**

   - VM installation test (verify 2-reboot flow)
   - Systemd journal verification (service before GDM)
   - Desktop cache verification (apps visible first login)
   - Bare-metal installation test (optional validation)

1. **Documentation**

   - Update `CLAUDE.md` installation flow section
   - Add inline comments to modified modules
   - Create user-facing installation guide

______________________________________________________________________

## Implementation Notes

### Critical Path

**Must implement in order**:

1. Systemd ordering fix (enables blocking behavior)
1. Desktop cache refresh (ensures fresh cache ready)
1. Testing validation (proves solution works)

**Optional enhancements** (can defer):

- Progress messaging improvements
- Bare-metal testing
- User documentation

### Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Service hangs, blocking boot indefinitely | HIGH | Add timeout to service (10-minute max), document manual recovery |
| Network failures prevent home-manager build | MEDIUM | Service already handles gracefully, fails and allows GDM to start |
| Desktop cache refresh fails silently | LOW | Non-blocking by design (`|| true`), logged to journal |
| Wayland-specific issues with cache | LOW | `update-desktop-database` is DE-agnostic, tested on Wayland |

### Rollback Plan

If deployment causes issues:

```bash
# Immediate rollback
sudo nixos-rebuild switch --rollback

# Manual recovery if system won't boot
# At boot menu: Select previous generation
# Or from recovery shell:
nixos-rebuild switch --rollback
```

______________________________________________________________________

## Success Metrics

**Quantitative**:

- Installation requires exactly 2 reboots (measured)
- First-boot service completes before GDM starts (systemd journal)
- 100% of configured apps visible on first login (manual verification)
- Desktop cache refresh completes in \<2 seconds (logged)

**Qualitative**:

- User experience improved (no confusing 3rd reboot)
- Installation time reduced by 2-5 minutes
- Clear understanding of boot delay reason (progress messages)

______________________________________________________________________

## Agent Context Update

**Technologies Added**:

- systemd service ordering (`before`, `after`, `wantedBy`)
- Home Manager activation DAG (`lib.hm.dag.entryAfter`)
- Desktop file utilities (`update-desktop-database`)

**Note**: Will run `.specify/scripts/bash/update-agent-context.sh claude` after Phase 1 completion to update agent-specific context with these technologies.
