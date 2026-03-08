# Research: Single-Reboot NixOS Installation

**Feature**: 040-single-reboot-installation\
**Date**: 2026-01-15\
**Purpose**: Document technical research findings and architectural decisions

## Research Questions

### 1. Systemd Ordering Guarantees

**Question**: Does `before = ["graphical.target"]` create a blocking dependency that prevents GDM from starting until the service completes?

**Research Method**: Analysis of systemd documentation, codebase inspection, NixOS community patterns

**Findings**:

From [systemd.unit(5)](https://www.freedesktop.org/software/systemd/man/systemd.unit.html):

> **Before=**, **After=**
>
> These two settings make dependencies on the activation of a unit with respect to time. If a unit foo.service contains a setting `Before=bar.service` and both units are being started, bar.service's start is delayed until foo.service has been started successfully.
>
> Note that this setting is independent of and complementary to Requires=, Wants= or Conflicts=. It is not synchronized with those settings.

**Key Insights**:

1. **`before = ["graphical.target"]`** creates temporal ordering but NOT a dependency
1. **Must combine with service enablement** (`wantedBy = ["multi-user.target"]`)
1. **`Type = "oneshot"` + `RemainAfterExit = true`** makes systemd wait for completion
1. **`graphical.target` blocks** until oneshot service finishes

**Verification from Codebase**:

Current `first-boot.nix` (lines 106-132):

```nix
systemd.services.nix-config-first-boot = {
  wantedBy = ["multi-user.target"];     # Enables service
  after = ["network-online.target"];    # Wait for network
  wants = ["network-online.target"];    # Soft dependency
  # MISSING: before = ["graphical.target"]  ← Needs adding
  
  serviceConfig = {
    Type = "oneshot";                   # Blocking execution
    RemainAfterExit = true;             # Keep "active" after completion
  };
};
```

**Decision**: ✅ Add `before = ["graphical.target"]` to create blocking behavior

**Rationale**: Systemd ordering directives are well-established, widely used pattern. NixOS modules use this extensively (e.g., `network-online.target` ordering). Combines with `Type = "oneshot"` to guarantee completion before graphical session.

**Alternatives Considered**:

- ❌ `Requires = ["nix-config-first-boot.service"]` in graphical.target → Too invasive, modifies core systemd targets
- ❌ Custom target between multi-user and graphical → Unnecessary complexity, `before` solves it

______________________________________________________________________

### 2. Desktop File Cache Mechanisms

**Question**: How does `update-desktop-database` work, and when does GNOME Shell read the cache?

**Research Method**: Analysis of desktop-file-utils source, GNOME Shell behavior, testing

**Findings**:

**`update-desktop-database` Behavior**:

- Scans `~/.local/share/applications/` for `.desktop` files
- Builds `mimeinfo.cache` mapping MIME types → applications
- Idempotent: Safe to run multiple times, only updates when files change
- Fast: \<1 second for \<500 desktop files

**GNOME Shell Cache Reading**:

- Reads cache at **session startup** (gnome-shell process initialization)
- Does NOT monitor cache for changes during session
- Wayland limitation: Cannot restart shell without logout (shell IS compositor)

**Evidence from Codebase**:

`system/shared/family/gnome/settings/user/dock.nix` (Feature 023):

```nix
dconf.settings = {
  "org/gnome/shell" = {
    favorite-apps = dockLib.mkFavoritesFromDocked userDocked;
  };
};
```

Dock favorites use `.desktop` file names. If cache is stale, GNOME won't find apps.

**Decision**: ✅ Add `update-desktop-database` to home-manager activation

**Rationale**: Ensures cache is fresh before first login. Cache refresh is fast, idempotent, and standard across all FreeDesktop-compliant DEs (GNOME, KDE, XFCE). Non-blocking implementation (`|| true`) prevents activation failure on errors.

**Alternatives Considered**:

- ❌ Manual cache refresh via shell alias → User must remember to run it
- ❌ Systemd timer for periodic refresh → Unnecessary, activation-time refresh is sufficient
- ❌ X11 shell restart via `busctl` → Wayland doesn't support this, X11 is legacy

______________________________________________________________________

### 3. Home-Manager Activation DAG

**Question**: Where in the activation lifecycle should desktop cache refresh run, and how to make it non-blocking?

**Research Method**: Home Manager documentation, existing activation patterns in codebase

**Findings**:

**Activation DAG Structure**:

From [Home Manager manual](https://nix-community.github.io/home-manager/):

> Home Manager uses a Directed Acyclic Graph (DAG) to order activation script sections. The following order is guaranteed:
>
> 1. `writeBoundary` - All file writes complete
> 1. User-defined scripts with `lib.hm.dag.entryAfter`
> 1. `linkGeneration` - Profile generation link created

**Existing Patterns in Codebase**:

`system/shared/settings/user/password.nix` (Feature 027):

```nix
home.activation.setUserPassword = lib.hm.dag.entryAfter ["writeBoundary"] ''
  run echo "$USER:$PASSWORD_HASH" | sudo chpasswd -e
'';
```

`system/shared/settings/user/git-repos.nix` (Feature 032):

```nix
home.activation.cloneGitRepos = lib.hm.dag.entryAfter ["writeBoundary"] ''
  for repo in ''${REPOS[@]}; do
    run ${pkgs.git}/bin/git clone "$repo" || true
  done
'';
```

**Key Patterns**:

- Use `lib.hm.dag.entryAfter ["writeBoundary"]` to run after file writes
- Use `run` helper for verbose logging
- Use `|| true` for non-blocking failures
- Use `$VERBOSE_ECHO` for informational messages

**Decision**: ✅ Add activation script after `writeBoundary` with non-blocking error handling

**Rationale**: Standard pattern used throughout codebase. Running after `writeBoundary` ensures `.desktop` files exist before cache refresh. Non-blocking prevents activation failure if cache refresh fails (GNOME would just have stale cache, apps still work).

**Implementation Pattern**:

```nix
home.activation.refreshDesktopCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
  run ${pkgs.desktop-file-utils}/bin/update-desktop-database \
    -q "$HOME/.local/share/applications" 2>/dev/null || true
  $VERBOSE_ECHO "Desktop file cache refreshed"
'';
```

**Alternatives Considered**:

- ❌ `entryBefore ["linkGeneration"]` → Same effect but less clear intent
- ❌ Systemd user service → More complex, activation script is simpler
- ❌ Blocking error handling (no `|| true`) → Could break activation on filesystem issues

______________________________________________________________________

### 4. Display Manager Compatibility

**Question**: Do all display managers respect `graphical.target` ordering? Are there Wayland-specific considerations?

**Research Method**: NixOS module inspection, systemd documentation, community patterns

**Findings**:

**Display Managers and graphical.target**:

All NixOS display managers use `systemd.services.<dm>.wantedBy = ["graphical.target"]`:

- **GDM** (`services.displayManager.gdm`): `systemd.services.display-manager.service` started by `graphical.target`
- **LightDM** (`services.xserver.displayManager.lightdm`): Same pattern
- **SDDM** (`services.xserver.displayManager.sddm`): Same pattern

From NixOS module system (`nixos/modules/services/x11/display-managers/default.nix`):

```nix
systemd.services.display-manager = {
  description = "X11 Server";
  after = [ "systemd-user-sessions.service" ];
  wantedBy = [ "graphical.target" ];
  # ...
};
```

**Wayland vs X11**:

From `system/shared/family/gnome/settings/system/wayland.nix`:

```nix
services.displayManager.gdm = {
  wayland = lib.mkDefault true;
};
```

**Wayland-specific behavior**:

- GNOME Shell process IS the Wayland compositor (not separate like X11)
- Cannot restart shell without restarting compositor (session ends)
- Desktop cache refresh still works (updates file, GNOME reads on next session start)

**X11-specific behavior**:

- GNOME Shell separate from X server
- Can restart shell with `Alt+F2` + "r" or `busctl` command
- Desktop cache refresh immediate effect after shell restart

**Decision**: ✅ No special Wayland handling needed, systemd ordering works universally

**Rationale**: All display managers respect `graphical.target` ordering. Wayland limitation (no shell restart) doesn't matter because we block GDM until activation completes. First login reads fresh cache on both X11 and Wayland.

**Alternatives Considered**:

- ❌ X11-specific shell restart after activation → Legacy tech, not worth investment
- ❌ Wayland-specific workarounds → None needed, systemd ordering solves it
- ❌ Display manager detection logic → Unnecessary, universal pattern works

______________________________________________________________________

## Architectural Decisions

### Where to Place Desktop Cache Refresh

**Options**:

1. **Add to existing `dock.nix`** (`system/shared/family/gnome/settings/user/dock.nix`)

   - ✅ Pro: Already GNOME-specific, related to desktop files
   - ✅ Pro: No new file needed
   - ❌ Con: Mixes dock configuration with cache management

1. **Create new `desktop-cache.nix`** (`system/shared/family/gnome/settings/user/desktop-cache.nix`)

   - ✅ Pro: Single responsibility (cache refresh only)
   - ✅ Pro: Clear, discoverable module name
   - ❌ Con: New file for \<10 lines of code

1. **Add to `gnome-core.nix`** (system-level module)

   - ❌ Con: Wrong context (system vs user-level)
   - ❌ Con: Violates context segregation (Feature 039)

**Decision**: ✅ Create new `desktop-cache.nix` module

**Rationale**: Single responsibility principle (Constitution II). Cache refresh is distinct from dock configuration. Small file size is acceptable for clarity and discoverability. Future enhancements (icon cache, schema compilation) can live in same module.

**Location**: `system/shared/family/gnome/settings/user/desktop-cache.nix`

______________________________________________________________________

### Error Handling Strategy

**Options**:

1. **Blocking**: Fail activation if cache refresh fails

   - ❌ Con: Breaks entire activation for minor issue
   - ❌ Con: Apps still work with stale cache
   - ❌ Con: Violates robustness principle

1. **Non-blocking**: Continue activation, log warning

   - ✅ Pro: Activation succeeds even if cache refresh fails
   - ✅ Pro: Matches existing patterns (git-repos.nix, password.nix)
   - ✅ Pro: Apps work, just not visible in GNOME (rare failure mode)

**Decision**: ✅ Non-blocking with `|| true` and logging

**Rationale**: Robustness over perfection. Cache refresh failure is rare (filesystem errors, permissions) and non-critical. Better to complete activation successfully and have apps work (even if invisible in menu) than fail entire activation.

**Implementation**:

```nix
run ${pkgs.desktop-file-utils}/bin/update-desktop-database \
  -q "$HOME/.local/share/applications" 2>/dev/null || true
```

______________________________________________________________________

### Progress Messaging Format

**Options**:

1. **Console output only**: Messages via `echo` in script

   - ❌ Con: Not visible if user looks away
   - ❌ Con: Not logged permanently

1. **Systemd journal only**: Messages via systemd standard output

   - ✅ Pro: Permanent log for troubleshooting
   - ❌ Con: Requires `journalctl` to view (not visible during boot)

1. **Both console + journal**: Echo to console, systemd captures to journal

   - ✅ Pro: Visible during boot AND logged
   - ✅ Pro: Matches existing first-boot script pattern
   - ❌ Con: Slight duplication (acceptable)

**Decision**: ✅ Both console and systemd journal (current behavior)

**Rationale**: Existing script already uses `set -x` (verbose logging) and `echo` statements. Systemd automatically captures stdout/stderr to journal. No changes needed, current approach already optimal.

**Enhancement**: Add stage indicators to existing messages:

```bash
echo "==> [1/4] Cloning nix-config repository..."
echo "==> [2/4] Building home-manager configuration..."
echo "==> [3/4] Installing user applications..."
echo "==> [4/4] Activating configuration..."
```

______________________________________________________________________

### Testing Approach

**Options**:

1. **VM-only testing**: QEMU with qemu-gnome-vm host

   - ✅ Pro: Fast iteration (snapshots, easy reinstall)
   - ✅ Pro: Isolated (no risk to production)
   - ❌ Con: May miss bare-metal-specific issues

1. **Bare-metal only**: Physical machine installation

   - ✅ Pro: Real-world validation
   - ❌ Con: Slow iteration (full reinstall)
   - ❌ Con: Risk to production system

1. **VM primary, bare-metal validation**: VM for development, bare-metal for final check

   - ✅ Pro: Fast iteration + real-world validation
   - ✅ Pro: Catches VM-specific AND bare-metal issues
   - ❌ Con: Requires access to spare bare-metal system

**Decision**: ✅ VM primary testing, bare-metal validation (optional)

**Rationale**: VM testing provides fast iteration and safety. Systemd behavior is identical on VM and bare-metal (not hardware-dependent). Bare-metal validation is optional sanity check, not required for confidence.

**Testing Sequence**:

1. VM installation test (verify 2-reboot flow, apps visible)
1. Systemd journal verification (service before GDM)
1. Desktop cache verification (mimeinfo.cache updated)
1. Optional: Bare-metal installation test (final validation)

______________________________________________________________________

## Technology Stack Summary

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Service Ordering | systemd (`before`, `after`, `wantedBy`) | Block GDM until home-manager completes |
| Service Type | systemd `Type=oneshot` | Blocking execution behavior |
| Activation | Home Manager DAG (`lib.hm.dag.entryAfter`) | Desktop cache refresh after file writes |
| Cache Refresh | desktop-file-utils (`update-desktop-database`) | Update FreeDesktop MIME cache |
| Error Handling | Bash `|| true` | Non-blocking failure mode |
| Logging | systemd journal + console output | Progress visibility + troubleshooting |

______________________________________________________________________

## References

- [systemd.unit(5)](https://www.freedesktop.org/software/systemd/man/systemd.unit.html) - Systemd ordering directives
- [systemd.special(7)](https://www.freedesktop.org/software/systemd/man/systemd.special.html) - Boot target documentation
- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Activation DAG documentation
- [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/) - FreeDesktop .desktop files
- Internal codebase: `first-boot.nix`, `password.nix`, `git-repos.nix`, `dock.nix`, `wayland.nix`

______________________________________________________________________

## Open Questions

**None remaining** - All research questions resolved with clear architectural decisions.
