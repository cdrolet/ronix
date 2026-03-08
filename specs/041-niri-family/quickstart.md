# Quickstart Guide: Niri Family Desktop Environment

**Feature**: 041-niri-family\
**Date**: 2026-01-29\
**Purpose**: Setup and testing instructions for developers and users

## Prerequisites

### System Requirements

- **Platform**: NixOS (x86_64-linux or aarch64-linux)
- **Nix Version**: 2.19+ with flakes enabled
- **Nixpkgs**: unstable channel (for Niri package)
- **Hardware**: Working graphics card with Wayland support

### Development Tools

```bash
# Check Nix version
nix --version  # Should be 2.19+

# Verify flakes enabled
nix flake --help  # Should show flake commands

# Check nixpkgs channel
nix-channel --list  # Should include nixpkgs-unstable
```

## Quick Setup (User Perspective)

### 1. Configure Host

Create or edit your host configuration to use the Niri family:

```nix
# system/nixos/host/my-workstation/default.nix
{
  name = "my-workstation";
  family = ["linux", "niri"];  # Add Niri family
  applications = ["*"];
  settings = ["default"];
}
```

**Important**: Always declare `linux` before `niri` for proper setting inheritance.

### 2. Configure User (Optional Customization)

Add Niri-specific preferences to your user config:

```nix
# user/myusername/default.nix
{
  user = {
    name = "myusername";
    applications = [
      "ghostty"    # Terminal
      "fuzzel"     # Launcher
      "waybar"     # Panel/bar
      "firefox"    # Browser
      # ... other apps
    ];
    
    # Optional Niri customization
    terminal = "${pkgs.ghostty}/bin/ghostty";
    launcher = "${pkgs.fuzzel}/bin/fuzzel";
    wallpaper = "~/Pictures/wallpaper.jpg";
    darkMode = true;  # Default for Niri
  };
}
```

### 3. Build and Install

```bash
# Build and apply configuration
just install myusername my-workstation

# Or manually:
sudo nixos-rebuild switch --flake ".#myusername-my-workstation"
home-manager switch --flake ".#myusername@my-workstation"
```

### 4. Reboot and Login

```bash
# Reboot system
sudo reboot

# At login screen (greetd/tuigreet):
# 1. Enter username
# 2. Enter password
# 3. Select "niri-session"
# 4. Press Enter
```

### 5. Verify Installation

```bash
# Check Niri is running
echo $XDG_CURRENT_DESKTOP  # Should output: niri

# Check wallpaper service
systemctl --user status niri-wallpaper

# Test keyboard shortcuts
# Mod+Return → Should open terminal
# Mod+Q → Should close window
# Mod+Left/Right → Should focus windows
```

## Development Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/nix-config.git
cd nix-config
```

### 2. Create Test Host

```bash
# Create a test host configuration
mkdir -p system/nixos/host/test-niri
cat > system/nixos/host/test-niri/default.nix <<'EOF'
{
  name = "test-niri";
  architecture = "x86_64";
  family = ["linux", "niri"];
  applications = ["*"];
  settings = ["default"];
}
EOF
```

### 3. Create Test User

```bash
# Create a minimal test user
just user-create
# Enter: test-user
# Email: test@example.com
# Template: common

# Or manually:
mkdir -p user/test-user
cat > user/test-user/default.nix <<'EOF'
{
  user = {
    name = "test-user";
    applications = ["ghostty" "fuzzel" "waybar" "firefox"];
    terminal = "${pkgs.ghostty}/bin/ghostty";
    launcher = "${pkgs.fuzzel}/bin/fuzzel";
  };
}
EOF
```

### 4. Build Test Configuration

```bash
# Syntax validation
nix flake check

# Build system configuration
nix build ".#nixosConfigurations.test-user-test-niri.config.system.build.toplevel"

# Build home configuration
nix build ".#homeConfigurations.\"test-user@test-niri\".activationPackage"
```

### 5. Test in Virtual Machine

```bash
# Build NixOS VM
nixos-rebuild build-vm --flake ".#test-user-test-niri"

# Run VM
./result/bin/run-*-vm

# Inside VM:
# - Login as test-user
# - Select niri-session
# - Test keyboard shortcuts
# - Verify wallpaper (if configured)
# - Test window management
```

## Module Development Workflow

### Creating a New System Module

```bash
# 1. Create module file
touch system/shared/family/niri/settings/system/my-module.nix

# 2. Write module
cat > system/shared/family/niri/settings/system/my-module.nix <<'EOF'
{
  config,
  lib,
  pkgs,
  ...
}: {
  # System-level configuration
  services.myservice = {
    enable = lib.mkDefault true;
  };
}
EOF

# 3. Test (no import needed - auto-discovery)
nix flake check
nix build ".#nixosConfigurations.test-user-test-niri.config.system.build.toplevel"
```

### Creating a New User Module

```bash
# 1. Create module file
touch system/shared/family/niri/settings/user/my-module.nix

# 2. Write module
cat > system/shared/family/niri/settings/user/my-module.nix <<'EOF'
{
  config,
  lib,
  pkgs,
  options,  # REQUIRED for context validation
  ...
}: {
  config = lib.optionalAttrs (options ? home) {
    # User-level configuration
    home.packages = [ pkgs.mypackage ];
  };
}
EOF

# 3. Test
nix flake check
nix build ".#homeConfigurations.\"test-user@test-niri\".activationPackage"
```

### Testing Module Changes

```bash
# 1. Check syntax
nix flake check

# 2. Build without applying
just build test-user test-niri

# 3. Show diff
just diff test-user test-niri

# 4. Apply if satisfied
just install test-user test-niri
```

## Common Tasks

### Add Niri-Specific Application

```bash
# 1. Create app module
mkdir -p system/shared/family/niri/app/utility
touch system/shared/family/niri/app/utility/myapp.nix

# 2. Write app configuration
cat > system/shared/family/niri/app/utility/myapp.nix <<'EOF'
{
  config,
  lib,
  pkgs,
  options,
  ...
}: {
  config = lib.optionalAttrs (options ? home) {
    home.packages = [ pkgs.myapp ];
    
    xdg.configFile."myapp/config".text = ''
      # App configuration
    '';
  };
}
EOF

# 3. Add to user applications
# Edit user/{username}/default.nix
# applications = ["myapp" /* ... */];

# 4. Test
just build username hostname
```

### Customize Keyboard Shortcuts

```bash
# Edit: system/shared/family/niri/settings/user/keyboard.nix
# Modify keybindings in the KDL config text

# Test changes
just build username hostname
just diff username hostname
just install username hostname
```

### Change Wallpaper

```bash
# Edit user configuration
# user.wallpaper = "~/Pictures/new-wallpaper.jpg";

# Apply changes
just install username hostname

# Or just rebuild home-manager:
home-manager switch --flake ".#username@hostname"
```

## Debugging

### Check Family Discovery

```bash
# Verify Niri family exists
nix eval ".#nixosConfigurations.test-user-test-niri.config.system.build.toplevel" --json | jq

# Check family validation
nix eval '.#nixosConfigurations.test-user-test-niri.config' --apply 'c: c.system.build.family or "not found"'
```

### Inspect Generated Config

```bash
# View Niri config file
nix eval ".#homeConfigurations.\"test-user@test-niri\".config.xdg.configFile.\"niri/config.kdl\".text" --raw

# View wallpaper service
nix eval ".#homeConfigurations.\"test-user@test-niri\".config.systemd.user.services.niri-wallpaper" --json | jq
```

### Check Context Validation

```bash
# Test user module in system context (should skip)
nix eval ".#nixosConfigurations.test-user-test-niri.config.home-manager" --json

# Test user module in home-manager context (should work)
nix eval ".#homeConfigurations.\"test-user@test-niri\".config.home.packages" --json
```

### Test Keyboard Module

```bash
# Extract terminal command from Niri config
nix eval ".#homeConfigurations.\"test-user@test-niri\".config.xdg.configFile.\"niri/config.kdl\".text" --raw | grep "Mod+Return"

# Should show: Mod+Return { spawn "${terminal}"; }
# Where ${terminal} is from user.terminal or default
```

### Verify Wallpaper Integration

```bash
# Check if wallpaper service created
nix eval ".#homeConfigurations.\"test-user@test-niri\".config.systemd.user.services" --json | jq 'keys | map(select(. | startswith("niri-wallpaper")))'

# Expected: ["niri-wallpaper"] if user.wallpaper set, [] if not
```

## Testing Checklist

### Pre-Merge Validation

- [ ] `nix flake check` passes without errors
- [ ] All modules \<200 lines (constitutional requirement)
- [ ] System build succeeds: `nix build ".#nixosConfigurations.test-user-test-niri.config.system.build.toplevel"`
- [ ] Home build succeeds: `nix build ".#homeConfigurations.\"test-user@test-niri\".activationPackage"`
- [ ] Context validation works (user modules skip in system context)
- [ ] All settings use `lib.mkDefault` (user-overridable)
- [ ] No manual imports (auto-discovery working)

### VM Testing

- [ ] VM boots successfully
- [ ] greetd/tuigreet login screen appears
- [ ] Niri session option available
- [ ] Niri compositor starts after login
- [ ] Wallpaper displays (if configured)
- [ ] Keyboard shortcuts work (Mod+Return, Mod+Q, Mod+Left/Right)
- [ ] Terminal opens with Mod+Return
- [ ] Windows close with Mod+Q
- [ ] Window focus changes with Mod+Left/Right
- [ ] GTK apps use dark theme (if darkMode = true)

### Integration Testing

- [ ] Composes with linux family (keyboard layout works)
- [ ] Font configuration works (Feature 030)
- [ ] Wallpaper configuration works (Feature 033)
- [ ] User config fields read correctly (terminal, launcher, wallpaper, darkMode)
- [ ] Discovery system finds all modules
- [ ] Family validation passes

## Troubleshooting

### Build Errors

**Error**: `error: attribute 'niri' missing`

```bash
# Solution: Ensure nixpkgs unstable channel
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
nix-channel --update
```

**Error**: `error: Family 'niri' not found`

```bash
# Solution: Verify family directory exists
ls -la system/shared/family/niri
# Should show: app/, settings/, lib/ subdirectories
```

**Error**: `error: infinite recursion encountered`

```bash
# Solution: Check user modules use 'options' parameter, not 'config' in condition
# WRONG: config = lib.optionalAttrs (config._configContext == "home") { ... };
# CORRECT: config = lib.optionalAttrs (options ? home) { ... };
```

### Runtime Issues

**Issue**: Niri doesn't start after login

```bash
# Check logs
journalctl -u greetd -f

# Check Niri status
systemctl status --user niri
```

**Issue**: Wallpaper not displaying

```bash
# Check wallpaper service
systemctl --user status niri-wallpaper

# Check logs
journalctl --user -u niri-wallpaper -f

# Verify wallpaper file exists
ls -l ~/Pictures/wallpaper.jpg
```

**Issue**: Keyboard shortcuts not working

```bash
# Check Niri config file
cat ~/.config/niri/config.kdl

# Test Niri config syntax
niri validate ~/.config/niri/config.kdl
```

**Issue**: GTK theme not dark

```bash
# Check environment variable
echo $GTK_THEME  # Should be: Adwaita:dark

# Check dconf setting
gsettings get org.gnome.desktop.interface color-scheme
# Should be: 'prefer-dark'
```

## Performance Benchmarks

### Expected Performance

| Metric | Target | Test Command |
|--------|--------|--------------|
| Session start time | \<5s | Time from login to usable desktop |
| Keyboard response | \<16ms | Mod+Return to terminal visible |
| Window focus | Instant | Mod+Left/Right focus change |
| Wallpaper load | \<1s | swaybg startup time |
| Build time | \<2min | Full system rebuild |
| Closure size | \<2GB | Niri + dependencies |

### Benchmark Commands

```bash
# Measure session start time
systemd-analyze --user

# Measure build time
time nix build ".#nixosConfigurations.test-user-test-niri.config.system.build.toplevel"

# Measure closure size
nix path-info -rsSh ".#nixosConfigurations.test-user-test-niri.config.system.build.toplevel"
```

## Next Steps

### After Successful Testing

1. **Merge to main**: Create pull request with test results
1. **Document**: Create `docs/features/041-niri-family.md` for users
1. **Announce**: Notify users of new Niri family availability
1. **Monitor**: Watch for issues in production use

### Future Enhancements

1. **niri-flake integration**: Migrate to declarative `programs.niri.settings`
1. **Per-monitor wallpapers**: Implement `config.user.wallpapers` array support
1. **Additional panels**: Add Ironbar, Eww as alternative app modules
1. **Notification daemon**: Add mako or dunst app module
1. **Session management**: Add swaylock, swayidle app modules

## Resources

- [Niri Documentation](https://github.com/YaLTeR/niri/wiki)
- [NixOS Wiki: Niri](https://wiki.nixos.org/wiki/Niri)
- [Feature Specification](./spec.md)
- [Implementation Plan](./plan.md)
- [Research Findings](./research.md)
- [Data Model](./data-model.md)
- [System Contracts](./contracts/system-settings.md)
- [User Contracts](./contracts/user-settings.md)
- [Integration Contracts](./contracts/integration.md)
