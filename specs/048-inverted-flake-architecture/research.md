# Research: Feature 048 — Inverted Flake Architecture

## 1. `just import` with runtime-computed paths

**Decision**: Use `just --justfile` wrapper pattern, NOT `import`.

**Rationale**: `import` in `just` requires a **string literal** path resolved at parse time. Variables computed via backtick expressions (shell commands) cannot be used as `import` targets. The `nix flake metadata` path is a Nix store path that changes with each `flake.lock` update — it must be computed at runtime.

**Pattern chosen**:
```just
# usst/justfile
_nix_config_dir := `nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes["nix-config"].path'`

# Delegate every recipe to nix-config's justfile
build *args:
    just --justfile "{{_nix_config_dir}}/justfile" --working-directory . build {{args}}
```

**Alternative considered**: Generate a `nix-config.justfile` symlink in `.envrc` via direnv.
**Rejected because**: Requires direnv, adds indirection, symlink breaks on `nix flake update`.

**Alternative considered**: Hardcode `~/.config/nix-config/justfile` as a known clone location.
**Rejected because**: Defeats the purpose — private repo should be self-contained without requiring framework repo to be separately cloned.

---

## 2. `nix-config.lib.mkOutputs` — Library API Design

**Decision**: Expose a single `lib.mkOutputs` function in `nix-config/flake.nix`.

**Rationale**: Mirrors how nix-darwin and home-manager expose `lib.darwinSystem` / `lib.homeManagerConfiguration`. Single entry point is simpler than separate `mkDarwinConfigurations`, `mkNixosConfigurations`, etc.

**Signature**:
```nix
lib.mkOutputs = {
  inputs,          # All flake inputs from usst's flake (must include nix-darwin, home-manager, etc.)
  privateConfigRoot,  # self (the usst flake's self)
} -> {
  darwinConfigurations,
  nixosConfigurations,
  homeConfigurations,
  formatter,
  devShells,
  packages,
  apps,
}
```

**Input follows**: `usst/flake.nix` must re-export all nix-config's inputs as follows:
```nix
inputs.nixpkgs.follows = "nix-config/nixpkgs";
inputs.nix-darwin.follows = "nix-config/nix-darwin";
inputs.home-manager.follows = "nix-config/home-manager";
# etc.
```
This avoids duplicate nixpkgs in closure.

---

## 3. `discovery.nix` hardcoded path issue

**Finding**: `discoverHosts` in `system/shared/lib/discovery.nix` uses:
```nix
hostPath = ./../../${system}/host;
```
This is a relative path from `system/shared/lib/` — works when nix-config is the root, fails when imported as a library.

**Decision**: Pass `repoRoot` explicitly to `discoverHosts`, replacing the relative path. `repoRoot` is already threaded through `config-loader.nix` as a parameter — the same pattern extends naturally.

**Change**:
```nix
# Before
discoverHosts = system: let hostPath = ./../../${system}/host; ...

# After
discoverHosts = system: repoRoot: let hostPath = repoRoot + "/system/${system}/host"; ...
```

All callers already have access to `repoRoot` (= `self` in nix-config's flake, or the resolved store path of nix-config in usst's flake).

---

## 4. Standalone mode for framework development

**Decision**: Keep `nix-config/flake.nix` functional as standalone root flake for framework development.

**Rationale**: Framework developers need `nix flake check`, `nix build`, etc. without a private repo. The stub `config/.gitkeep` approach (Feature 047) remains — evaluates to zero configurations, no error.

**Implementation**: `nix-config/flake.nix` gains a thin wrapper that calls its own `lib.mkOutputs` with `self` as privateConfigRoot (the stub). No duplication — the existing outputs section becomes the `lib.mkOutputs` implementation.

---

## 5. Passing `inputs` from usst vs nix-config

**Finding**: Platform libs (darwin.nix, nixos.nix, home-manager.nix) use inputs for: `inputs.nix-darwin`, `inputs.home-manager`, `inputs.stylix`, `inputs.disko`, `inputs.claude-code-nix`, `inputs.nix-cachyos-kernel`.

**Decision**: usst passes its own `inputs` (which follow nix-config inputs). This ensures consistent nixpkgs version across all builds.

**Constraint**: usst's `flake.nix` must declare `follows` for every nix-config input used by platform libs. The `lib.mkOutputs` docstring will list required inputs.
