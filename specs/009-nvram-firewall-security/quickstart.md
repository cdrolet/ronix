# Quickstart: NVRAM, Firewall, and Security Configuration

**Feature**: 009-nvram-firewall-security\
**Purpose**: Quick testing and verification guide\
**Audience**: Developers and system administrators

______________________________________________________________________

## Quick Reference

**What This Feature Does**:

- ✅ Enables macOS Application Firewall with stealth mode
- ✅ Disables guest account on login screen
- ✅ Sets per-host NetBIOS hostname for SMB/CIFS
- ✅ Configures NVRAM for verbose boot and muted startup sound

**Requirements**:

- macOS with nix-darwin
- Sudo privileges for system-level configuration
- Reboot required for NVRAM changes

______________________________________________________________________

## Installation

### 1. Build Configuration

```bash
# From repository root
darwin-rebuild build

# Check for errors
nix flake check
```

### 2. Dry-Run (Recommended First)

```bash
# See what would change without applying
darwin-rebuild switch --dry-run
```

### 3. Apply Configuration

```bash
# Apply system configuration
darwin-rebuild switch
```

**Expected Output**:

```
──────────────────────────────────────
Configuring macOS Application Firewall
──────────────────────────────────────
✓ Firewall already enabled
→ Enabling stealth mode...
✓ Stealth mode enabled successfully
✓ Logging already disabled
──────────────────────────────────────

──────────────────────────────────────
Configuring Security Settings
──────────────────────────────────────
Setting GuestEnabled to false...
✓ GuestEnabled set successfully
NetBIOSName already set to Work-MacBook
──────────────────────────────────────

──────────────────────────────────────
Configuring NVRAM Variables
──────────────────────────────────────
Setting NVRAM boot-args to -v...
✓ NVRAM boot-args set successfully
Setting NVRAM SystemAudioVolume to %00...
✓ NVRAM SystemAudioVolume set successfully
──────────────────────────────────────

═══════════════════════════════════════════
 ⚠️  NVRAM CONFIGURATION COMPLETE
 2 variable(s) updated

 REBOOT REQUIRED for changes to take effect
═══════════════════════════════════════════
```

______________________________________________________________________

## Verification

### Firewall

**Check firewall status**:

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
# Expected: Firewall is enabled. (State = 1)

/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
# Expected: Stealth mode enabled

/usr/libexec/ApplicationFirewall/socketfilterfw --getloggingmode
# Expected: Logging mode is disabled
```

**Test stealth mode from another computer**:

```bash
# From another machine on your network
ping <your-mac-ip>
# Expected: Request timeout (no response)

# Port scan test
nmap <your-mac-ip>
# Expected: Host appears filtered or down
```

**Alternative test (if no second machine)**:

```bash
# On the Mac, check if ICMP is being filtered
sudo tcpdump -i en0 icmp
# From another terminal, ping the Mac's IP
# You should see ICMP echo requests arrive but no replies sent
```

______________________________________________________________________

### Security Settings

**Guest account**:

```bash
# Check plist value
sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled
# Expected: 0

# Visual check
# 1. Lock screen or log out
# 2. Login screen should NOT show "Guest" option
```

**NetBIOS hostname**:

```bash
# Check configured value
sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName
# Expected: Your configured hostname (e.g., "Work-MacBook")

# Network test from another machine (optional)
nmblookup -A <mac-ip>
# Should show your NetBIOS name in output
```

______________________________________________________________________

### NVRAM Variables

**Before reboot** (check variables were written):

```bash
# Check boot-args
nvram boot-args
# Expected: boot-args	-v

# Check startup sound
nvram SystemAudioVolume
# Expected: SystemAudioVolume	%00

# View all NVRAM variables (optional)
nvram -p | grep -E '(boot-args|SystemAudioVolume)'
```

**After reboot** (verify effects):

1. **Verbose boot**: During boot, you should see log messages scrolling instead of just the Apple logo
1. **Silent startup**: Mac should boot silently (no startup sound)
1. **NVRAM persistence**:
   ```bash
   nvram boot-args
   nvram SystemAudioVolume
   # Values should still be set after reboot
   ```

______________________________________________________________________

## Per-Host Configuration

### Setting Custom Hostname

**In your host configuration** (`hosts/work-macbook/default.nix`):

```nix
{
  # Override NetBIOS hostname for this host
  system.defaults.smb.netbiosName = "Work-MacBook";
}
```

**Other examples**:

```nix
# Home Mac Mini
system.defaults.smb.netbiosName = "Home-MacMini";

# Development VM
system.defaults.smb.netbiosName = "Darwin-Dev";
```

**Validation rules**:

- Maximum 15 characters
- Alphanumeric and hyphens only (`[A-Za-z0-9-]`)
- No spaces or special characters

**Test configuration**:

```bash
# Build to check for errors
darwin-rebuild build

# If successful, apply
darwin-rebuild switch
```

______________________________________________________________________

## Testing Idempotency

**Run activation multiple times**:

```bash
# First run - should apply changes
darwin-rebuild switch

# Second run - should report "already set"
darwin-rebuild switch
```

**Expected on second run**:

```
──────────────────────────────────────
Configuring macOS Application Firewall
──────────────────────────────────────
✓ Firewall already enabled
✓ Stealth mode already enabled
✓ Logging already disabled
──────────────────────────────────────

──────────────────────────────────────
Configuring Security Settings
──────────────────────────────────────
GuestEnabled already set (current: 0)
NetBIOSName already set to Work-MacBook
──────────────────────────────────────

──────────────────────────────────────
Configuring NVRAM Variables
──────────────────────────────────────
NVRAM boot-args already set to -v
NVRAM SystemAudioVolume already set to %00
──────────────────────────────────────
```

______________________________________________________________________

## Security Testing

### Firewall Security Verification

**Test 1: Port Scan from External Machine**

```bash
# On another computer on the same network
nmap -p 1-65535 <mac-ip>
```

**Expected Results** (with stealth mode ON):

- Host appears as if it doesn't exist
- Ports show as "filtered" rather than "closed"
- Scan takes longer than usual (timeout waiting for responses)

**Expected Results** (without stealth mode):

- Ports show as "closed"
- Quick scan completion
- Host responds to probes

**Test 2: ICMP Ping Test**

```bash
# From another machine
ping <mac-ip>
```

**With stealth mode**:

```
Request timeout for icmp_seq 0
Request timeout for icmp_seq 1
...
100% packet loss
```

**Without stealth mode**:

```
64 bytes from <ip>: icmp_seq=0 ttl=64 time=2.123 ms
64 bytes from <ip>: icmp_seq=1 ttl=64 time=1.456 ms
```

**Test 3: Service Access (Should Still Work)**

Stealth mode doesn't block authorized applications:

```bash
# SSH should still work (if enabled)
ssh user@<mac-ip>

# File sharing should still work (if enabled)
smbclient -L //<mac-ip>

# Web services should still work (if running)
curl http://<mac-ip>:port
```

______________________________________________________________________

## Troubleshooting

### Firewall Issues

**Problem**: Firewall settings not applying

**Diagnosis**:

```bash
# Check if socketfilterfw exists
ls -la /usr/libexec/ApplicationFirewall/socketfilterfw

# Try manual command
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

**Solution**:

- Ensure running `darwin-rebuild` with sudo
- Check macOS version (Sequoia 15+ required for full support)
- If using older macOS, file an issue

______________________________________________________________________

**Problem**: Stealth mode not working (ping still responds)

**Diagnosis**:

```bash
# Check current stealth mode setting
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode

# Check firewall is actually enabled
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

**Solution**:

1. Manually enable stealth mode:
   ```bash
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
   sudo pkill -HUP socketfilterfw
   ```
1. Reboot Mac
1. Test again from external machine

______________________________________________________________________

### Security Settings Issues

**Problem**: Guest account still visible on login screen

**Diagnosis**:

```bash
# Check plist value
sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled

# Check if value is really 0
sudo defaults read /Library/Preferences/com.apple.loginwindow | grep GuestEnabled
```

**Solution**:

1. Manually set via System Settings:
   - System Settings → Users & Groups → Guest User → Disable
1. Or manually via command:
   ```bash
   sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
   ```
1. Log out and check login screen

______________________________________________________________________

**Problem**: NetBIOS hostname not taking effect

**Diagnosis**:

```bash
# Check if value was written
sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName

# Check file permissions
ls -la /Library/Preferences/SystemConfiguration/com.apple.smb.server.plist
```

**Solution**:

1. Manually set hostname:
   ```bash
   sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "Your-Hostname"
   ```
1. Verify with `nmblookup` from another machine
1. May need to restart SMB service or reboot

______________________________________________________________________

### NVRAM Issues

**Problem**: boot-args write fails on Apple Silicon

**Error Message**:

```
✗ Failed to set boot-args
Error setting variable - 'boot-args': (iokit/common) not permitted.
```

**Diagnosis**:
This is **expected behavior** on Apple Silicon with default security settings.

**Solution Options**:

**Option 1: Accept limitation (Recommended)**

- Verbose boot is diagnostic only, not required for system operation
- Configuration will skip on Apple Silicon automatically
- No action needed

**Option 2: Reduce security (Not recommended)**

1. Restart Mac
1. Hold power button until "Loading startup options"
1. Select disk, hold Command-R for Recovery Mode
1. Utilities → Startup Security Utility
1. Select disk → Security Policy → Reduced Security
1. Check "Allow NVRAM modifications"
1. **Warning**: Disables Apple Pay and iOS app compatibility

**Verification**:

```bash
# Check if nvram is writable
sudo nvram test-var="test"
sudo nvram -d test-var

# If succeeds, boot-args should work
sudo nvram boot-args="-v"
```

______________________________________________________________________

**Problem**: SystemAudioVolume doesn't mute startup sound

**Diagnosis**:

```bash
# Check if value was written
nvram SystemAudioVolume
# Expected: %00

# Check after reboot
nvram SystemAudioVolume
# Should still show %00
```

**Possible Causes**:

- Some Apple Silicon models don't respect this setting
- NVRAM may have been reset (Cmd+Option+P+R on Intel)
- Firmware update may have cleared NVRAM

**Solution**:

1. Verify value after reboot:
   ```bash
   nvram SystemAudioVolume
   ```
1. If value persists but sound still plays:
   - This is a known limitation on some Apple Silicon models
   - Use System Settings → Sound → "Play sound on startup" (if available)
1. If value was cleared:
   - Reapply with `darwin-rebuild switch`

______________________________________________________________________

**Problem**: NVRAM changes lost after reboot

**Diagnosis**:

```bash
# Before reboot
nvram -p | grep -E '(boot-args|SystemAudioVolume)'

# After reboot
nvram -p | grep -E '(boot-args|SystemAudioVolume)'
# If variables missing, NVRAM was reset
```

**Possible Causes**:

- Manual NVRAM reset (Cmd+Option+P+R on Intel)
- Firmware password preventing writes
- Apple Silicon auto-reset on certain boots
- macOS update cleared NVRAM

**Solution**:

1. Reapply configuration:
   ```bash
   darwin-rebuild switch
   ```
1. If issue persists, check for firmware password:
   ```bash
   sudo firmwarepasswd -check
   # If enabled, may need to disable temporarily
   ```

______________________________________________________________________

### General Debugging

**Check activation script logs**:

```bash
# Run with verbose output
darwin-rebuild switch --show-trace

# Check system logs
log show --predicate 'process == "darwin-rebuild"' --last 10m

# Check for errors
journalctl -u nix-darwin-activation
```

**Manual test helper functions**:

```bash
# Test defaults read/write
sudo defaults read /Library/Preferences/com.apple.alf globalstate
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

# Test NVRAM read/write
nvram boot-args
sudo nvram boot-args="-v"

# Test socketfilterfw
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

______________________________________________________________________

## Rollback Procedures

### Disable Firewall

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
```

### Re-enable Guest Account

```bash
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool true
```

### Reset NetBIOS Hostname

```bash
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "Workstation"
```

### Clear NVRAM Variables

```bash
# Remove boot-args
sudo nvram -d boot-args

# Remove SystemAudioVolume
sudo nvram -d SystemAudioVolume

# Reboot to apply
sudo reboot
```

**Full NVRAM Reset** (Intel only):

1. Restart Mac
1. Hold Cmd+Option+P+R immediately after startup sound
1. Hold for 20 seconds (Mac will restart)
1. Release keys

**Apple Silicon**: NVRAM resets automatically on certain boots, or:

1. Shut down Mac
1. Hold power button for 10 seconds
1. Release, wait a few seconds
1. Press power button to start normally

______________________________________________________________________

## Performance Expectations

### Activation Time

- **Firewall configuration**: < 5 seconds
- **Security settings**: < 2 seconds
- **NVRAM configuration**: < 3 seconds
- **Total**: < 10 seconds (well under 30-second requirement)

### Boot Time Impact

- **Verbose boot**: Minimal impact (< 2 seconds slower)
- **NVRAM overhead**: Negligible
- **Overall**: No noticeable slowdown

______________________________________________________________________

## Integration Testing

### Full System Test

1. **Clean state**: Reset all settings to defaults (optional)
1. **Apply configuration**: `darwin-rebuild switch`
1. **Verify without reboot**: Check firewall and security settings
1. **Reboot**: `sudo reboot`
1. **Verify after reboot**: Check NVRAM effects (verbose boot, silent startup)
1. **Test security**: Port scan from external machine
1. **Test idempotency**: Run `darwin-rebuild switch` again, verify "already set" messages
1. **Test per-host**: Change hostname, apply, verify
1. **Test rollback**: Manually revert settings, then reapply config to verify restoration

______________________________________________________________________

## Quick Commands Cheat Sheet

```bash
# Firewall status
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode

# Security status
sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled
sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName

# NVRAM status
nvram boot-args
nvram SystemAudioVolume

# Apply configuration
darwin-rebuild switch

# Build only (test)
darwin-rebuild build

# Dry-run (see changes)
darwin-rebuild switch --dry-run

# Test from external machine
ping <mac-ip>
nmap <mac-ip>
```

______________________________________________________________________

## Next Steps

After successful verification:

1. **Update documentation**: Mark items resolved in `specs/002-darwin-system-restructure/unresolved-migration.md`
1. **Create user docs**: Add to `docs/features/009-nvram-firewall-security.md`
1. **Test on all hosts**: Apply configuration to work-macbook, home-macmini, darwin-dev
1. **Monitor behavior**: Check for any unexpected issues over next few days
1. **Consider future enhancements**: Firewall application exceptions, additional NVRAM variables

______________________________________________________________________

## Support

**Issues**:

- Check troubleshooting section above
- Review `specs/009-nvram-firewall-security/plan.md` for design details
- Consult `docs/research/` for technical research

**Contributing**:

- Report issues with detailed system info (macOS version, hardware type)
- Include activation script output
- Provide verification command results
