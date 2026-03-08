# Research: Keyboard Configuration Restructure

**Feature**: 044-keyboard-config-restructure
**Date**: 2026-02-07

## Decision 1: Schema Structure for keyboard namespace

**Decision**: Use a typed submodule `keyboard` with two fields: `layout` (list of strings, default null) and `macStyleMappings` (boolean, default true).

**Rationale**: Follows the existing pattern used by `fonts` in user-schema.nix — a typed submodule with explicit options. The `keyboard` field replaces the flat `keyboardLayout` at the same level as other user options. Using a submodule (vs freeform) gives proper type checking and documentation.

**Alternatives considered**:

- Freeform attrs: Rejected — keyboard settings need type validation (boolean for macStyleMappings)
- Deeply nested (`keyboard.modifiers.macStyle`): Rejected — over-engineering per spec assumption of flat namespace

## Decision 2: Default value for macStyleMappings

**Decision**: Default to `true`.

**Rationale**: All current Linux users have the Super/Ctrl swap hardcoded. Defaulting to `true` preserves existing behavior — no breaking change for current configurations. Users who don't want the swap can explicitly set `false`.

**Alternatives considered**:

- Default `false` (standard Linux behavior): Rejected — would break all current users' muscle memory
- Default `null` (per-family default): Rejected — unnecessary complexity, `true` is the right default for this project

## Decision 3: Backward compatibility handling for keyboardLayout

**Decision**: Remove `keyboardLayout` from schema entirely. No compatibility shim.

**Rationale**: Constitution v2.3.0 "No Backward Compatibility" principle explicitly prohibits aliases, deprecation warnings, and conditional logic supporting old patterns. The field is removed, all consumers updated in the same commit.

**Alternatives considered**:

- Keep both fields with alias: Prohibited by constitution
- Deprecation warning: Prohibited by constitution

## Decision 4: Files requiring modification

**Decision**: 11 files reference `keyboardLayout`. Of these, 9 are production code requiring updates, 2 are old spec contracts (informational only).

**Files to modify**:

| File | Change |
|------|--------|
| `user/shared/lib/user-schema.nix` | Replace `keyboardLayout` with `keyboard` submodule |
| `user/cdrokar/default.nix` | Migrate to `keyboard.layout` + add `macStyleMappings` |
| `user/shared/template/developer.nix` | Migrate to `keyboard` block |
| `user/shared/template/basic-english.nix` | Migrate to `keyboard` block |
| `user/shared/template/basic-french.nix` | Migrate to `keyboard` block |
| `system/shared/family/linux/settings/system/keyboard.nix` | Read from `keyboard.layout`, conditionally apply swap based on `keyboard.macStyleMappings` |
| `system/shared/family/gnome/settings/user/keyboard.nix` | Read from `keyboard.layout`, conditionally apply XKB options based on `keyboard.macStyleMappings` |
| `system/shared/family/niri/settings/user/keyboard.nix` | Read from `keyboard.layout` |
| `system/darwin/settings/system/keyboard.nix` | Read from `keyboard.layout` |

**Spec contracts (no change needed — historical reference)**:

- `specs/018-user-locale-config/contracts/user-locale-schema.nix`
- `specs/018-user-locale-config/contracts/keyboard-layout-translation-schema.nix`

## Decision 5: Conditional XKB options application

**Decision**: When `macStyleMappings = false`, the `xkb.options` and GNOME `xkb-options` are set to empty (omitting the swap entries). When `true`, the current swap options are applied.

**Rationale**: The swap options (`ctrl:swap_lwin_lctl`, `ctrl:swap_rwin_rctl`) are the only XKB options currently set. When disabled, the field should be empty rather than removed, to ensure no stale options persist.

**Alternatives considered**:

- `lib.mkIf` to conditionally include: Works but leaves no explicit value when false — could inherit unexpected defaults
- Separate XKB options list: Over-engineering for current scope
