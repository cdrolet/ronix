# Quickstart Guide: Testing Single-Reboot Installation

**Feature**: 040-single-reboot-installation\
**Date**: 2026-01-15\
**Purpose**: Step-by-step testing procedures for implementation validation

## Prerequisites

- QEMU installed (for VM testing)
- Spare bare-metal machine (optional, for final validation)
- Network connectivity (required for package downloads)
- Agenix private key available (for secret decryption)

## Test Environment Setup

### Option 1: QEMU VM (Recommended for Development)

**Build Installation ISO**:

```bash
# From repository root
cd /path/to/nix-config

# Build ISO for qemu-gnome-vm host
nix build ".#nixosConfigurations.cdrokar-qemu-gnome-vm.config.system.build.isoImage"

# ISO location
ls result/iso/*.iso
# Example: nixos-25.05.20260115.abcd123-x86_64-linux.iso
```

**Launch VM**:

```bash
# Start QEMU with 4GB RAM, KVM acceleration
qemu-system-x86_64 \
  -cdrom result/iso/nixos-*.iso \
  -m 4096 \
  -enable-kvm \
  -cpu host \
  -smp 2 \
  -boot d \
  -drive file=vm-disk.qcow2,format=qcow2,if=virtio \
  -net nic,model=virtio \
  -net user

# First run: Create disk image
qemu-img create -f qcow2 vm-disk.qcow2 20G
```

### Option 2: Bare-Metal Installation

**Requirements**:

- Spare physical machine (or partition)
- USB drive for ISO image
- Backup of existing data (installation will erase disk)

**Create Bootable USB**:

```bash
# Burn ISO to USB drive (replace /dev/sdX with actual device)
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

## Installation Test Procedure

### Phase 1: ISO Boot and Installation

**Step 1: Boot from ISO**

```bash
# VM: Already booted from -cdrom
# Bare-metal: Boot from USB, select "NixOS Installer" from menu

# Wait for ISO to load (1-2 minutes)
# Expected: Live environment shell prompt
```

**Step 2: Run Installation Script**

```bash
# In ISO environment
cd /tmp
git clone https://github.com/yourusername/nix-config.git
cd nix-config

# Run installer with user and host
bash install-remote.sh cdrokar qemu-gnome-vm

# Expected prompts:
# 1. "Enter agenix private key" (paste key content)
# 2. "Disk will be erased, continue?" (yes)
# 3. Progress messages (partitioning, copying, installing)
# 4. "Reboot now? (y/n)" (y)

# Timing: 5-10 minutes depending on network speed
```

**Verification**:

```bash
# Before rebooting, verify marker file created
ls -l /mnt/home/cdrokar/.nix-config-first-boot
# Expected: File exists with 3 lines (user, host, repo URL)

# Verify agenix key copied
ls -l /mnt/home/cdrokar/.config/agenix/key.txt
# Expected: File exists with private key content
```

### Phase 2: First Boot (The Critical Test)

**Step 3: Reboot and Observe**

```bash
# System reboots automatically (or manual reboot)
# VM: Watch QEMU window
# Bare-metal: Watch physical screen

# Expected behavior:
# T=0s   Kernel boots (1-2 minutes)
# T=2m   Systemd services start
# T=3m   Console shows: "Starting First boot home-manager setup..."
# T=3m   Console shows: "Cloning nix-config repository..."
# T=4m   Console shows: "Building home-manager configuration..."
# T=6m   Console shows: "Activating configuration..."
# T=8m   Console shows: "Desktop file cache refreshed"
# T=8m   Console shows: "Finished First boot home-manager setup."
# T=8m   GDM login screen appears ← KEY MOMENT
```

**What to Watch For**:

- ✅ **GOOD**: GDM login screen appears AFTER "Finished First boot..." message
- ❌ **BAD**: GDM login screen appears BEFORE or DURING first-boot service (ordering broken)
- ❌ **BAD**: Boot hangs indefinitely (timeout needed)
- ❌ **BAD**: Service fails with errors (check implementation)

**Step 4: First Login**

```bash
# At GDM login screen
# Enter username: cdrokar
# Enter password: (your password)

# Wait for GNOME session to start (30-60 seconds)
# Expected: Desktop appears with wallpaper, dock visible

# KEY VERIFICATION: Check dock and application menu
# Click "Show Applications" (grid icon) in dock
```

**Success Criteria**:

- ✅ All configured applications visible in application menu
- ✅ Dock shows favorite apps (zen, brave, mail, etc.)
- ✅ No need to log out and back in
- ✅ Apps launch successfully when clicked

**Failure Indicators**:

- ❌ Application menu empty or shows only basic apps
- ❌ Dock empty or missing configured favorites
- ❌ Apps present but don't launch (different issue)

### Phase 3: Systemd Verification

**Step 5: Check Service Execution Order**

```bash
# Open terminal (gnome-terminal or ghostty)

# Check first-boot service status
systemctl status nix-config-first-boot.service

# Expected output:
# ● nix-config-first-boot.service - First boot home-manager setup
#    Loaded: loaded (/etc/systemd/system/nix-config-first-boot.service; ...)
#    Active: inactive (dead) since ...
#    Condition: ConditionPathExists=/home/cdrokar/.nix-config-first-boot was not met
#
# Note: "was not met" means marker file removed (good!)

# Check service ran BEFORE display manager
journalctl -b -u nix-config-first-boot.service -u display-manager.service -o short-precise

# Expected order:
# 12:34:56.123 systemd[1]: Starting First boot home-manager setup...
# 12:38:45.678 systemd[1]: Finished First boot home-manager setup.
# 12:38:45.901 systemd[1]: Starting Display Manager...  ← After first-boot!
# 12:38:46.234 systemd[1]: Started Display Manager.
```

**Timing Verification**:

```bash
# Extract exact timestamps
journalctl -b -u nix-config-first-boot.service --no-pager | grep -E "Starting|Finished"
journalctl -b -u display-manager.service --no-pager | grep "Starting"

# Calculate time difference (first-boot finish → GDM start)
# Expected: <1 second (immediate transition after service completes)
```

**Step 6: Check Systemd Ordering Configuration**

```bash
# Verify 'before' directive is set
systemctl show -p Before nix-config-first-boot.service | grep graphical.target

# Expected output:
# Before=graphical.target

# Verify service dependencies
systemctl show -p After nix-config-first-boot.service

# Expected output includes:
# After=network-online.target
```

### Phase 4: Desktop Cache Verification

**Step 7: Check Cache File Freshness**

```bash
# Verify cache file exists
stat ~/.local/share/applications/mimeinfo.cache

# Expected output:
# File: /home/cdrokar/.local/share/applications/mimeinfo.cache
# Size: ~10KB
# Modify: 2026-01-15 12:38:44 (recent timestamp)

# Compare cache timestamp with desktop files
ls -lt ~/.local/share/applications/*.desktop | head -5
ls -lt ~/.local/share/applications/mimeinfo.cache

# Expected: mimeinfo.cache timestamp >= desktop file timestamps
```

**Step 8: Check Activation Log**

```bash
# Search for desktop cache refresh message
journalctl -b _COMM=systemd --no-pager | grep -i "desktop.*cache"

# Expected output:
# Desktop file cache refreshed

# Check home-manager activation succeeded
journalctl -b -u nix-config-first-boot.service --no-pager | grep -i "activation"

# Expected: No error messages, "activation complete" or similar
```

**Step 9: Verify GNOME Configuration**

```bash
# Check dock favorites (should match user configuration)
gsettings get org.gnome.shell favorite-apps

# Expected output (example):
# ['zen-browser.desktop', 'brave-browser.desktop', 'org.gnome.Geary.desktop', ...]

# Verify apps launch successfully
gtk-launch zen-browser.desktop
# Expected: Zen browser opens
```

## Bare-Metal Validation (Optional)

**When to Run**:

- After VM testing succeeds
- Before merging to main branch
- To verify hardware compatibility

**Procedure**:

- Follow same steps as VM testing
- Use physical machine instead of QEMU
- Timing may differ slightly (faster/slower depending on hardware)
- All verification commands identical

**Additional Checks**:

```bash
# Verify not running in VM
systemd-detect-virt
# Expected: none (bare-metal) or qemu/kvm (VM)

# Check hardware-specific services
systemctl status qemu-guest-agent.service
# Expected: inactive/disabled on bare-metal (ConditionVirtualization=vm)
```

## Troubleshooting

### Service Doesn't Run

**Symptom**: GDM appears immediately, apps not visible, marker file still exists

**Diagnosis**:

```bash
# Check if marker file exists (should be removed after first run)
ls -l ~/.nix-config-first-boot
# If exists: Service didn't run or failed early

# Check service logs
journalctl -u nix-config-first-boot.service --no-pager

# Common issues:
# - Network unavailable (check network-online.target)
# - Repository clone failed (check SSH keys, URLs)
# - Home-manager build failed (check Nix errors)
```

**Resolution**:

```bash
# Manual home-manager activation
cd ~/.config/nix-config
nix build ".#homeConfigurations.\"cdrokar@qemu-gnome-vm\".activationPackage"
./result/activate

# Remove marker file to prevent re-run
rm ~/.nix-config-first-boot

# Reboot to test GDM blocking
sudo reboot
```

### Service Runs But Apps Not Visible

**Symptom**: First-boot service succeeds, cache updated, but GNOME shows no apps

**Diagnosis**:

```bash
# Verify desktop files exist
ls ~/.local/share/applications/*.desktop | wc -l
# Expected: >10 files (depending on configuration)

# Verify cache exists and is recent
stat ~/.local/share/applications/mimeinfo.cache

# Check GNOME Shell is reading cache
dconf read /org/gnome/shell/favorite-apps
# Should show list of .desktop files
```

**Resolution**:

```bash
# Manually refresh cache
update-desktop-database ~/.local/share/applications

# Restart GNOME session (logout and login again)
# OR on X11 only: Alt+F2 → type "r" → Enter

# If still broken: Check dconf settings
dconf dump /org/gnome/shell/
# Verify favorite-apps is set correctly
```

### GDM Starts Before Service Completes

**Symptom**: Login screen appears while first-boot service still running (CRITICAL BUG)

**Diagnosis**:

```bash
# Check systemd ordering (verify 'before' directive exists)
systemctl cat nix-config-first-boot.service | grep -i before

# Expected output:
# Before=graphical.target

# If missing: Implementation bug, systemd ordering not applied
```

**Resolution**:

- Fix implementation: Ensure `before = ["graphical.target"]` in first-boot.nix
- Rebuild system: `nixos-rebuild switch`
- Test again from ISO (full reinstall)

### Service Hangs Indefinitely

**Symptom**: Boot stuck at "Starting First boot home-manager setup..." for >15 minutes

**Diagnosis**:

```bash
# From another TTY (Ctrl+Alt+F2)
journalctl -fu nix-config-first-boot.service

# Check what step it's stuck on:
# - "Cloning repository" → Network/SSH issue
# - "Building home-manager" → Nix build error
# - No output → Script crashed early
```

**Resolution**:

```bash
# Kill hanging service (allow GDM to start)
sudo systemctl stop nix-config-first-boot.service

# Investigate logs
journalctl -u nix-config-first-boot.service --no-pager | less

# Fix issue and re-run manually (see "Service Doesn't Run" resolution)
```

## Success Checklist

- [ ] ISO installation completes without errors
- [ ] Marker file created during nixos-install
- [ ] Agenix key copied to ~/.config/agenix/key.txt
- [ ] System reboots successfully
- [ ] First-boot service runs before GDM starts
- [ ] Service completes within reasonable time (2-10 minutes)
- [ ] GDM login screen appears after service finishes
- [ ] First login successful
- [ ] All configured apps visible in GNOME application menu
- [ ] Dock shows favorite apps correctly
- [ ] Apps launch successfully
- [ ] Marker file removed after first-boot
- [ ] Service won't run on subsequent boots
- [ ] Desktop cache file exists and is fresh
- [ ] No errors in systemd journal

## Performance Metrics

**Expected Timings** (VM on modern hardware):

| Phase | Duration | Notes |
|-------|----------|-------|
| ISO boot | 1-2 min | Depends on ISO size |
| nixos-install | 5-10 min | Depends on network speed |
| First boot (kernel) | 1-2 min | Hardware-dependent |
| First-boot service | 2-5 min | Repository clone + build |
| Desktop cache refresh | \<2 sec | Fast operation |
| GDM startup | 10-30 sec | Display manager init |
| GNOME session start | 30-60 sec | Desktop environment load |
| **Total (ISO → Functional Desktop)** | **10-20 min** | Single reboot |

**Comparison to Old Flow**:

| Metric | Old (3 reboots) | New (2 reboots) | Improvement |
|--------|----------------|-----------------|-------------|
| Total reboots | 3 | 2 | -33% |
| Total logins | 2 | 1 | -50% |
| Installation time | 15-25 min | 10-20 min | -5 min avg |
| User confusion | High | Low | Qualitative |

## Next Steps After Testing

1. **Document findings** in test results file
1. **Update CLAUDE.md** if installation flow differs from expectations
1. **Create user documentation** for new installation experience
1. **Commit changes** with test validation evidence
1. **Optional**: Run bare-metal validation before merging
