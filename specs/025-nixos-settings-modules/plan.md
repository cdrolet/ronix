# Implementation Plan: NixOS Settings Modules

**Branch**: `025-nixos-settings-modules` | **Date**: 2025-12-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/025-nixos-settings-modules/spec.md`

## Summary

Create NixOS system settings modules inspired by the Darwin settings structure. Core NixOS settings go in `system/nixos/settings/`, while GNOME-specific settings go in `system/shared/family/gnome/settings/`. Both use the auto-discovery pattern from Darwin.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled
**Primary Dependencies**: NixOS modules, Home Manager, dconf (for GNOME)
**Storage**: N/A (declarative Nix configuration files)
**Testing**: `nix flake check`, manual activation testing
**Target Platform**: NixOS with optional GNOME desktop
**Project Type**: Nix configuration modules
**Performance Goals**: Configuration applies at system activation
**Constraints**: Modules must be \<200 lines (constitutional requirement)
**Scale/Scope**: 6 NixOS settings modules, 3 GNOME settings modules

## Constitution Check

*GATE: Must pass before Phase 0 research.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration First | PASS | All config via Nix expressions |
| II. Modularity and Reusability | PASS | Self-contained settings modules |
| III. Documentation-Driven | PASS | Spec complete with scenarios |
| IV. Purity and Reproducibility | PASS | Same config → same settings |
| V. Testing and Validation | PASS | `nix flake check` validation |
| VI. Cross-Platform Compatibility | PASS | GNOME settings in family/, NixOS in nixos/ |
| Module Size \<200 lines | PASS | Each module focused on one topic |
| App-Centric Organization | PASS | Settings organized by topic |

**Gate Status**: PASSED

## Project Structure

### Documentation (this feature)

```text
specs/025-nixos-settings-modules/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
system/
├── nixos/
│   └── settings/
│       ├── default.nix      # NEW: Auto-discovery aggregator
│       ├── security.nix     # NEW: Firewall, sudo, polkit
│       ├── locale.nix       # NEW: Timezone, locale from user config
│       ├── keyboard.nix     # NEW: Repeat rate, layout
│       ├── network.nix      # NEW: NetworkManager, DNS
│       └── system.nix       # NEW: Boot, Nix settings, GC
│
└── shared/
    └── family/
        ├── linux/
        │   └── settings/
        │       ├── default.nix  # NEW: Auto-discovery
        │       └── keyboard.nix # NEW: Mac-style keyboard remapping
        │
        └── gnome/
            └── settings/
                ├── default.nix  # MODIFIED: Add auto-discovery
                ├── dock.nix     # EXISTING: Dock configuration
                ├── ui.nix       # NEW: Dark mode, fonts, animations
                ├── keyboard.nix # NEW: Shortcuts, input sources
                └── power.nix    # NEW: Screen timeout, suspend
```

**Structure Decision**: Follows the established platform hierarchy. NixOS-specific settings in `system/nixos/settings/`, cross-platform GNOME settings in `system/shared/family/gnome/settings/`.

## Complexity Tracking

No constitution violations. Implementation follows established patterns.

## Design Decisions

### D1: Auto-Discovery Pattern

**Decision**: Use the same discovery pattern as Darwin settings.
**Rationale**: Consistency, maintainability, and zero-config module addition.

```nix
# system/nixos/settings/default.nix
imports = map (file: ./${file}) (discovery.discoverModules ./.);
```

### D2: Keyboard Repeat Values

**Decision**: Use equivalent values to Darwin for consistency.
**Rationale**: Users expect similar behavior across platforms.

| Darwin | NixOS Equivalent |
|--------|-----------------|
| KeyRepeat = 2 | services.xserver.autoRepeatDelay = 200 |
| InitialKeyRepeat = 10 | services.xserver.autoRepeatInterval = 25 |

### D3: GNOME Settings via dconf

**Decision**: Use Home Manager's dconf.settings for GNOME configuration.
**Rationale**: Standard approach, declarative, persists properly.

### D4: User Config Access

**Decision**: Read from `user.*` fields via config path (same as Darwin).
**Rationale**: Cross-platform consistency for locale settings.

## Implementation Phases

### Phase 1: NixOS Core Settings

1. Create `system/nixos/settings/default.nix` with auto-discovery
1. Create `security.nix` - firewall, sudo, polkit
1. Create `locale.nix` - timezone, locale from user config
1. Create `keyboard.nix` - repeat rate matching Darwin
1. Create `network.nix` - NetworkManager, DNS settings
1. Create `system.nix` - boot, Nix flakes, garbage collection

### Phase 2: Linux Family Settings

1. Create `system/shared/family/linux/settings/default.nix` with auto-discovery
1. Create `keyboard.nix` - Mac-style keyboard remapping (modifier keys)

### Phase 3: GNOME Family Settings

1. Update `system/shared/family/gnome/settings/default.nix` with auto-discovery
1. Create `ui.nix` - dark mode, fonts, animations
1. Create `keyboard.nix` - shortcuts, input sources
1. Create `power.nix` - screen timeout, suspend

### Phase 4: Testing

1. Verify `nix flake check` passes
1. Test auto-discovery adds new modules
1. Verify Darwin still works unchanged
