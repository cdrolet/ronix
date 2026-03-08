# Feature Specification: Single-Reboot NixOS Installation

**Feature Branch**: `040-single-reboot-installation`\
**Created**: 2026-01-15\
**Status**: Draft\
**Scope**: All NixOS installations (VMs, bare-metal, laptops, desktops)

**Input**: User description: "currently installing a host such as the system/nixos/host/qemu-gnome-vm on a ISO live image require 3 system restart ... first one from the iso, then home-manager is installed from nix-config-first-boot during first restart but gnome desktop didn't display installed apps/settings. after restarting the system for a third time, the list of apps are finally displaying the one configured."

## Executive Summary

**Problem**: NixOS installations with standalone home-manager currently require 3 reboots before users see their configured applications.

**Root Cause**: The `nix-config-first-boot` systemd service runs in parallel with GDM startup, allowing users to log in before home-manager completes activation. GNOME Shell reads desktop file cache at login time, missing the newly installed applications.

**Solution**: Add proper systemd ordering (`before = ["graphical.target"]`) to block GDM until home-manager activation completes, plus automatic desktop cache refresh. This ensures applications are visible on first login.

**Impact**: 3 reboots → 2 reboots (33% reduction), saves 2-5 minutes installation time, applies to ALL NixOS installations (not just VMs).

## Research Summary

### Current Installation Flow Analysis

The current NixOS installation with standalone home-manager requires **3 reboots**:

1. **Boot #1 (ISO → Installed System)**: nixos-install completes, creates first-boot marker, system reboots
1. **Boot #2 (First-Boot Service)**: nix-config-first-boot systemd service runs, installs standalone home-manager, user logs in (apps invisible)
1. **Login #2 (GNOME Cache Refresh)**: User logs out and back in, GNOME indexes desktop files, apps finally appear

### Root Cause: Systemd Service Ordering

**Current Configuration** (`system/nixos/settings/system/first-boot.nix` lines 106-132):

```nix
systemd.services.nix-config-first-boot = {
  description = "First boot home-manager setup";
  wantedBy = ["multi-user.target"];        # Service is enabled
  after = ["network-online.target"];       # Wait for network
  wants = ["network-online.target"];       # Require network
  
  # MISSING: before = ["graphical.target"]  ← The critical ordering!
  
  serviceConfig = {
    Type = "oneshot";
    User = config.user.name;
    ExecStart = "/etc/nix-config-first-boot.sh";
    RemainAfterExit = true;
  };
};
```

**The Problem**:

- `wantedBy = ["multi-user.target"]` only **enables** the service, doesn't create ordering
- `after = ["network-online.target"]` says "start after network", not "block graphical.target"
- GDM starts in parallel during `graphical.target` activation
- User can log in while home-manager is still building/activating
- GNOME Shell reads desktop cache at login (before activation completes)
- Desktop files don't exist yet or cache is stale

**Boot Sequence Timeline (Current)**:

```
T=0:  Kernel boots
T=1:  network-online.target reached
T=2:  nix-config-first-boot starts (background) ← 2-5 minute build
T=3:  multi-user.target reached
T=4:  graphical.target starts (GDM launches) ← Runs in parallel!
T=5:  User sees login screen, logs in
T=6:  GNOME Shell reads cache ← Desktop files don't exist yet!
T=7:  nix-config-first-boot completes (too late)
T=8:  User sees empty desktop, no apps
```

### The Solution: Proper Systemd Ordering

**Add one line** to create blocking dependency:

```nix
systemd.services.nix-config-first-boot = {
  description = "First boot home-manager setup";
  wantedBy = ["multi-user.target"];
  after = ["network-online.target"];
  wants = ["network-online.target"];
  
  before = ["graphical.target"];  # ← NEW: Block GDM until completion
  
  serviceConfig = {
    Type = "oneshot";              # Blocking execution
    User = config.user.name;
    ExecStart = "/etc/nix-config-first-boot.sh";
    RemainAfterExit = true;        # Keep "active" after completion
  };
};
```

**Boot Sequence Timeline (Fixed)**:

```
T=0:  Kernel boots
T=1:  network-online.target reached
T=2:  nix-config-first-boot starts ← 2-5 minute build
T=3:  multi-user.target reached
T=4:  [WAITING] graphical.target blocked ← GDM cannot start yet!
T=5:  Home-manager creates .desktop files
T=6:  update-desktop-database runs (cache refreshed)
T=7:  nix-config-first-boot completes ✅
T=8:  graphical.target starts (GDM launches)
T=9:  User logs in
T=10: GNOME Shell reads fresh cache ← Desktop files exist! ✅
T=11: Apps visible immediately! ✅
```

### Why This Works

1. **Systemd Ordering Guarantees**: `before = ["graphical.target"]` creates dependency: `nix-config-first-boot.service` → `graphical.target`
1. **Oneshot Service Type**: `Type = "oneshot"` makes the service blocking (target waits for completion)
1. **RemainAfterExit**: Keeps service "active" so dependency is satisfied
1. **GDM Waits**: Display manager cannot start until service completes
1. **Fresh Cache**: Desktop files and cache exist before GNOME Shell starts
1. **First Login Success**: GNOME reads complete application list immediately

### Architectural Constraints (Preserved)

This solution works within existing constraints:

**✅ Standalone Home-Manager (Feature 036)**:

- No changes to home-manager architecture
- Still runs independently from system configuration
- Darwin compatibility preserved (Darwin doesn't have first-boot service)
- Full `lib.hm` support maintained

**✅ Wayland Compatibility**:

- No shell restart required (apps visible from first login)
- No X11-specific workarounds needed
- Works with modern Wayland-only systems

**✅ Safety Boundaries**:

- No forced logout (user cannot login until ready)
- No data loss risk (no existing session to interrupt)
- No race conditions (service completes before user interaction)

### Scope: All NixOS Installations

This solution applies universally to:

- ✅ **Virtual Machines** (QEMU, UTM, VirtualBox, VMware, etc.)
- ✅ **Bare-metal desktops** (AMD, Intel, any architecture)
- ✅ **Laptops** (Dell, Lenovo, Framework, System76, etc.)
- ✅ **Servers with GUI** (Remote desktop, KVM consoles)
- ✅ **Any display manager** (GDM, LightDM, SDDM) - all respect `graphical.target`
- ✅ **Any desktop environment** (GNOME, KDE, XFCE) - all have desktop file caches

**Only requirement**: Installation uses `install-remote.sh` script (creates first-boot marker) and standalone home-manager architecture.

**VM-specific components** (separate concern):

- `services.qemuGuest.enable` - QEMU guest agent (auto-detects VM)
- `services.spice-vdagentd.enable` - SPICE clipboard (only runs in VMs)
- These are unrelated to the reboot count issue

## User Scenarios & Testing

### User Story 1 - Single-Reboot Installation (Priority: P1)

User installs NixOS (VM, bare-metal, or laptop) from ISO image and expects a functional desktop with all configured applications visible after a single reboot.

**Why this priority**: Eliminates the primary pain point (3 reboots → 2 reboots). Reduces installation time by 2-5 minutes. Dramatically improves first-time user experience. Single technical change (one line) with universal impact.

**Independent Test**: Can be fully tested by running `bash install-remote.sh user host` from ISO, rebooting once, logging in, and verifying all configured apps appear in dock and application menu immediately.

**Acceptance Scenarios**:

1. **Given** NixOS ISO booted with network access, **When** user runs installation script, **Then** nixos-install creates first-boot marker and installs system configuration
1. **Given** system reboots after installation, **When** first-boot service runs, **Then** GDM login screen does NOT appear until home-manager activation completes
1. **Given** first-boot service in progress, **When** user waits at boot screen, **Then** visible progress indicator shows "Setting up user environment..." (systemd boot messages)
1. **Given** first-boot service completes, **When** GDM login screen appears, **Then** home-manager activation has finished and desktop files exist
1. **Given** user logs into GNOME session for first time, **When** desktop appears, **Then** all configured applications visible in dock and application menu
1. **Given** first login complete, **When** user checks systemd journal, **Then** log shows first-boot service completed before graphical.target started

### User Story 2 - Automatic Desktop Cache Refresh (Priority: P2)

Home-manager activation automatically updates desktop file cache as part of the activation process, ensuring GNOME reads fresh application metadata on first login.

**Why this priority**: Guarantees cache consistency. Prevents stale cache issues. Required complement to systemd ordering fix. Low implementation cost (single activation script).

**Independent Test**: Can be tested by checking home-manager activation logs for `update-desktop-database` execution, verifying cache files updated in `~/.local/share/applications/`, and confirming apps appear on first login.

**Acceptance Scenarios**:

1. **Given** home-manager activation running, **When** activation writes desktop files, **Then** `update-desktop-database ~/.local/share/applications` runs automatically
1. **Given** desktop database updated, **When** GNOME Shell starts, **Then** Shell reads fresh cache with all installed applications
1. **Given** cache update fails for any reason, **When** activation continues, **Then** activation succeeds (non-blocking) and warning logged
1. **Given** future home-manager activations, **When** user installs new apps, **Then** cache refresh runs on every activation (idempotent)

### User Story 3 - Clear Installation Progress Communication (Priority: P3)

User installing NixOS receives clear, informative messages explaining what's happening during the first boot delay (home-manager building) and why they should wait.

**Why this priority**: Manages user expectations during 2-5 minute first-boot delay. Prevents confusion ("is it frozen?"). Educates users about the one-time setup process.

**Independent Test**: Can be tested by observing boot messages during first-boot service execution, verifying clarity and accuracy of messages.

**Acceptance Scenarios**:

1. **Given** first boot starting, **When** systemd boot messages appear, **Then** user sees "Starting First boot home-manager setup..." message
1. **Given** home-manager building, **When** user observes console output, **Then** progress messages show "Cloning repository...", "Building home-manager...", "Activating configuration..."
1. **Given** first-boot service completes, **When** GDM starts, **Then** final message shows "Home-manager setup complete! You may now log in."
1. **Given** user viewing boot messages, **When** reading service description, **Then** description clearly states this is one-time setup (won't run on subsequent boots)

### Edge Cases

- **What happens when first-boot service fails?** GDM starts anyway (no infinite boot loop), user can manually run home-manager or retry installation
- **How does system handle network failures during first-boot?** Service fails gracefully, GDM starts, user can re-run manually after fixing network
- **What if home-manager build takes >10 minutes?** User sees boot messages showing progress, no timeout on service (waits indefinitely)
- **How does this affect console-only installations (no GUI)?** No `graphical.target` to block, service runs normally, no impact on console systems
- **What happens on subsequent reboots?** Marker file removed after first run, service never runs again (condition not met)
- **How does this affect non-GNOME desktops?** Desktop cache refresh uses `update-desktop-database` (standard tool), works with KDE/XFCE/etc.
- **What if user uses different display manager (LightDM, SDDM)?** All display managers respect `graphical.target` ordering, solution works universally

## Requirements

### Functional Requirements

- **FR-001**: First-boot systemd service MUST block `graphical.target` until home-manager activation completes (`before = ["graphical.target"]`)
- **FR-002**: Home-manager activation MUST automatically run `update-desktop-database ~/.local/share/applications` after writing desktop files
- **FR-003**: Desktop cache refresh MUST be non-blocking (activation succeeds even if cache update fails)
- **FR-004**: System MUST log first-boot service progress to systemd journal for troubleshooting
- **FR-005**: First-boot service script MUST display clear progress messages ("Cloning repository", "Building home-manager", "Activating")
- **FR-006**: Systemd service MUST use `Type = "oneshot"` to ensure blocking behavior
- **FR-007**: Service MUST use `RemainAfterExit = true` to keep service "active" after completion (satisfies dependency)
- **FR-008**: System MUST remove first-boot marker file after successful completion (prevent re-running)
- **FR-009**: Desktop cache refresh MUST run in home-manager activation DAG after file writes complete (`lib.hm.dag.entryAfter ["writeBoundary"]`)

### Non-Functional Requirements

- **NFR-001**: First-boot service MUST complete within reasonable time (2-5 minutes typical, no hard timeout)
- **NFR-002**: Boot delay MUST be visible to user via console/boot messages (not silent hang)
- **NFR-003**: Solution MUST work on all NixOS installations (VMs, bare-metal, laptops, servers)
- **NFR-004**: Solution MUST preserve Feature 036 architecture (standalone home-manager)
- **NFR-005**: Solution MUST not introduce new failure modes (graceful degradation on errors)
- **NFR-006**: Desktop cache refresh MUST complete in \<2 seconds on systems with \<500 desktop files

### Key Entities

- **First-Boot Service**: Systemd service (`nix-config-first-boot.service`) running home-manager activation before user login
- **Systemd Ordering**: Dependency relationships between boot targets (network → first-boot → graphical)
- **Desktop File Cache**: GNOME/FreeDesktop database (`mimeinfo.cache`) mapping applications to file types
- **Graphical Target**: Systemd target representing display manager readiness (`graphical.target`)
- **First-Boot Marker**: File (`~/.nix-config-first-boot`) created during installation, consumed by service, removed after success

## Success Criteria

### Measurable Outcomes

- **SC-001**: NixOS installations require only 2 reboots (ISO → functional desktop) instead of 3 (33% reduction)
- **SC-002**: 100% of configured applications visible in GNOME application menu and dock after first login
- **SC-003**: First-boot service completes before GDM starts on 100% of installations (verified via systemd journal ordering)
- **SC-004**: Desktop cache refresh succeeds automatically on 100% of installations (logged and verified)
- **SC-005**: Installation time reduces by 2-5 minutes compared to current 3-reboot flow
- **SC-006**: Zero cases of users logging in before home-manager completes (blocked by systemd)
- **SC-007**: First-boot service failure rate remains at current baseline (no new failure modes introduced)
- **SC-008**: User satisfaction with installation experience improves from current baseline (measured via feedback)
- **SC-009**: Support requests related to "apps not appearing" reduce by 90% (from 3rd-reboot confusion)

## Assumptions

- Users have network connectivity during first boot (required for cloning repository and building home-manager)
- Users can wait 2-5 minutes at boot screen during first-boot service (acceptable one-time delay)
- GNOME or compatible desktop environment reads desktop file cache at session startup
- Systemd ordering guarantees are reliable (`before` directive blocks dependent targets)
- Feature 036 architecture (standalone home-manager) remains non-negotiable
- Installation uses `install-remote.sh` script (creates first-boot marker)
- Agenix private key copied during installation (required for secret decryption)

## Scope Boundaries

### In Scope

- ✅ Systemd service ordering fix (`before = ["graphical.target"]`)
- ✅ Automatic desktop cache refresh during home-manager activation
- ✅ Clear progress messaging during first-boot service execution
- ✅ Works on ALL NixOS installations (VMs, bare-metal, laptops, desktops)
- ✅ Works with any display manager (GDM, LightDM, SDDM)
- ✅ Works with any desktop environment (GNOME, KDE, XFCE)

### Out of Scope

- ❌ Module-integrated home-manager mode (conflicts with Darwin compatibility, Feature 036)
- ❌ Automatic logout mechanisms (not needed, systemd blocks login until ready)
- ❌ X11-specific workarounds (Wayland is modern standard, X11 is legacy)
- ❌ Eliminating ISO reboot (mandatory boundary, cannot be removed)
- ❌ Console-only installations (no graphical.target to block, works as-is)
- ❌ Alternative installation methods (manual nixos-install without install-remote.sh)

## Implementation Notes

### Recommended Approach

**Phase 1: Systemd Ordering Fix** (Primary solution - 90% of value)

1. Modify `system/nixos/settings/system/first-boot.nix`:

   ```nix
   systemd.services.nix-config-first-boot = {
     # ... existing configuration ...
     before = ["graphical.target"];  # Add this line
   };
   ```

1. Test ordering:

   ```bash
   # After boot, verify service ran before GDM
   systemctl show -p After nix-config-first-boot.service
   systemctl show -p Before nix-config-first-boot.service
   journalctl -u nix-config-first-boot.service
   journalctl -u display-manager.service
   ```

**Phase 2: Automatic Cache Refresh** (Complementary - ensures reliability)

1. Add activation script to GNOME dock module (`system/shared/family/gnome/settings/user/dock.nix`):

   ```nix
   home.activation.refreshDesktopCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
     run ${pkgs.desktop-file-utils}/bin/update-desktop-database \
       -q "$HOME/.local/share/applications" 2>/dev/null || true
     $VERBOSE_ECHO "Desktop file cache refreshed"
   '';
   ```

1. Make idempotent and non-blocking (shown above with `|| true`)

**Phase 3: Progress Messaging** (Polish - improves UX)

1. Enhance existing script messages in `/etc/nix-config-first-boot.sh`:

   ```bash
   echo "==> [1/4] Cloning nix-config repository..."
   echo "==> [2/4] Building home-manager configuration..."
   echo "==> [3/4] Installing user applications..."
   echo "==> [4/4] Activating configuration..."
   echo "==> Setup complete! Starting login screen..."
   ```

1. Ensure messages visible in systemd journal and console

**Phase 4: Documentation Updates**

1. Update `CLAUDE.md` installation flow section (remove 3rd-reboot reference)
1. Add comment in `first-boot.nix` explaining systemd ordering
1. Update any user-facing docs mentioning reboot count

### Files to Modify

- `system/nixos/settings/system/first-boot.nix` - Add `before = ["graphical.target"]` (1 line change)
- `system/shared/family/gnome/settings/user/dock.nix` - Add desktop cache refresh activation script (~5 lines)
- `CLAUDE.md` - Update installation flow documentation
- Existing: `/etc/nix-config-first-boot.sh` script (enhance progress messages)

### Testing Plan

1. **Test on VM**: Install qemu-gnome-vm from ISO, verify apps appear on first login
1. **Test on bare-metal**: Install on physical machine, verify same behavior
1. **Test service ordering**: Check systemd journal shows service before GDM
1. **Test cache refresh**: Verify `update-desktop-database` runs and succeeds
1. **Test failure modes**: Kill network during first-boot, verify graceful failure
1. **Test subsequent boots**: Verify service never runs again (marker removed)

## Constitutional Compliance

- **Module Size**: Changes total \<20 lines across all files (\<200 line limit)
- **App-Centric**: No app-level changes (system/settings level only)
- **Platform Abstraction**: NixOS-specific changes in `system/nixos/`, GNOME-specific in `family/gnome/`
- **Pure Data Pattern**: No changes to host/user configuration schema
- **Documentation**: All changes documented inline and in CLAUDE.md

## Related Features

- **Feature 036**: Standalone home-manager mode (architectural foundation, preserved by this fix)
- **Feature 028**: GNOME family system integration (desktop environment configuration)
- **Feature 031**: Per-user secrets (agenix key distribution during installation)
- **Feature 023**: User dock configuration (benefits from reliable desktop file cache)

## Sources

Research findings based on:

- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Official documentation
- [Home Manager - NixOS Wiki](https://nixos.wiki/wiki/Home_Manager) - Community best practices
- [systemd.unit man page](https://www.freedesktop.org/software/systemd/man/systemd.unit.html) - Systemd ordering directives
- [systemd.special man page](https://www.freedesktop.org/software/systemd/man/systemd.special.html) - Boot target documentation
- Internal codebase analysis: `install-remote.sh`, `first-boot.nix`, `home-manager.nix`, `gnome-core.nix`, `dock.nix`
