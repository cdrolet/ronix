# Quickstart: User Wallpaper Configuration

**Feature**: 033-user-wallpaper-config\
**Date**: 2025-12-30\
**For**: End Users

## Overview

Set your desktop wallpaper declaratively in your user configuration. Works on both macOS (Darwin) and GNOME desktop environments with the same simple syntax.

______________________________________________________________________

## Basic Usage

### Step 1: Add Wallpaper to Your User Configuration

Edit your user configuration file (`user/<username>/default.nix`):

```nix
{ ... }:

{
  user = {
    name = "alice";
    email = "alice@example.com";
    
    # Add this line with your wallpaper path
    wallpaper = "~/Pictures/my-wallpaper.jpg";
    
    applications = [ "git" "zsh" "firefox" ];
  };
}
```

### Step 2: Rebuild Your System

**On macOS:**

```bash
just install alice home-macbook
```

**On NixOS:**

```bash
just install alice nixos-desktop
```

### Step 3: Observe the Result

Your wallpaper will be applied automatically:

- **macOS**: All displays show the same wallpaper
- **GNOME**: Wallpaper applied in both light and dark modes

______________________________________________________________________

## Path Formats

### Home-Relative Paths (Recommended)

Use tilde (`~`) for portability across machines:

```nix
wallpaper = "~/Pictures/wallpaper.jpg";
wallpaper = "~/Wallpapers/nature-scene.png";
wallpaper = "~/Desktop/background.heic";
```

### Absolute Paths

```nix
# macOS
wallpaper = "/Users/alice/Pictures/wallpaper.jpg";

# Linux
wallpaper = "/home/bob/Pictures/wallpaper.png";
```

______________________________________________________________________

## Supported Image Formats

Both platforms support common image formats:

| Format | Extension | Notes |
|--------|-----------|-------|
| JPEG | `.jpg`, `.jpeg` | Most common, good compression |
| PNG | `.png` | Lossless, supports transparency |
| HEIC | `.heic` | High efficiency, supports dynamic wallpapers (macOS) |
| WebP | `.webp` | Modern format, excellent compression |
| SVG | `.svg` | Scalable vector graphics (GNOME only) |

**Recommendation**: Use JPEG or PNG for maximum compatibility.

______________________________________________________________________

## Examples

### Example 1: Simple Configuration

```nix
{
  user = {
    name = "alice";
    wallpaper = "~/Pictures/mountain-view.jpg";
  };
}
```

### Example 2: With Spaces in Filename

```nix
{
  user = {
    name = "bob";
    wallpaper = "~/Pictures/Northern Lights 2024.png";
    # Spaces are handled automatically
  };
}
```

### Example 3: Shared Folder

```nix
{
  user = {
    name = "charlie";
    wallpaper = "/mnt/shared/wallpapers/corporate-bg.jpg";
  };
}
```

______________________________________________________________________

## Troubleshooting

### "Wallpaper file not found" Warning

**Symptom**: You see a warning during build:

```
warning: Wallpaper file not found: /Users/alice/Pictures/wallpaper.jpg
```

**Solutions**:

1. **Check the file exists**: `ls ~/Pictures/wallpaper.jpg`
1. **Verify the path is correct** - check for typos
1. **Ensure file is readable**: `file ~/Pictures/wallpaper.jpg`

**Note**: The build will complete successfully even with this warning. The wallpaper just won't be applied.

### "Unsupported extension" Warning

**Symptom**: Warning about unsupported file format

**Solution**: Rename or convert your image to a supported format:

```bash
# Convert to JPEG
convert wallpaper.bmp wallpaper.jpg

# Convert to PNG
convert wallpaper.tiff wallpaper.png
```

### Wallpaper Not Changing (macOS)

**Symptom**: Configuration builds successfully but wallpaper doesn't change

**Common causes**:

1. **TCC Permission**: First time requires permission approval

   - Look for popup: "Terminal wants to control System Events"
   - Click "OK" to approve
   - Rebuild: `just install <user> <host>`

1. **File doesn't exist**: Check runtime logs

   ```bash
   # Check activation output for warnings
   just build alice home-macbook 2>&1 | grep -i wallpaper
   ```

1. **Absolute path required**: Ensure tilde was expanded

   ```bash
   # Verify in activation script
   cat result/activate | grep WALLPAPER
   ```

### Wallpaper Not Changing (GNOME)

**Symptom**: Configuration builds but wallpaper unchanged

**Common causes**:

1. **Wrong URI format**: Check dconf value

   ```bash
   gsettings get org.gnome.desktop.background picture-uri
   # Should show: 'file:///home/username/Pictures/wallpaper.jpg'
   ```

1. **Dark mode active**: Ensure `picture-uri-dark` is set

   ```bash
   gsettings get org.gnome.desktop.background picture-uri-dark
   ```

1. **File permissions**: Ensure file is readable

   ```bash
   ls -l ~/Pictures/wallpaper.jpg
   # Should show: -rw-r--r-- (or similar)
   ```

**Manual fix** (temporary):

```bash
gsettings set org.gnome.desktop.background picture-uri "file://$(realpath ~/Pictures/wallpaper.jpg)"
gsettings set org.gnome.desktop.background picture-uri-dark "file://$(realpath ~/Pictures/wallpaper.jpg)"
```

______________________________________________________________________

## Platform-Specific Notes

### macOS (Darwin)

**Behavior:**

- Wallpaper applied to **all monitors** (same image on each display)
- First run requires TCC permission approval (one-time)
- Changes apply immediately after activation
- Wallpaper persists across reboots

**Limitations:**

- Cannot set different wallpapers per monitor (use third-party app if needed)
- Dynamic wallpapers (time-of-day changing) require special HEIC format

### GNOME Desktop

**Behavior:**

- Wallpaper applied to **all monitors** (zoomed to fit)
- Separate wallpapers for light and dark modes (currently both set to same image)
- Changes apply immediately (no logout required)
- Lock screen wallpaper can be configured separately (future enhancement)

**Limitations:**

- Requires active GNOME session (not applicable to other desktops like KDE)
- Per-monitor wallpapers require third-party tools

______________________________________________________________________

## Advanced Usage (Future Enhancements)

These features are planned but not yet implemented:

### Separate Light/Dark Mode Wallpapers (GNOME)

```nix
# Future API (not yet implemented)
user = {
  wallpaperLight = "~/Pictures/light-mode.jpg";
  wallpaperDark = "~/Pictures/dark-mode.jpg";
};
```

### Per-Monitor Wallpapers

```nix
# Future API (not yet implemented)
user = {
  wallpapers = [
    { monitor = 0; path = "~/Pictures/left.jpg"; }
    { monitor = 1; path = "~/Pictures/right.jpg"; }
  ];
};
```

### Wallpaper from Nix Store

```nix
# Future API (not yet implemented)
user = {
  wallpaper = ./my-wallpaper.jpg;  # Bundled in config repo
};
```

______________________________________________________________________

## FAQ

### Q: Can I use URLs for wallpapers?

**A:** Not currently. Only local file paths are supported. Download the wallpaper first:

```bash
wget https://example.com/wallpaper.jpg -O ~/Pictures/wallpaper.jpg
```

### Q: Does this work on other desktop environments (KDE, XFCE)?

**A:** Not yet. Currently only Darwin (macOS) and GNOME are supported. Support for other environments could be added in the future.

### Q: Will my wallpaper sync across machines?

**A:** Only if you:

1. Use the same file path on all machines (e.g., `~/Pictures/wallpaper.jpg`)
1. Ensure the wallpaper file exists at that path on each machine

The configuration syncs, but the wallpaper file itself must be present on each system.

### Q: Can I rotate wallpapers automatically?

**A:** Not with this feature. Consider using:

- **macOS**: Third-party apps like Irvue or Dynamic Wallpaper
- **GNOME**: `wallpaper-slideshow` or `variety` packages

### Q: What happens if I remove the wallpaper field?

**A:** The configuration is removed, but the currently-set wallpaper remains. To reset to system default, manually change it through system settings.

______________________________________________________________________

## Quick Reference

**Minimal configuration:**

```nix
user.wallpaper = "~/Pictures/wallpaper.jpg";
```

**Rebuild system:**

```bash
just install <user> <host>
```

**Check current wallpaper:**

```bash
# macOS
osascript -e 'tell application "Finder" to get desktop picture as alias'

# GNOME
gsettings get org.gnome.desktop.background picture-uri
```

**Reset to default:**

```nix
# Remove or comment out the wallpaper field
# user.wallpaper = "~/Pictures/wallpaper.jpg";
```

______________________________________________________________________

## Getting Help

If you encounter issues:

1. **Check warnings during build**: Look for "Wallpaper" in output
1. **Verify file exists**: `ls -l <path-to-wallpaper>`
1. **Test manually**:
   - macOS: `osascript -e 'tell application "Finder" to set desktop picture to POSIX file "/path/to/wallpaper.jpg"'`
   - GNOME: `gsettings set org.gnome.desktop.background picture-uri "file:///path/to/wallpaper.jpg"`
1. **Check logs**: Review activation script output for error messages

Still stuck? File an issue with:

- Your platform (macOS version or NixOS + GNOME version)
- Your wallpaper configuration (path and file extension)
- Any warning/error messages from build output
