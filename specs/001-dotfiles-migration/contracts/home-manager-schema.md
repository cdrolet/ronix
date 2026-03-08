# Configuration Contract: Home Manager User Schema

**Purpose**: Define the structure for Home Manager user configurations

______________________________________________________________________

## User Configuration Template

```nix
{config, pkgs, lib, ...}: {
  # User identity
  home = {
    username = "charles";
    homeDirectory = "/Users/charles";  # or "/home/charles" on Linux
    stateVersion = "23.11";
  };

  # Packages
  home.packages = with pkgs; [
    # CLI tools
    zoxide
    atuin
    ripgrep
    fd
    bat
    eza
    
    # Development
    nodejs
    python3
    go
  ];

  # Program configurations
  programs = {
    git = {
      enable = true;
      userName = "Charles Drolet";
      userEmail = "charles@example.com";
    };
    
    zsh = {
      enable = true;
      enableCompletion = true;
      # ... additional config
    };
    
    starship.enable = true;
  };

  # Import program modules
  imports = [
    ./programs/git.nix
    ./programs/zsh
    ./programs/starship.nix
  ];
}
```

## Required Fields

- `home.username` (string): System username
- `home.homeDirectory` (path): Absolute path to home
- `home.stateVersion` (string): Home Manager version

## Optional Sections

- `home.packages` (list): User-specific packages
- `programs.<name>` (attrset): Program configurations
- `home.file.<path>` (attrset): File generation
- `xdg.configFile.<path>` (attrset): XDG config files
- `home.sessionVariables` (attrset): Environment variables

## Program Configuration Pattern

Each program MUST:

- Have `enable = true` to activate
- Use Home Manager's built-in program modules when available
- Fallback to manual file generation for unsupported programs

Example for supported program:

```nix
programs.helix = {
  enable = true;
  settings = {
    theme = "nord";
    editor.line-number = "relative";
  };
};
```

Example for unsupported program:

```nix
xdg.configFile."aerospace/aerospace.toml".text = ''
  # AeroSpace configuration
  ...
'';
```

## File Structure

```
common/users/<username>/
├── default.nix          # Main user config (this file)
├── packages.nix         # Package definitions
└── programs/            # Program configurations
    ├── git.nix
    ├── zsh/
    │   ├── default.nix
    │   ├── environment.nix
    │   └── ...
    ├── starship.nix
    └── helix.nix
```

## Validation

```bash
home-manager build --flake .#<username>
home-manager switch --flake .#<username>
```
