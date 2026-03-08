# Quickstart: Keyboard Configuration Restructure

**Feature**: 044-keyboard-config-restructure

## User Configuration

### Before (old)

```nix
user = {
  name = "cdrokar";
  keyboardLayout = ["canadian-english" "canadian-french"];
  # ...
};
```

### After (new)

```nix
user = {
  name = "cdrokar";
  keyboard = {
    layout = ["canadian-english" "canadian-french"];
    macStyleMappings = true;  # default, can omit
  };
  # ...
};
```

### Disable Mac-Style Key Swap on Linux

```nix
user = {
  name = "cdrokar";
  keyboard = {
    layout = ["canadian-english" "canadian-french"];
    macStyleMappings = false;  # Super and Ctrl are NOT swapped
  };
};
```

## Verification

```bash
# Build check
nix flake check

# Full build
just build cdrokar avf-gnome

# On Linux VM: verify XKB options
setxkbmap -query
# With macStyleMappings = true: options should include ctrl:swap_lwin_lctl,ctrl:swap_rwin_rctl
# With macStyleMappings = false: options should NOT include swap entries

# On GNOME: verify dconf
dconf read /org/gnome/desktop/input-sources/xkb-options
# With macStyleMappings = true: ['ctrl:swap_lwin_lctl', 'ctrl:swap_rwin_rctl']
# With macStyleMappings = false: @as [] (empty)
```
