# Research: User Font Configuration

**Feature**: 030-user-font-config
**Date**: 2025-12-26

## Research Questions

### 1. How does Home Manager handle font installation?

**Decision**: Use `home.packages` for nixpkgs fonts and `home.file` for custom fonts

**Findings**:

- Home Manager installs fonts via `home.packages` with font packages from nixpkgs
- Common font packages: `pkgs.fira-code`, `pkgs.jetbrains-mono`, `pkgs.nerdfonts`, `pkgs.source-code-pro`
- Fonts are automatically available after activation (no manual cache update needed on most systems)
- Custom fonts can be placed in `~/.local/share/fonts/` (Linux) or `~/Library/Fonts/` (macOS)

**Font Package Pattern**:

```nix
home.packages = with pkgs; [
  fira-code
  jetbrains-mono
  source-code-pro
  (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
];
```

### 2. How to install fonts from local directory?

**Decision**: Use `home.file` to symlink font files to user font directory

**Findings**:

- Linux: `~/.local/share/fonts/` is the standard user font directory
- macOS: `~/Library/Fonts/` is the user font directory
- Home Manager's `home.file` can create symlinks to font files
- After placing fonts, run `fc-cache -f` (Linux) to update font cache

**Pattern for local fonts**:

```nix
home.file = {
  ".local/share/fonts/custom" = {
    source = /path/to/font/directory;
    recursive = true;
  };
};
```

### 3. How to clone private git repo with deploy key?

**Decision**: Use activation script with SSH key from secrets, similar to ssh.nix pattern

**Findings**:

- Existing pattern in `ssh.nix` deploys keys via `secrets.mkActivationScript`
- Deploy key would be stored at `~/.ssh/id_fonts`
- Git clone with specific key: `GIT_SSH_COMMAND='ssh -i ~/.ssh/id_fonts' git clone ...`
- Clone to `~/.local/share/fonts/private/` (Linux) or `~/Library/Fonts/private/` (macOS)

**Pattern**:

```nix
home.activation.clonePrivateFonts = lib.hm.dag.entryAfter ["writeBoundary"] ''
  if [ -f ~/.ssh/id_fonts ]; then
    export GIT_SSH_COMMAND='ssh -i ~/.ssh/id_fonts -o StrictHostKeyChecking=accept-new'
    if [ -d ~/fonts-repo ]; then
      cd ~/fonts-repo && git pull
    else
      git clone git@github.com:user/fonts.git ~/fonts-repo
    fi
  fi
'';
```

### 4. How to configure default font on macOS?

**Decision**: Use `defaults write` for Terminal.app monospace font (limited system-wide options)

**Findings**:

- macOS doesn't have a single "system monospace font" setting
- Each application manages its own font preferences
- Terminal.app font can be set via defaults (complex plist structure)
- iTerm2, VS Code, etc. have their own config mechanisms
- Recommendation: Configure monospace font in specific apps rather than "system-wide"

**Limitation**: macOS doesn't provide a centralized monospace font setting. The spec mentions "system font preferences" but this is application-specific on macOS.

**Alternative approach**: Skip macOS-specific font configuration or only configure specific apps.

### 5. How to configure default font on GNOME?

**Decision**: Use dconf settings in `org/gnome/desktop/interface`

**Findings**:

- GNOME has clear monospace font setting via dconf
- Existing pattern in `system/shared/family/gnome/settings/ui.nix`
- Setting: `org/gnome/desktop/interface/monospace-font-name`

**Pattern**:

```nix
dconf.settings = {
  "org/gnome/desktop/interface" = {
    monospace-font-name = "Fira Code 11";
  };
};
```

### 6. Font naming conventions in nixpkgs

**Decision**: Use attribute name from nixpkgs (e.g., `fira-code`, `jetbrains-mono`)

**Findings**:

- nixpkgs uses lowercase-hyphenated names as package attributes
- Common fonts and their nixpkgs names:
  - `pkgs.fira-code` → "Fira Code"
  - `pkgs.jetbrains-mono` → "JetBrains Mono"
  - `pkgs.source-code-pro` → "Source Code Pro"
  - `pkgs.noto-fonts-mono` → "Noto Mono"
- Font family name (for desktop config) differs from package name
- Need mapping: package name → font family name

**Font name mapping** (package → family):

```nix
fontFamilyNames = {
  "fira-code" = "Fira Code";
  "jetbrains-mono" = "JetBrains Mono";
  "source-code-pro" = "Source Code Pro";
  "berkeleymono" = "Berkeley Mono";  # Private font
};
```

## Architecture Decisions

### Module Structure

```
system/shared/settings/fonts.nix          # Core: font options, package installation, private repo clone
system/darwin/settings/fonts.nix          # Darwin: default font config (if feasible)
system/shared/family/gnome/settings/fonts.nix  # GNOME: dconf monospace font
```

### User Schema Extension

Add to `user/shared/lib/home-manager.nix`:

```nix
fonts = lib.mkOption {
  type = lib.types.nullOr (lib.types.submodule {
    options = {
      default = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      repositories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };
  });
  default = null;
};
```

### Private Font Repository Flow

1. User sets `sshKeys.fonts = "<secret>"` in config
1. SSH module deploys key to `~/.ssh/id_fonts` at activation
1. Fonts module clones repositories using that key
1. Font files are copied/symlinked to user font directory
1. Font cache is refreshed

#### 7. How can apps reference the default font?

**Decision**: Apps use `config.user.fonts.default or "monospace"` pattern

**Findings**:

- Apps can access user config via `config.user.fonts.default`
- Use `lib.mkDefault` to allow user overrides
- Fall back to sensible default when not set

**Pattern**:

```nix
# In any app module
{ config, lib, pkgs, ... }:
{
  programs.someApp = {
    settings = {
      font = lib.mkDefault (config.user.fonts.default or "monospace");
    };
  };
}
```

**Benefits**:

- Single source of truth for preferred font
- Consistent experience across all apps
- User can still override per-app if needed

## Alternatives Considered

1. **System-level font installation** (rejected): Requires root, less portable
1. **Flake input for font repo** (rejected): Requires token in flake.nix, less flexible
1. **Per-user deploy keys** (rejected): More complex, shared key is sufficient for this use case
1. **Per-app font configuration only** (rejected): Requires duplicating font choice in every app
