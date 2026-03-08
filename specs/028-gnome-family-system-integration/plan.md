# Implementation Plan: GNOME Family System Integration

**Branch**: `028-gnome-family-system-integration` | **Date**: 2025-12-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/028-gnome-family-system-integration/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Reorganize GNOME family configuration to properly separate system-level desktop environment installation (via NixOS) from user-level settings (via home-manager). When a NixOS host declares `family = ["gnome"]`, the full GNOME desktop environment will be installed system-wide via NixOS configuration modules in `settings/desktop/`, while optional user tools remain in `app/utility/`. Includes Wayland configuration and global shortcuts (Ctrl+Alt+Space for launcher).

## Technical Context

**Language/Version**: Nix 2.19+ (flakes enabled)\
**Primary Dependencies**: NixOS modules, home-manager, dconf (for GNOME settings)\
**Storage**: Declarative Nix configuration files (.nix expressions)\
**Testing**: `nix flake check`, NixOS evaluation tests\
**Target Platform**: NixOS systems with GNOME desktop environment\
**Project Type**: Configuration management (Nix modules)\
**Performance Goals**: N/A (declarative configuration)\
**Constraints**:

- System-level config requires NixOS (not just home-manager)
- Family settings auto-discovered by default.nix
- Modules must be \<200 lines per constitutional requirement\
  **Scale/Scope**:
- 3-5 desktop component modules (gnome-shell, nautilus, etc.)
- 2-3 new settings modules (wayland, shortcuts)
- Auto-discovery pattern for all modules

**Key Technical Questions**:

- NEEDS CLARIFICATION: Which specific GNOME packages to include in desktop/? (gnome-shell, nautilus, gnome-control-center, etc.)
- NEEDS CLARIFICATION: How to properly configure system-level vs user-level with family integration?
- NEEDS CLARIFICATION: Correct dconf schema path for Ctrl+Alt+Space launcher binding?
- NEEDS CLARIFICATION: GDM Wayland configuration options in NixOS?

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles Compliance

✅ **I. Declarative Configuration First**

- All GNOME desktop configuration will be declarative Nix modules
- System-level: NixOS options (`services.xserver.desktopManager.gnome.enable`)
- User-level: dconf settings via home-manager
- No imperative configuration steps required

✅ **II. Modularity and Reusability**

- Desktop modules in `settings/desktop/` (system-level, NixOS)
- Optional tools in `app/utility/` (user-level, home-manager)
- Each module has single purpose: gnome-shell.nix, nautilus.nix, etc.
- Auto-discovery via default.nix pattern (no manual imports)
- Modules will be \<200 lines (constitutional requirement)

✅ **III. Documentation-Driven Development**

- Spec already created with user stories, architecture, implementation plan
- Each module will include header documentation with purpose, options, examples
- Dependencies declared explicitly in module headers
- User documentation planned in `docs/features/028-gnome-family-system-integration.md`

✅ **IV. Purity and Reproducibility**

- All GNOME packages from nixpkgs with pinned versions (flake.lock)
- No runtime network access during build
- Deterministic dconf settings (declarative JSON)

✅ **V. Testing and Validation**

- Will validate with `nix flake check` for syntax
- NixOS evaluation tests for system modules
- Test on NixOS VM before deployment to physical machine

✅ **VI. Cross-Platform Compatibility**

- Platform-agnostic architecture maintained
- GNOME modules specific to NixOS (in `system/nixos/`)
- Linux family modules in `system/shared/family/linux/` (cross-distro)
- GNOME family modules in `system/shared/family/gnome/` (cross-platform GNOME)
- No darwin-specific code in GNOME modules

### Architectural Standards Compliance

✅ **Flakes as Entry Point**

- No changes to flake.nix structure
- All dependencies from pinned nixpkgs in flake.lock

✅ **Home Manager Integration**

- User-level settings (dconf, GTK themes) via home-manager
- System-level desktop via NixOS modules
- Clean separation maintained

✅ **Directory Structure Standard**

- Following canonical structure:
  - `system/shared/family/gnome/settings/desktop/` - System components
  - `system/shared/family/gnome/settings/wayland.nix` - Wayland config
  - `system/shared/family/gnome/settings/shortcuts.nix` - Global shortcuts
  - `system/shared/family/gnome/app/utility/` - Optional user tools

✅ **Development Standards**

- Specification-driven process (this spec)
- No backward compatibility required (breaking changes permitted)
- Will document blockers if encountered

### Potential Violations

None identified. This feature aligns with all constitutional requirements.

**GATE STATUS**: ✅ **PASS** - Proceed to Phase 0 research

## Project Structure

### Documentation (this feature)

```text
specs/028-gnome-family-system-integration/
├── spec.md              # ✅ Feature specification (completed)
├── plan.md              # 🔄 This file (in progress)
├── research.md          # ⏳ Phase 0 output (next)
├── data-model.md        # ⏳ Phase 1 output
├── quickstart.md        # ⏳ Phase 1 output
├── contracts/           # ⏳ Phase 1 output
└── tasks.md             # ⏳ Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

This feature reorganizes GNOME family modules in the existing nix-config repository:

```text
system/shared/family/gnome/
├── settings/
│   ├── default.nix           # ✅ Auto-discovery (exists, updated)
│   ├── ui.nix                # ✅ Dark mode, fonts (exists)
│   ├── keyboard.nix          # ✅ Window shortcuts (exists)
│   ├── power.nix             # ✅ Screen timeout (exists)
│   ├── dock.nix              # ✅ Dock favorites (exists)
│   ├── keyring.nix           # ✅ GNOME keyring (exists)
│   │
│   ├── desktop/              # 🆕 System-level desktop components (NixOS)
│   │   ├── default.nix       # 🆕 Auto-discovery for desktop modules
│   │   ├── gnome-shell.nix   # 🆕 Core GNOME Shell
│   │   ├── nautilus.nix      # 🆕 File manager (move from app/utility/)
│   │   ├── control-center.nix# 🆕 Settings app
│   │   └── [more desktop components]
│   │
│   ├── wayland.nix           # 🆕 Wayland display server config
│   └── shortcuts.nix         # 🆕 Global shortcuts (Ctrl+Alt+Space → launcher)
│
└── app/
    ├── default.nix           # ✅ Auto-discovery (exists, updated)
    └── utility/              # ✅ Optional user tools
        ├── gnome-tweaks.nix  # ✅ Customization tool (exists)
        └── dconf-editor.nix  # ✅ Low-level config (exists)

system/nixos/lib/
└── nixos.nix                 # 🔄 May need updates for family system integration

docs/features/
└── 028-gnome-family-system-integration.md  # 🆕 User documentation
```

**Structure Decision**:

This is a **Nix configuration reorganization** project, not application development. The structure follows the constitutional directory layout for the User/System Split pattern with hierarchical organization.

**Key Changes**:

1. **New `settings/desktop/` directory** - System-level GNOME components (NixOS modules)
1. **New settings modules** - `wayland.nix`, `shortcuts.nix` for system configuration
1. **Move `nautilus.nix`** - From `app/utility/` to `settings/desktop/` (system component)
1. **Keep `app/utility/`** - For optional user-level tools (gnome-tweaks, dconf-editor)

This maintains the constitutional requirement of \<200 lines per module while properly separating system-level desktop installation from user-level optional tools.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations identified.** All constitutional requirements are met without exceptions.
