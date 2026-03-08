# Research: User Dock Configuration

**Feature**: 023-user-dock-config
**Date**: 2025-12-18
**Status**: Complete

## Executive Summary

Research confirms the proposed approach is viable. Key findings:

1. **Darwin**: dockutil provides full control; trash/finder are special (can't be fully removed without hacks)
1. **GNOME**: gsettings with `.desktop` file names; trash requires custom `.desktop` file
1. **KDE**: Config file `~/.config/plasma-org.kde.plasma.desktop-appletsrc`; uses `.desktop` files

______________________________________________________________________

## RQ1: Application Path Resolution Strategy

### Darwin

**Finding**: Search known locations is the recommended approach.

**Locations to search** (in priority order):

1. `/Applications/*.app` - User-installed apps
1. `/System/Applications/*.app` - System apps (Mail, Maps, etc.)
1. `/System/Applications/Utilities/*.app` - Utility apps
1. `~/Applications/*.app` - User-local apps

**Resolution algorithm**:

```
For app name "obsidian":
1. Search /Applications/Obsidian.app (case-insensitive)
2. Search /System/Applications/Obsidian.app
3. Search /System/Applications/Utilities/Obsidian.app
4. Search ~/Applications/Obsidian.app
5. If not found, skip silently
```

**Existing code**: `system/darwin/lib/dock.nix` already uses dockutil which handles paths.

### GNOME

**Finding**: Use `.desktop` file names with gsettings.

**Configuration command**:

```bash
gsettings set org.gnome.shell favorite-apps \
  "['firefox.desktop', 'org.gnome.Terminal.desktop', 'nautilus.desktop']"
```

**Desktop file locations** (search order):

1. `~/.local/share/applications/` - User .desktop files
1. `/usr/share/applications/` - System .desktop files
1. `/var/lib/flatpak/exports/share/applications/` - Flatpak apps
1. `~/.local/share/flatpak/exports/share/applications/` - User Flatpak apps

**Resolution algorithm**:

```
For app name "firefox":
1. Search for firefox.desktop in known locations
2. Search for *firefox*.desktop (partial match)
3. Search by Exec field containing "firefox"
4. If not found, skip silently
```

### KDE

**Finding**: Uses `.desktop` files via plasma config.

**Config file**: `~/.config/plasma-org.kde.plasma.desktop-appletsrc`

**Pinned apps format**: Comma-delimited list of .desktop file names

**Note**: KDE is lower priority; GNOME covers most Linux desktop use cases.

### Recommendation

**Use hybrid approach**:

1. Try desktop metadata (Feature 019) if available
1. Fall back to filesystem search
1. Skip silently if not found

______________________________________________________________________

## RQ2: Folder Path Resolution Strategy

### Confirmed Approach

The `/FolderName` syntax uses a fallback resolution:

1. **First**: Try as user-relative path (`$HOME/<name>`)
1. **Then**: Try as absolute path (`/<name>`)
1. **Finally**: Skip if neither exists

| User Config | Try First | Try Second | Example Use Case |
|-------------|-----------|------------|------------------|
| `/Downloads` | `$HOME/Downloads` | `/Downloads` | User downloads folder |
| `/Documents` | `$HOME/Documents` | `/Documents` | User documents |
| `/Volumes/External` | `$HOME/Volumes/External` (unlikely) | `/Volumes/External` | Mounted drive on darwin |
| `/mnt/data` | `$HOME/mnt/data` (unlikely) | `/mnt/data` | Mount point on linux |

**Implementation**:

```nix
resolveFolderPath = folderName: userName: let
  userPath = if stdenv.isDarwin
    then "/Users/${userName}/${folderName}"
    else "/home/${userName}/${folderName}";
  absolutePath = "/${folderName}";
in
  if builtins.pathExists userPath then userPath
  else if builtins.pathExists absolutePath then absolutePath
  else null;  # Skip if neither exists
```

**Benefits of fallback approach**:

- Common folders (`/Downloads`) resolve to user home
- System paths (`/Volumes/Backup`, `/mnt/data`) work as absolute paths
- No need for different syntax for user vs system folders

______________________________________________________________________

## RQ3: GNOME/KDE Dock Configuration

### GNOME

**API**: `gsettings` / `dconf`

**Schema**: `org.gnome.shell`
**Key**: `favorite-apps`
**Type**: Array of strings (`.desktop` file names)

**Commands**:

```bash
# Read current favorites
gsettings get org.gnome.shell favorite-apps

# Set favorites
gsettings set org.gnome.shell favorite-apps \
  "['firefox.desktop', 'org.gnome.Nautilus.desktop']"

# Reset to default
gsettings reset org.gnome.shell favorite-apps
```

**Home Manager integration**: Use `dconf.settings` option:

```nix
dconf.settings = {
  "org/gnome/shell" = {
    favorite-apps = [ "firefox.desktop" "org.gnome.Nautilus.desktop" ];
  };
};
```

### KDE

**Config**: `~/.config/plasma-org.kde.plasma.desktop-appletsrc`

**Format**: INI-style with comma-delimited launcher lists

**Home Manager**: May need to use `home.file` to write config, or use plasma-manager module.

**Priority**: Lower than GNOME for initial implementation.

______________________________________________________________________

## RQ4: Module Execution Timing

### Confirmed Approach

Dock module must run in **activation phase** (after package installation).

**Darwin**: Already works this way via `system.activationScripts.configureDock`

**GNOME/NixOS**: Use Home Manager's `home.activation` for user-level changes:

```nix
home.activation.configureDock = lib.hm.dag.entryAfter ["writeBoundary"] ''
  ${pkgs.glib}/bin/gsettings set org.gnome.shell favorite-apps "['...']"
'';
```

**Rationale**: Apps must be installed before paths can be verified.

______________________________________________________________________

## RQ5: Trash Handling

### Darwin

**Finding**: Trash is a special dock item that cannot be easily removed.

- Trash icon is added by macOS automatically
- Cannot be removed via dockutil
- Workarounds exist but require modifying system files (not recommended)
- Position is always rightmost (after all other items)

**Recommendation for darwin**:

- `<trash>` in config is a no-op (darwin handles automatically)
- Document that trash position cannot be controlled on darwin
- Or: Skip `<trash>` on darwin since it's always present

### GNOME

**Finding**: Trash requires creating a custom `.desktop` file.

**Trash .desktop file** (`~/.local/share/applications/trash.desktop`):

```ini
[Desktop Entry]
Type=Application
Name=Trash
Comment=Trash
Icon=user-trash-full
Exec=nautilus trash://
Categories=Utility;
```

**Then add to favorites**:

```bash
gsettings set org.gnome.shell favorite-apps \
  "['firefox.desktop', 'trash.desktop']"
```

**Alternative**: Use [Trash extension](https://extensions.gnome.org/extension/48/trash/) for GNOME Shell.

**Recommendation for GNOME**:

- Create trash.desktop file if `<trash>` in config
- Add to favorite-apps at specified position
- Fully controllable (position, presence)

### KDE

**Finding**: KDE has built-in trash functionality.

- Trash typically accessed via file manager
- Can be pinned to panel like any app
- Uses standard freedesktop trash spec

______________________________________________________________________

## Implementation Recommendations

### Phase 1: Darwin (Refactor existing)

1. Move app list from `settings/dock.nix` to user config
1. Read `user.docked` in `lib/dock.nix`
1. Resolve app names to `/Applications/*.app` paths
1. Handle folders with `mkDockAddFolder`
1. Ignore `<trash>` (darwin manages automatically)

### Phase 2: GNOME

1. Create `system/shared/family/gnome/lib/dock.nix`
1. Read `user.docked` from user config
1. Resolve app names to `.desktop` file names
1. Create `trash.desktop` if `<trash>` present
1. Use `dconf.settings` for favorite-apps

### Phase 3: KDE (Future)

1. Create `system/shared/family/kde/lib/dock.nix`
1. Similar approach to GNOME
1. Lower priority

______________________________________________________________________

## Syntax Finalization

Based on research, the proposed syntax is confirmed:

```nix
docked = [
  # Applications - resolved to platform paths
  "zen"
  "brave"
  "firefox"
  
  # Separators
  "|"                    # Standard spacer
  "||"                   # Thick spacer (darwin only, fallback to | elsewhere)
  
  # Folders - resolved to $HOME/<name>
  "/Downloads"
  "/Documents"
  
  # System items
  "<trash>"              # Trash (GNOME: controllable, darwin: no-op)
  "<launchpad>"          # Future: darwin Launchpad
];
```

______________________________________________________________________

## Open Questions Resolved

| Question | Answer |
|----------|--------|
| How to resolve app names? | Search filesystem in known locations |
| How to resolve folders? | Expand to `$HOME/<name>` |
| How does GNOME dock work? | gsettings with .desktop file names |
| How does KDE dock work? | Plasma config with .desktop files |
| When to run dock config? | Activation phase (after packages installed) |
| How is trash handled? | Darwin: automatic; GNOME: custom .desktop file |

______________________________________________________________________

## Sources

- [dockutil GitHub](https://github.com/kcrawford/dockutil)
- [GNOME Favorites Documentation](https://help.gnome.org/admin//system-admin-guide/3.12/dconf-favorite-applications.html.en)
- [Red Hat GNOME Configuration](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/using_the_desktop_environment_in_rhel_8/customizing-default-favorite-applications_using-the-desktop-environment-in-rhel-8)
- [GNOME Trash Extension](https://extensions.gnome.org/extension/48/trash/)
- [Adding Trash to Ubuntu Dock](https://www.linuxuprising.com/2018/05/how-to-add-dynamic-trash-icon-to-ubuntu.html)
- [KDE Panel Documentation](https://docs.kde.org/stable5/en/plasma-desktop/plasma-desktop/panel.html)
- [Baeldung: GNOME Favorites Storage](https://www.baeldung.com/linux/gnome-favorites)
- [Omakub Dock Configuration](https://deepwiki.com/basecamp/omakub/6.2-dock-and-favorites)
