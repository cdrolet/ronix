# Configuration Contract: Module Schema

**Purpose**: Define the standard structure for Nix configuration modules

______________________________________________________________________

## Module Template

```nix
{config, lib, pkgs, ...}:
with lib;
let
  cfg = config.modules.<category>.<module-name>;
in {
  options.modules.<category>.<module-name> = {
    enable = mkEnableOption "Description of what this module provides";
    
    # Additional options
    package = mkOption {
      type = types.package;
      default = pkgs.<package-name>;
      description = "Package to use";
    };
    
    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings";
    };
  };

  config = mkIf cfg.enable {
    # Configuration applied when enabled
    environment.systemPackages = [cfg.package];
    
    # Service configuration
    # File generation
    # etc.
  };
}
```

## Required Structure

### Options Block

- MUST use `mkOption` with explicit types
- MUST include `description` for each option
- SHOULD provide sensible `default` values
- MUST use `mkEnableOption` for enable flag

### Config Block

- MUST wrap with `mkIf cfg.enable`
- MUST only apply when module is enabled
- MAY import other modules via `imports`

## Type System

Use proper Nix types:

- `types.bool` - Boolean values
- `types.str` - Strings
- `types.int` - Integers
- `types.package` - Nix packages
- `types.path` - File paths
- `types.attrs` - Attribute sets
- `types.listOf <type>` - Lists
- `types.enum [...]` - Enumeration

## Platform-Specific Modules

```nix
{config, lib, pkgs, ...}:
with lib;
let
  cfg = config.modules.optional.darwin.aerospace;
in {
  options.modules.optional.darwin.aerospace = {
    enable = mkEnableOption "AeroSpace tiling window manager";
  };

  config = mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    # macOS-only configuration
  };
}
```

Platform checks:

- `pkgs.stdenv.isDarwin` - macOS
- `pkgs.stdenv.isLinux` - Linux/NixOS

## File Naming

- Core modules: `modules/core/<name>.nix`
- Optional modules: `modules/optional/<category>/<name>.nix`
- Platform-specific: `modules/optional/darwin/<name>.nix` or `modules/optional/linux/<name>.nix`

## Validation

Modules MUST:

- Build without errors: `nix flake check`
- Not leak implementation details in descriptions
- Use constitutional directory structure
- Be under 200 lines (or refactor)
