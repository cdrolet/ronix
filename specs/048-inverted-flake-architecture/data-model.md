# Data Model: Feature 048 — Inverted Flake Architecture

## Library API Contract

### `nix-config.lib.mkOutputs`

```nix
# nix-config/flake.nix (new lib output)
lib.mkOutputs = {
  # Required: all flake inputs from the calling flake
  # Must include: nixpkgs, nix-darwin, home-manager, stylix, disko,
  #               treefmt-nix, claude-code-nix, nix-cachyos-kernel
  inputs,

  # Required: path to private config repo root
  # Contains: users/<name>/default.nix, hosts/<system>/<name>/default.nix
  privateConfigRoot,
} -> {
  darwinConfigurations,    # Map of "{user}-{host}" -> darwinSystem
  nixosConfigurations,     # Map of "{user}-{host}" -> nixosSystem
  homeConfigurations,      # Map of "{user}@{host}" -> homeManagerConfiguration
  formatter,               # Per-system formatter (treefmt)
  devShells,               # Per-system devShells.default
  packages,                # Per-system packages (empty, satisfies schema)
  apps,                    # Per-system apps (empty, satisfies schema)
}
```

---

## File Layout After Feature 048

### nix-config (framework repo) — changes

```
nix-config/
├── flake.nix                        # Exports lib.mkOutputs + standalone self-use
├── system/shared/lib/
│   └── discovery.nix                # Fix: discoverHosts takes repoRoot param
└── specs/048-inverted-flake-architecture/
    └── ...
```

### usst (private repo) — new files

```
usst/
├── flake.nix                        # NEW: root flake, calls nix-config.lib.mkOutputs
├── flake.lock                       # NEW: pins nix-config + transitive deps
├── justfile                         # NEW: delegates to nix-config justfile
├── users/
│   └── cdrokar/default.nix          # Unchanged pure data
└── hosts/
    ├── darwin/*/default.nix         # Unchanged pure data
    └── nixos/*/default.nix          # Unchanged pure data
```

---

## `usst/flake.nix` Contract

```nix
{
  description = "Private user/host configuration";

  inputs = {
    nix-config.url = "github:cdrolet/nix-config";

    # All inputs follow nix-config to avoid duplicate nixpkgs
    nixpkgs.follows           = "nix-config/nixpkgs";
    nix-darwin.follows        = "nix-config/nix-darwin";
    home-manager.follows      = "nix-config/home-manager";
    stylix.follows            = "nix-config/stylix";
    disko.follows             = "nix-config/disko";
    treefmt-nix.follows       = "nix-config/treefmt-nix";
    claude-code-nix.follows   = "nix-config/claude-code-nix";
    nix-cachyos-kernel.follows = "nix-config/nix-cachyos-kernel";
  };

  outputs = { self, nix-config, ... }@inputs:
    nix-config.lib.mkOutputs {
      inherit inputs;
      privateConfigRoot = self;
    };
}
```

---

## `usst/justfile` Contract

```just
# Resolve nix-config store path from flake.lock at runtime
_nix_config_dir := `nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes["nix-config"].path'`

# Delegate all recipes to nix-config justfile
# --working-directory . ensures paths resolve relative to usst/
[doc("Build configuration for user + host")]
build *args:
    just --justfile "{{_nix_config_dir}}/justfile" \
         --working-directory "{{justfile_directory()}}" build {{args}}

install *args:
    just --justfile "{{_nix_config_dir}}/justfile" \
         --working-directory "{{justfile_directory()}}" install {{args}}

# ... repeat for all public recipes
```

**Note**: `private_config_dir` in nix-config's justfile will resolve correctly because:
- `NIX_PRIVATE_CONFIG_DIR` can be set to `usst/` path, OR
- Default `~/.config/nix-private` symlink to `~/project/usst` continues to work

---

## `discovery.nix` API Change

```nix
# Before
discoverHosts = system:
  let hostPath = ./../../${system}/host;
  ...

# After — repoRoot passed explicitly
discoverHosts = system: repoRoot:
  let hostPath = repoRoot + "/system/${system}/host";
  ...
```

All callers updated:
- `flake.nix` (standalone): passes `self` → resolves to nix-config store path
- `lib.mkOutputs`: receives `repoRoot` derived from the nix-config flake input path
