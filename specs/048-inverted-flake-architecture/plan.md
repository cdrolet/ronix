# Implementation Plan: Inverted Flake Architecture

**Branch**: `048-inverted-flake-architecture` | **Date**: 2026-03-08 | **Spec**: [spec.md](spec.md)

## Summary

Invert the framework/private repo relationship: `usst` (private repo) becomes the root flake,
`nix-config` becomes a library flake exposing `lib.mkOutputs`. The justfile stays in `nix-config`
and is delegated to from `usst/justfile` via runtime-resolved flake store path.

## Technical Context

**Language/Version**: Nix (flakes, 2.19+), just 1.x\
**Primary Dependencies**: nix-darwin, home-manager, treefmt-nix, disko, stylix\
**Storage**: N/A (declarative `.nix` files)\
**Testing**: `nix flake check`, `just build`\
**Target Platform**: aarch64-darwin, x86_64-linux, aarch64-linux\
**Project Type**: Nix configuration library\
**Performance Goals**: N/A\
**Constraints**: No duplicate nixpkgs in closure; `just import` not usable for dynamic paths\
**Scale/Scope**: 1 private repo, ~6 hosts, ~1 user

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| Flakes as Entry Point | ✅ | usst becomes root flake |
| Platform-Agnostic Orchestration | ✅ | `lib.mkOutputs` loads platforms lazily |
| Modularity & Reusability | ✅ | Framework now truly reusable as library |
| No Backward Compatibility | ✅ | Breaking change: commands move to usst/ |
| Declarative Configuration First | ✅ | No imperative changes |
| Documentation-Driven Development | ✅ | spec.md + research.md + quickstart.md |

## Project Structure

### Documentation (this feature)

```
specs/048-inverted-flake-architecture/
├── plan.md          ✅ This file
├── spec.md          ✅ Feature specification
├── research.md      ✅ Phase 0 decisions
├── data-model.md    ✅ API contracts
├── quickstart.md    ✅ User guide
└── tasks.md         (Phase 2 — /speckit.tasks)
```

### Source Code Changes

```
nix-config/
├── flake.nix                         # Add lib.mkOutputs; keep standalone self-use
└── system/shared/lib/
    └── discovery.nix                 # Fix discoverHosts: repoRoot param replaces relative path

usst/  (new files)
├── flake.nix                         # Root flake: calls nix-config.lib.mkOutputs
├── flake.lock                        # Pins nix-config + all transitive deps
└── justfile                          # Delegates to nix-config justfile via flake path
```

## Complexity Tracking

No constitution violations.

## Implementation Phases

### Phase 1 — Fix `discovery.nix` hardcoded path

**File**: `system/shared/lib/discovery.nix`

Change `discoverHosts` signature:
```nix
# Before
discoverHosts = system: ...  # uses relative ../../${system}/host

# After
discoverHosts = system: repoRoot: ...  # uses repoRoot + "/system/${system}/host"
```

Update all callers:
- `flake.nix`: `discoverHosts = system: discovery.discoverHosts system self`
- `system/shared/lib/config-loader.nix` (`getPlatformForHost` uses `discoverHosts` transitively)

---

### Phase 2 — Add `lib.mkOutputs` to nix-config

**File**: `nix-config/flake.nix`

Extract the current `outputs` body into a reusable function:

```nix
outputs = { self, nixpkgs, nix-darwin, home-manager, ... }@inputs: let
  mkOutputs = { inputs, privateConfigRoot }: let
    lib = nixpkgs.lib;
    repoRoot = self;   # nix-config store path (framework code)
    discovery = import ./system/shared/lib/discovery.nix { inherit lib; };
    validUsers = discovery.discoverDirectoriesWithDefault (privateConfigRoot + "/users");
    discoverHosts = system: discovery.discoverDirectoriesWithDefault (privateConfigRoot + "/hosts/${system}");
    # ... rest of current outputs logic
  in { darwinConfigurations, nixosConfigurations, homeConfigurations, formatter, devShells, packages, apps };

in (mkOutputs { inherit inputs; privateConfigRoot = inputs.user-host-config; }) // {
  lib = { inherit mkOutputs; };
}
```

Key: `repoRoot` is always `self` (nix-config's own store path), separate from `privateConfigRoot`.

---

### Phase 3 — Add `usst/flake.nix`

```nix
{
  description = "Private user/host configuration";

  inputs = {
    nix-config.url = "github:cdrolet/nix-config";
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

Run `nix flake lock` from `usst/`.

---

### Phase 4 — Add `usst/justfile`

```just
# Resolve nix-config justfile path from flake.lock at runtime
_nix_config_dir := `nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes["nix-config"].path'`
_fw := "just --justfile \"" + _nix_config_dir + "/justfile\" --working-directory \"" + justfile_directory() + "\""

# Public recipes — delegate to framework
build *args:           {{_fw}} build {{args}}
install *args:         {{_fw}} install {{args}}
diff *args:            {{_fw}} diff {{args}}
update *args:          {{_fw}} update {{args}}
check *args:           {{_fw}} check {{args}}
fmt *args:             {{_fw}} fmt {{args}}
list-users:            {{_fw}} list-users
list-hosts:            {{_fw}} list-hosts
list-combinations:     {{_fw}} list-combinations
secrets-set *args:     {{_fw}} secrets-set {{args}}
secrets-list:          {{_fw}} secrets-list
secrets-init-user *a:  {{_fw}} secrets-init-user {{a}}
user-create:           {{_fw}} user-create
clean:                 {{_fw}} clean
```

`NIX_PRIVATE_CONFIG_DIR` defaults to `~/.config/nix-private` (symlink to `usst/`) — no change needed.

---

### Phase 5 — Verification

```bash
# From usst/
nix flake show                          # Shows darwinConfigurations, nixosConfigurations, homeConfigurations
just build cdrokar home-macmini-m4      # Full build via delegated justfile
nix flake check                         # Syntax + schema

# From nix-config/ (standalone, still works)
nix flake show                          # Zero configs (stub), no error
nix flake check                         # Passes
```
