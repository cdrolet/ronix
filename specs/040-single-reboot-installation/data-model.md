# Data Model: Single-Reboot NixOS Installation

**Feature**: 040-single-reboot-installation\
**Date**: 2026-01-15\
**Purpose**: Define installation state machine, transitions, and invariants

## State Machine

### States

| State | Description | Visible Artifacts | User Actions Available |
|-------|-------------|-------------------|----------------------|
| **ISO_BOOTED** | Live ISO environment running | Installation prompt | Run install-remote.sh |
| **SYSTEM_INSTALLED** | NixOS installed to disk, first-boot marker created | Filesystem on /mnt, marker file | Reboot system |
| **FIRST_BOOT_STARTING** | System booting, services initializing | Boot messages | Wait (no interaction) |
| **FIRST_BOOT_IN_PROGRESS** | nix-config-first-boot.service running | Console output, systemd journal | Wait (GDM blocked) |
| **FIRST_BOOT_COMPLETE** | Home-manager activated, desktop cache fresh | Desktop files, cache, profile links | None (automatic transition) |
| **GDM_READY** | Display manager started, login screen visible | GDM login screen | Enter credentials |
| **USER_LOGGED_IN** | GNOME session active, apps visible | Full desktop, dock, apps | Use system normally |

### Transitions

```
ISO_BOOTED
    │ (install-remote.sh completes)
    ├─ Creates: /mnt/home/{user}/.nix-config-first-boot
    ├─ Creates: /mnt/home/{user}/.config/agenix/key.txt
    ├─ Runs: nixos-install --flake ".#{user}-{host}"
    └─ Prompts: "Reboot now?"
    ↓
SYSTEM_INSTALLED
    │ (User reboots system)
    └─ Kernel loads, systemd starts
    ↓
FIRST_BOOT_STARTING
    │ (network-online.target reached)
    ├─ Checks: ConditionPathExists=/home/{user}/.nix-config-first-boot
    └─ Starts: nix-config-first-boot.service
    ↓
FIRST_BOOT_IN_PROGRESS
    │ (Service executes /etc/nix-config-first-boot.sh)
    ├─ Clones: nix-config repository
    ├─ Builds: home-manager activation package
    ├─ Activates: home-manager (desktop files, configs)
    ├─ Refreshes: desktop file cache (update-desktop-database)
    ├─ Removes: first-boot marker file
    └─ Exits: Service completes (RemainAfterExit=true)
    ↓
FIRST_BOOT_COMPLETE
    │ (graphical.target unblocked)
    └─ Starts: display-manager.service (GDM)
    ↓
GDM_READY
    │ (User enters credentials)
    └─ Launches: GNOME session
    ↓
USER_LOGGED_IN
    │ (GNOME Shell reads desktop cache)
    ├─ Loads: favorite-apps from dconf
    ├─ Indexes: .desktop files from cache
    └─ Displays: full application menu + dock
    ↓
(Normal Operation)
```

### Timing Diagram

```
Time →

T=0     ISO_BOOTED
        │ install-remote.sh
        │ (5-10 minutes: download packages, install)
T=10m   SYSTEM_INSTALLED
        │ User reboots
        │
T=10m   ┌─────────────────────────────────────────┐
        │ Boot #1: Kernel + Systemd Init          │
T=11m   ├─────────────────────────────────────────┤
        │ FIRST_BOOT_STARTING                     │
        │ - network-online.target reached         │
        │ - Service condition checked ✓           │
        │ - nix-config-first-boot.service starts  │
T=11m   ├─────────────────────────────────────────┤
        │ FIRST_BOOT_IN_PROGRESS                  │
        │ ╔═══════════════════════════════════╗   │
        │ ║ [BLOCKING graphical.target]       ║   │
        │ ║                                   ║   │
        │ ║ - Clone repository      (30s)    ║   │
T=12m   ║ ║ - Build home-manager    (2-4m)   ║   │
        │ ║ - Run activation        (30s)    ║   │
T=15m   ║ ║ - Refresh desktop cache (<2s)    ║   │
        │ ║ - Remove marker file    (<1s)    ║   │
        │ ╚═══════════════════════════════════╝   │
T=15m   ├─────────────────────────────────────────┤
        │ FIRST_BOOT_COMPLETE                     │
        │ - Service exits (RemainAfterExit=true)  │
        │ - graphical.target UNBLOCKED ✓          │
T=15m   ├─────────────────────────────────────────┤
        │ GDM_READY                               │
        │ - GDM starts                            │
        │ - Login screen appears                  │
        └─────────────────────────────────────────┘
        │ User logs in
        │
T=16m   ┌─────────────────────────────────────────┐
        │ USER_LOGGED_IN                          │
        │ - GNOME Shell starts                    │
        │ - Reads fresh desktop cache ✓           │
        │ - Apps visible immediately ✓            │
        └─────────────────────────────────────────┘

Total Time: ~16 minutes (ISO → Functional Desktop)
Reboots: 1 (ISO → System)
Logins: 1 (First login successful)
```

## Invariants

### System Invariants

1. **Ordering Invariant**: `graphical.target` MUST NOT start while `nix-config-first-boot.service` is in FIRST_BOOT_IN_PROGRESS state

   - **Enforced by**: `before = ["graphical.target"]` in service definition
   - **Verified by**: `systemctl show -p Before nix-config-first-boot.service`

1. **Completion Invariant**: Service MUST remain "active" after completion to satisfy `graphical.target` dependency

   - **Enforced by**: `RemainAfterExit = true` in service config
   - **Verified by**: `systemctl status nix-config-first-boot.service` shows "active (exited)"

1. **Idempotency Invariant**: Service MUST run exactly once per installation

   - **Enforced by**: `ConditionPathExists=/home/{user}/.nix-config-first-boot` + marker file removal
   - **Verified by**: Marker file absent after first boot, service skipped on subsequent boots

1. **Cache Freshness Invariant**: Desktop file cache MUST be updated before first GNOME session starts

   - **Enforced by**: `lib.hm.dag.entryAfter ["writeBoundary"]` in activation + systemd ordering
   - **Verified by**: `mimeinfo.cache` timestamp after `.desktop` files

### Failure Invariants

1. **Network Failure**: If network unavailable, service fails gracefully, GDM starts anyway

   - **Behavior**: `wants = ["network-online.target"]` (soft dependency)
   - **User Recovery**: Manual home-manager activation after fixing network

1. **Build Failure**: If home-manager build fails, service exits non-zero, GDM starts anyway

   - **Behavior**: Service does not block boot indefinitely
   - **User Recovery**: Check `journalctl -u nix-config-first-boot`, fix config, re-run manually

1. **Cache Refresh Failure**: If `update-desktop-database` fails, activation continues

   - **Behavior**: `|| true` in activation script (non-blocking)
   - **User Recovery**: Apps work but may not appear in menu, re-run `update-desktop-database` manually

## File System State

### Marker File

**Path**: `/home/{username}/.nix-config-first-boot`

**Format**: Plain text, 3 lines

```
{username}
{hostname}
{repository_url}
```

**Lifecycle**:

- **Created**: During `nixos-install` by `install-remote.sh`
- **Read**: By systemd service condition + activation script
- **Removed**: After successful home-manager activation
- **Purpose**: One-time activation trigger, prevents re-running service

### Desktop File Cache

**Path**: `~/.local/share/applications/mimeinfo.cache`

**Format**: INI-style, generated by `update-desktop-database`

```ini
[MIME Cache]
application/pdf=org.gnome.Evince.desktop;firefox.desktop;
text/html=firefox.desktop;chromium.desktop;
...
```

**Lifecycle**:

- **Created**: By `update-desktop-database` during home-manager activation
- **Read**: By GNOME Shell at session startup
- **Updated**: On every home-manager activation (idempotent)
- **Purpose**: Map file types to applications for GNOME application menu

### Home-Manager Profile

**Path**: `~/.local/state/nix/profiles/home-manager`

**Format**: Symlink to Nix store derivation

```
~/.local/state/nix/profiles/home-manager -> /nix/store/{hash}-home-manager-path
```

**Lifecycle**:

- **Created**: By `nix-env --profile ... --set` during first-boot activation
- **Updated**: On every home-manager activation (new generation)
- **Purpose**: Track home-manager generations, enable rollback

## Systemd Service Definition

### Service File (Generated)

**Location**: `/etc/systemd/system/nix-config-first-boot.service` (generated from NixOS module)

**Content**:

```ini
[Unit]
Description=First boot home-manager setup
After=network-online.target
Before=graphical.target                    # NEW: Blocks GDM
Wants=network-online.target
ConditionPathExists=/home/{user}/.nix-config-first-boot

[Service]
Type=oneshot                               # Blocking execution
User={username}
Group=users
ExecStart=/etc/nix-config-first-boot.sh
RemainAfterExit=true                       # Keep "active" after exit
StandardOutput=journal
StandardError=journal
Environment=PATH=/run/current-system/sw/bin:...
Environment=HOME=/home/{username}

[Install]
WantedBy=multi-user.target
```

### Dependencies Graph

```
multi-user.target
    │
    ├─ wants ──→ nix-config-first-boot.service
    │                │
    │                ├─ after: network-online.target
    │                └─ before: graphical.target
    │                            │
    └─────────────────────────── wants ──→ display-manager.service
                                            │
                                            └─ starts: GDM
```

## Home-Manager Activation

### Activation DAG

```
Home-Manager Activation Phases:

1. writeBoundary
   │ (All files written to filesystem)
   ├─ Desktop files: ~/.local/share/applications/*.desktop
   ├─ Config files: ~/.config/*
   └─ Profile links: ~/.nix-profile
   ↓
2. refreshDesktopCache (NEW)
   │ lib.hm.dag.entryAfter ["writeBoundary"]
   ├─ Run: update-desktop-database ~/.local/share/applications
   └─ Result: mimeinfo.cache updated
   ↓
3. linkGeneration
   │ (Profile generation link created)
   └─ Complete: Activation successful
```

### Activation Script (Generated)

**Location**: `/nix/store/{hash}-home-manager-path/activate`

**Relevant Section**:

```bash
# After writeBoundary phase
if [[ -d "$HOME/.local/share/applications" ]]; then
  run /nix/store/{hash}-desktop-file-utils/bin/update-desktop-database \
    -q "$HOME/.local/share/applications" 2>/dev/null || true
  $VERBOSE_ECHO "Desktop file cache refreshed"
fi
```

## Verification Queries

### Check Service Ran Before GDM

```bash
# Show service started before graphical.target
journalctl -b -u nix-config-first-boot.service -u display-manager.service -o short-precise

# Expected output order:
# 12:34:56.123 systemd[1]: Starting First boot home-manager setup...
# 12:38:23.456 systemd[1]: Finished First boot home-manager setup.
# 12:38:23.789 systemd[1]: Starting Display Manager...  ← After first-boot!
```

### Check Desktop Cache Freshness

```bash
# Compare timestamps: cache should be newer than desktop files
stat -c '%Y %n' ~/.local/share/applications/*.desktop ~/.local/share/applications/mimeinfo.cache | sort -n

# Expected: mimeinfo.cache timestamp >= all .desktop file timestamps
```

### Check Service Won't Run Again

```bash
# Verify marker file removed
test -f ~/.nix-config-first-boot && echo "Marker exists (ERROR)" || echo "Marker removed (OK)"

# Verify service skips on next boot
sudo systemctl status nix-config-first-boot.service
# Expected: "Condition: ... was not met" (service skipped)
```

## State Validation

| State | Validation Command | Expected Result |
|-------|-------------------|----------------|
| SYSTEM_INSTALLED | `test -f /home/{user}/.nix-config-first-boot` | Exit 0 (marker exists) |
| FIRST_BOOT_IN_PROGRESS | `systemctl is-active nix-config-first-boot.service` | "activating" or "active" |
| FIRST_BOOT_COMPLETE | `systemctl show -p ActiveState nix-config-first-boot.service` | "ActiveState=inactive" + "SubState=exited" |
| GDM_READY | `systemctl is-active display-manager.service` | "active" |
| USER_LOGGED_IN | `pgrep gnome-shell` | Non-empty (shell running) |
| Cache Fresh | `stat ~/.local/share/applications/mimeinfo.cache` | Exit 0 (cache exists) |

## Error States

### Service Hangs (Timeout Needed?)

**Current**: No timeout defined, service can run indefinitely

**Risk**: Network issues, build failures could block boot forever

**Mitigation Options**:

1. Add `TimeoutStartSec=600` (10 minute timeout)
1. Document manual recovery: Boot to previous generation from bootloader
1. Service already has graceful failure (network failure → skip)

**Decision**: ⚠️ Consider adding timeout in implementation (not critical for MVP)

### Desktop Cache Stale After Update

**Scenario**: User installs new apps via `nixos-rebuild` (not first-boot)

**Current Behavior**: Cache NOT refreshed automatically

**Solution**: Cache refresh runs on EVERY home-manager activation (not just first-boot)

**Verification**: Activation script runs on all `nixos-rebuild switch` commands

______________________________________________________________________

## Summary

This data model defines the complete state machine for single-reboot installation:

- **7 states** from ISO boot to functional desktop
- **Clear transitions** with timing estimates
- **3 system invariants** enforcing ordering and idempotency
- **3 failure invariants** for graceful degradation
- **Verification queries** for testing and troubleshooting

The model demonstrates that **proper systemd ordering** (`before = ["graphical.target"]`) is the critical change that collapses FIRST_BOOT_IN_PROGRESS and GDM_READY into a sequential flow rather than parallel execution.
