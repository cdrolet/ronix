# Feature 028: GNOME Family System Integration

## Overview

Reorganize GNOME family configuration to properly separate system-level desktop environment installation from user-level settings. GNOME desktop packages should be installed at the system level when a host uses `family = ["gnome"]`, not at the user level via home-manager.

**Cross-Platform Family Architecture**: The `gnome` and `linux` families in `system/shared/family/` are designed to work with **any Linux-based distribution** (NixOS, Kali, Ubuntu, etc.), not just NixOS. When a host from any Linux system declares `family = ["gnome"]`, it should receive the full GNOME desktop environment and settings.

## Problem Statement

Currently:

- GNOME apps (nautilus, gnome-tweaks, dconf-editor) are installed per-user via home-manager
- No system-level GNOME desktop environment installation
- Nautilus is redundantly installed (comes with GNOME desktop by default)
- Missing Wayland configuration
- Missing global shortcuts and system tray integration
- GNOME family doesn't automatically include Linux family (implicit dependency not enforced)

## Goals

1. **Cross-Platform Family Support**: Ensure gnome/linux families work on any Linux distribution
1. **Family App Discovery**: Remove default.nix from family/\*/app/ directories for hierarchical discovery
1. **Independent Family Settings**: Each family settings/ auto-discovered independently (no cross-imports)
1. **System-Level Installation**: Install GNOME desktop environment at system level when host uses `family = ["gnome"]`
1. **Remove Redundancy**: Remove nautilus.nix (included with GNOME desktop)
1. **User-Level Apps**: Keep only optional tools (gnome-tweaks, dconf-editor) as user apps
1. **Wayland Support**: Configure Wayland as display server for GNOME
1. **Global Shortcuts**: Set up Ctrl+Alt+Space global shortcut
1. **System Tray**: Configure system tray integration properly

## Architecture

### Cross-Platform Family System

**Key Principle**: Families in `system/shared/family/` are **platform-agnostic** and work on any compatible system:

- `system/shared/family/linux/` - Works on NixOS, Kali, Ubuntu, Arch, etc.
- `system/shared/family/gnome/` - Works on any Linux distro with GNOME support
- Families are **optional** - only installed if host declares them in `family = [...]`
- When installed, family apps/settings become **part of the system** (not user-level overrides)

### Family Integration Behavior

When **any Linux-based host** declares `family = ["gnome"]`:

1. **Settings Auto-Discovery Only**:

   - `gnome/settings/` modules auto-discovered and imported at system level
   - **NO auto-import of other families** - Linux settings NOT automatically loaded
   - To get Linux settings, host must explicitly declare `family = ["linux", "gnome"]`
   - Family settings directory uses standard auto-discovery (like system settings)

1. **Apps via User Selection**:

   - `family/{name}/app/` has **NO default.nix** - behaves like `system/{platform}/app/`
   - Family apps discovered hierarchically (system → families → shared)
   - Apps loaded **ONLY when user declares them** in `user.applications`
   - Wildcard (`applications = ["*"]`) includes family apps if family in host
   - Family apps become **eligible for user selection**, not auto-installed

1. **System-Level Configuration**:

   - Family settings become system-level configuration when host uses family
   - Family apps available in discovery hierarchy for user selection
   - Platform-specific implementation:
     - NixOS: Uses `services.xserver.desktopManager.gnome.*` options
     - Other Linux: Platform lib translates to appropriate mechanism

### File Organization

```
system/shared/family/
├── linux/                       # Base Linux family (cross-distro)
│   ├── settings/
│   │   ├── default.nix          # Auto-discovery for Linux settings
│   │   └── keyboard.nix         # Mac-style modifier remapping (Super↔Ctrl)
│   └── app/
│       └── cli/
│           └── caligula.nix     # Docker/Podman TUI (Linux-only)
│           # NO default.nix - apps discovered hierarchically
│
└── gnome/                       # GNOME desktop family
    ├── settings/
    │   ├── default.nix          # Auto-discovery (DOES NOT import linux/settings)
    │   ├── desktop/              # NEW: GNOME desktop environment (system-level)
    │   │   ├── default.nix       # NEW: Auto-discovery for desktop modules
    │   │   ├── gnome-core.nix    # NEW: Core GNOME Shell & desktop
    │   │   ├── gnome-optional.nix# NEW: Optional components control
    │   │   └── gnome-exclude.nix # NEW: Exclude unwanted packages
    │   ├── wayland.nix           # NEW: Wayland configuration (system-level)
    │   ├── shortcuts.nix         # NEW: Global shortcuts (Ctrl+Alt+Space → launcher)
    │   ├── keyboard.nix          # Existing: Window shortcuts
    │   ├── ui.nix                # Existing: GTK theme, dark mode
    │   ├── power.nix             # Existing: Power management
    │   ├── dock.nix              # Existing: Dock configuration
    │   └── keyring.nix           # Existing: GNOME keyring
    └── app/
        └── utility/
            ├── gnome-tweaks.nix  # Optional: GNOME customization (user-level)
            └── dconf-editor.nix  # Optional: Low-level config editor (user-level)
            # NO default.nix - apps discovered hierarchically

Notes:
- settings/ uses auto-discovery (each family independent)
- app/ has NO default.nix - discovered via hierarchical search when user selects apps
- Apps available when: family in host.family AND app in user.applications
- Wildcard includes family apps: applications = ["*"] gets family apps if family in host
- To get both Linux + GNOME settings: host must declare family = ["linux", "gnome"]
- Works on any Linux distro: NixOS, Kali, Ubuntu, Arch, etc.
```

## Requirements

### US0: Family App Discovery Without default.nix

**As a** system architect\
**I want** family app directories to have NO default.nix and use hierarchical discovery\
**So that** family apps behave like system apps (user-selected, not auto-installed)

**Acceptance Criteria:**

- [ ] Delete `gnome/app/default.nix` (if exists)
- [ ] Delete `linux/app/default.nix` (if exists)
- [ ] Family apps discovered hierarchically: system → families → shared
- [ ] Apps loaded ONLY when user declares them in `user.applications`
- [ ] Wildcard `applications = ["*"]` includes family apps if family in host
- [ ] Family apps become eligible for selection, not automatically installed
- [ ] NO cross-family imports in app/ directories

### US1: GNOME Desktop in settings/desktop/

**As a** Linux system administrator\
**I want** GNOME desktop environment configured in gnome/settings/desktop/\
**So that** full GNOME desktop is installed system-wide on any Linux distro

**Acceptance Criteria:**

- [ ] Create `gnome/settings/desktop/` directory
- [ ] Delete `nautilus.nix` from `app/utility/` (redundant with GNOME core-apps)
- [ ] Create `gnome-core.nix`, `gnome-optional.nix`, `gnome-exclude.nix` modules
- [ ] Break down desktop environment into modular .nix files (\<200 lines each)
- [ ] Use system-level configuration (NixOS: `services.xserver.*`, other distros: TBD)
- [ ] Cross-platform: Works on NixOS, Kali, Ubuntu with appropriate platform lib

### US2: System-Level GNOME Configuration

**As a** system architect\
**I want** GNOME desktop to use system-level options (not user-level)\
**So that** the full desktop environment works properly with all services on any platform

**Acceptance Criteria:**

- [ ] NixOS: Use `services.xserver.desktopManager.gnome.enable = true`
- [ ] Other Linux distros: Platform-specific implementation (handled by platform lib)
- [ ] Configure GDM (GNOME Display Manager) at system level
- [ ] NOT installed via `home.packages` (home-manager)
- [ ] Auto-discovered by `gnome/settings/default.nix`
- [ ] Family modules remain platform-agnostic (no NixOS-specific code)

### US3: Wayland Configuration

**As a** GNOME user\
**I want** Wayland configured as the display server\
**So that** I have modern graphics stack and better performance

**Acceptance Criteria:**

- [ ] Create `gnome/settings/wayland.nix`
- [ ] Configure `services.xserver.displayManager.gdm.wayland = true`
- [ ] Set environment variables for Wayland session
- [ ] System-level configuration

### US4: Global Shortcuts

**As a** GNOME user\
**I want** Ctrl+Alt+Space configured as a global shortcut\
**So that** I can quickly launch the application launcher

**Acceptance Criteria:**

- [ ] Create `gnome/settings/shortcuts.nix`
- [ ] Configure Ctrl+Alt+Space to trigger launcher via dconf
- [ ] Bind to `org/gnome/desktop/wm/keybindings` or launcher keybinding
- [ ] User-level configuration (dconf settings)

### US5: System Tray Integration

**As a** GNOME user\
**I want** system tray properly configured\
**So that** applications can show status icons and notifications

**Acceptance Criteria:**

- [ ] GNOME Shell extensions configured by individual apps in `gnome/app/`
- [ ] Each app that needs extensions declares them in its own module
- [ ] No centralized systray.nix file
- [ ] Apps use `home.packages` or appropriate configuration for extensions

## Technical Considerations

### Cross-Platform Family Design

**Platform-Agnostic Principle**: Family modules in `system/shared/family/` should work on any compatible platform:

- Use generic configuration that platforms can interpret
- NixOS uses `services.xserver.*` options
- Other distros may use different mechanisms (handled by platform lib)
- Family modules should NOT contain platform-specific code (no `if NixOS then...`)

### System vs User Level

**System-Level** (family/gnome/settings/):

- GNOME desktop environment installation
- Wayland/GDM configuration
- Display manager settings
- System-wide services
- **Platform-specific implementation**: NixOS uses `services.*`, other distros TBD

**User-Level** (family/gnome/app/):

- dconf preferences (UI, keyboard shortcuts, dock)
- GTK theme settings
- Optional applications (gnome-tweaks, dconf-editor)
- User-specific customizations
- **Cross-platform**: home-manager works the same on all Linux distros

### Module Discovery

All new settings modules will be auto-discovered by `gnome/settings/default.nix`:

- Drop `.nix` files in `gnome/settings/`
- Auto-imported via discovery pattern
- No manual imports needed

## Testing Strategy

1. **Build Test**: `nix flake check` passes
1. **System Test**: Verify GNOME desktop packages available in NixOS config
1. **Wayland Test**: Verify Wayland session configuration
1. **Shortcuts Test**: Verify Ctrl+Alt+Space binding in dconf
1. **Tray Test**: Verify system tray extensions enabled

## Implementation Plan

### Phase 0: Remove Family App default.nix Files

1. Delete `gnome/app/default.nix` (if exists)
1. Delete `linux/app/default.nix` (if exists)
1. Verify family apps still discovered hierarchically
1. Test that wildcard `applications = ["*"]` includes family apps when family in host
1. Confirm apps NOT auto-installed (only when user selects them)

### Phase 1: Create Desktop Settings Directory

1. Create `gnome/settings/desktop/` directory with `default.nix` for auto-discovery
1. Delete `app/utility/nautilus.nix` (redundant with GNOME core-apps)
1. Create `gnome-core.nix`, `gnome-optional.nix`, `gnome-exclude.nix` modules
1. Keep modules platform-agnostic (no NixOS-specific code in family)
1. Test that desktop modules are discovered and imported

### Phase 2: Platform-Specific Integration (NixOS)

1. Update `system/nixos/lib/nixos.nix` to support family integration
1. Import `familyDefaults` at system modules level (like darwin does)
1. Ensure family settings use NixOS options (`services.xserver.*`)
1. Test on NixOS host with `family = ["gnome"]`
1. Verify GNOME desktop installs system-wide

### Phase 3: Wayland Configuration

1. Create `gnome/settings/wayland.nix` (platform-agnostic)
1. Configure GDM and Wayland session using generic options
1. NixOS: Uses `services.xserver.displayManager.gdm.wayland`
1. Other distros: Platform lib handles translation
1. Test Wayland session on NixOS

### Phase 4: Global Shortcuts

1. Create `gnome/settings/shortcuts.nix`
1. Configure Ctrl+Alt+Space → launcher via dconf
1. User-level home-manager configuration (cross-platform)
1. Test keyboard shortcut works

### Phase 5: Documentation & Testing

1. Update CLAUDE.md with cross-platform family architecture
1. Document GNOME family auto-imports Linux family
1. Document system vs user-level separation
1. Document platform-agnostic family design principle
1. Full integration test on NixOS
1. Commit and document changes

## Success Metrics

- [ ] Family app/ directories have NO default.nix (hierarchical discovery only)
- [ ] Family apps user-selected, not auto-installed
- [ ] Each family settings/ independent (no cross-family imports)
- [ ] GNOME desktop installed at system level via family integration
- [ ] Works on any Linux distribution (NixOS tested, others compatible)
- [ ] Family modules remain platform-agnostic (no platform-specific code)
- [ ] No redundant package installations (nautilus removed)
- [ ] Wayland properly configured
- [ ] Global shortcuts working (Ctrl+Alt+Space)
- [ ] System tray functional (per-app extensions)
- [ ] Clear separation between system and user configuration

## Resolved Questions

1. ✅ Ctrl+Alt+Space → Application launcher
1. ✅ GNOME Shell extensions → Configured per-app in `gnome/app/`, not centralized
1. ✅ GNOME desktop → System-level in `gnome/settings/desktop/` (modular approach)
1. ✅ `family = ["gnome"]` → Full GNOME desktop environment (system-level)
1. ✅ Cross-platform families → Work on any Linux distro (NixOS, Kali, Ubuntu, etc.)
1. ✅ Family app discovery → NO default.nix, hierarchical like system apps (user-selected)
1. ✅ Family settings → Independent per family (no cross-imports), auto-discovery only
1. ✅ Platform-agnostic design → Family modules use generic options, platform lib handles specifics

## References

- NixOS GNOME options: https://search.nixos.org/options?query=gnome
- GNOME Wayland: https://wiki.gnome.org/Initiatives/Wayland
- Feature 025: NixOS Settings Modules
