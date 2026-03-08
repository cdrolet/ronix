# Data Model: Keyboard Configuration Restructure

**Feature**: 044-keyboard-config-restructure
**Date**: 2026-02-07

## Entities

### Keyboard Configuration (user.keyboard)

User-level configuration block for keyboard preferences.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| layout | list of string (nullable) | null | Ordered list of platform-agnostic keyboard layout names. First is default. |
| macStyleMappings | boolean | true | Whether to swap Super/Ctrl keys on Linux for mac-style behavior. |

**Relationships**:

- `layout` values must exist in the shared keyboard layout registry (`system/shared/lib/keyboard-layouts.nix`)
- `layout` is translated by platform-specific translation layers (Darwin IDs, XKB codes, GNOME input sources)
- `macStyleMappings` is consumed by Linux family (system-level) and GNOME family (user-level) keyboard settings

### Keyboard Layout (unchanged)

Platform-agnostic layout identifier mapped to platform-specific representations.

| Layout Name | Darwin ID | XKB Layout | XKB Variant | GNOME Input Source |
|-------------|-----------|------------|-------------|-------------------|
| us | 0 ("U.S.") | us | (empty) | xkb:us |
| canadian-english | 29 ("Canadian") | ca | eng | xkb:ca+eng |
| canadian-french | 80 ("Canadian-CSA") | ca | fr | xkb:ca |
| uk | (tbd) | gb | (empty) | xkb:gb |

**No changes to layout registry or translation layers** — only the path from which they read changes.

## State Transitions

None. This is a pure configuration restructure with no runtime state.

## Validation Rules

1. `keyboard.layout` values must be valid keys in the shared layout registry
1. `keyboard.macStyleMappings` is a boolean (enforced by Nix type system)
1. Empty `keyboard.layout` list (`[]`) is treated as "no layouts configured" (platform defaults)
1. `keyboard = null` or omitted entirely means all defaults (no layouts, macStyleMappings = true)
