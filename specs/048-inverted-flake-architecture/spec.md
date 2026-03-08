# Feature 048: Inverted Flake Architecture

**Status**: Planning
**Branch**: `048-inverted-flake-architecture`

## Problem

The current relationship is inverted from idiomatic Nix:

```
nix-config/flake.nix  ← root (entry point)
  └── inputs.user-host-config = path:~/.config/nix-private  ← private repo pulled in passively
```

- `just` commands must run from the framework repo (`nix-config/`)
- The private repo (`usst`) has no `flake.nix` — it is a passive non-flake input
- SSH/auth complexity when bootstrapping: framework repo must know where private repo lives
- Justfile is not versioned with private repo, requiring out-of-band synchronisation

## Goal

Invert the relationship so the private repo becomes the root flake:

```
usst/flake.nix  ← root (entry point)
  └── inputs.nix-config = github:cdrolet/nix-config  ← framework pulled in as versioned library
```

- `just` commands run from `usst/`
- `nix-config` is a published, versioned library — pinned via `flake.lock`
- Private repo bootstraps itself: `git clone usst && just install cdrokar home-macmini-m4`
- Framework upgrades are explicit and auditable (`just update-input nix-config`)

## Requirements

### Functional

1. `usst/flake.nix` declares `inputs.nix-config` and calls a single library function to produce all outputs
2. `nix-config` exposes `lib.mkOutputs { inputs, privateConfigRoot }` returning all flake outputs
3. `usst/justfile` resolves the `nix-config` justfile path via flake metadata and delegates all recipes
4. All existing `just` commands (`build`, `install`, `diff`, `secrets-*`, etc.) work unchanged from `usst/`
5. `nix-config` remains buildable standalone for framework development (zero configs, no error)

### Non-Functional

1. No user-visible behaviour change — same commands, same outputs
2. Private repo gains independent versioning of framework dependency
3. Framework repo has no knowledge of any specific private repo
4. Justfile delegation must survive `nix-config` store path changes (i.e., re-resolved on each `flake.lock` update)

## Out of Scope

- Converting the API to JSON format (configs remain `.nix`)
- Publishing `nix-config` to a flake registry
- Multi-user support for the private repo

## Affected Files

| Repo | File | Change |
|------|------|--------|
| `nix-config` | `flake.nix` | Add `lib.mkOutputs` output; keep standalone mode |
| `nix-config` | `system/shared/lib/discovery.nix` | Fix hardcoded relative `../../${system}/host` paths |
| `nix-config` | `justfile` | No change (stays as reusable entrypoint) |
| `usst` | `flake.nix` | **New** — root flake calling `nix-config.lib.mkOutputs` |
| `usst` | `justfile` | **New** — resolves nix-config path, delegates all recipes |
