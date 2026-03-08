# Quickstart: User Font Configuration

**Feature**: 030-user-font-config

## Basic Usage

### 1. Add Fonts from nixpkgs

Simply list the fonts you want in your user configuration:

```nix
# user/cdrokar/default.nix
{ ... }:
{
  user = {
    name = "cdrokar";
    applications = ["*"];
    
    fonts = {
      packages = [
        "fira-code"
        "jetbrains-mono"
        "source-code-pro"
      ];
    };
  };
}
```

### 2. Set a Default Font

Set a default font to configure your desktop environment:

```nix
fonts = {
  default = "fira-code";
  packages = ["fira-code", "jetbrains-mono"];
};
```

On GNOME, this sets the monospace font. On macOS, this is currently a no-op (app-specific configuration).

### 3. Add Private Font Repositories

For proprietary fonts stored in a private git repository:

**Step 1**: Store the deploy key in your secrets

```bash
just secrets-set cdrokar sshKeys.fonts "$(cat ~/.ssh/fonts-deploy-key)"
```

**Step 2**: Reference the key and repository in your config

```nix
# user/cdrokar/default.nix
{ ... }:
{
  user = {
    name = "cdrokar";
    
    # Deploy key for private font repos
    sshKeys.fonts = "<secret>";
    
    fonts = {
      default = "berkeleymono-medium";
      packages = ["fira-code"];
      repositories = [
        "git@github.com:cdrolet/d-fonts.git"
      ];
    };
  };
}
```

## Complete Example

```nix
# user/cdrokar/default.nix
{ ... }:
{
  user = {
    name = "cdrokar";
    email = "<secret>";
    fullName = "<secret>";
    
    applications = ["*"];
    
    # SSH keys for various purposes
    sshKeys = {
      personal = "<secret>";
      fonts = "<secret>";
    };
    
    # Font configuration
    fonts = {
      # Default font for desktop (GNOME monospace)
      default = "berkeleymono-medium";
      
      # Public fonts from nixpkgs
      packages = [
        "fira-code"
        "jetbrains-mono"
        "source-code-pro"
        "noto-fonts-mono"
      ];
      
      # Private font repositories
      repositories = [
        "git@github.com:cdrolet/d-fonts.git"
      ];
    };
  };
}
```

## Apps Using Default Font

Application modules can reference the user's default font for consistent experience:

```nix
# system/shared/app/terminal/ghostty.nix
{ config, lib, pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = lib.mkDefault (config.user.fonts.default or "monospace");
      font-size = 14;
    };
  };
}
```

This pattern:

- Uses user's `fonts.default` if set
- Falls back to "monospace" if not set
- Can be overridden by user with `lib.mkForce`

Apps that can benefit: terminals (Ghostty, Kitty), editors (Helix, Zed), IDEs.

## What Happens at Activation

1. **Deploy key**: If `sshKeys.fonts` is set, the key is deployed to `~/.ssh/id_fonts`
1. **Public fonts**: All packages in `fonts.packages` are installed via Home Manager
1. **Private repos**: Each repository in `fonts.repositories` is cloned/updated to `~/.local/share/fonts/private/`
1. **Font cache**: Linux runs `fc-cache -f` to refresh font cache
1. **Desktop config**: GNOME sets monospace font from `fonts.default`

## Skipped Scenarios

- **No sshKeys.fonts**: Private repositories are silently skipped
- **Invalid package name**: Warning logged, other fonts still installed
- **Unreachable repository**: Warning logged, activation continues
- **No fonts block**: No fonts installed, system defaults used
