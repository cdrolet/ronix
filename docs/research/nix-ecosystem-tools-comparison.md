# Nix Ecosystem Tools Comparison

Research evaluation of external Nix ecosystem tools against the nix-config architecture.

**Date**: 2025-12-16
**Context**: Evaluating whether import-tree, dendritic pattern, or flake-parts would benefit this repository's architecture.

## Executive Summary

| Tool | Recommendation | Reason |
|------|----------------|--------|
| import-tree | **Do not adopt** | Our discovery system is more sophisticated |
| Dendritic pattern | **Do not adopt** | Solves different problems; migration cost exceeds benefit |
| flake-parts | **Do not adopt** | No real problems to solve for a configuration-only flake |
| treefmt-nix | **Adopted** | Provides multi-language formatting with minimal cost |

______________________________________________________________________

## Tool Evaluations

### 1. import-tree

**Source**: [github.com/vic/import-tree](https://github.com/vic/import-tree)

**What it does**: Recursively imports Nix modules from a directory with filtering and transformation APIs.

**Comparison with our discovery system**:

| Capability | Our Discovery System | import-tree |
|------------|---------------------|-------------|
| Recursive file discovery | `discoverModules` | `.files()` / `.leafs()` |
| Exclude patterns | Excludes `default.nix` automatically | Ignores `/_` prefixed paths |
| Platform-aware resolution | `resolveApplications` with hierarchical search | Not supported |
| Family/host composition | `discoverWithHierarchy` (system → family → shared) | Not supported |
| Context detection | `detectContext` (caller type inference) | Not supported |
| Error messages | Rich suggestions ("Did you mean...?") | Basic errors |
| Validation | `validateFamilyExists`, `validateNoWildcardInSettings` | None |
| Wildcard expansion | `"*"` expands to all apps | Not supported |

**Conclusion**: import-tree would replace only ~50 lines of our simplest code (`discoverModules`) while losing the 530+ lines of sophisticated platform-aware discovery logic. Not worth the dependency.

______________________________________________________________________

### 2. Dendritic Pattern

**Source**: [github.com/mightyiam/dendritic](https://github.com/mightyiam/dendritic)

**What it does**: An aspect-oriented Nix configuration pattern where every file is a flake-parts module that configures a single feature across all platforms.

**Example dendritic module**:

```nix
# modules/ssh.nix - configures SSH for ALL platforms in one file
{ ... }: let
  sshPort = 2277;
in {
  flake.modules.nixos.ssh = { services.openssh.ports = [ sshPort ]; };
  flake.modules.darwin.ssh = { /* darwin config */ };
  flake.modules.homeManager.ssh = { programs.ssh.extraConfig = "..."; };
}
```

**Comparison**:

| Aspect | Our Architecture | Dendritic |
|--------|------------------|-----------|
| File meaning | Clear by location (user/host/app) | All files are flake-parts modules |
| Organization | By platform, then by concern | By concern, spanning all platforms |
| Dependency | nix-darwin + home-manager | flake-parts (required) |
| Data pattern | Pure data configs | Module configs with deferredModule |
| User configs | 10-15 lines of pure data | Full flake-parts modules |
| Multi-user support | Built-in via `user/` directory | No built-in concept |

**When dendritic excels**:

- Single developer with many nearly-identical machines
- Strong cross-platform overlap (80%+ identical config)
- Already using flake-parts

**When our architecture excels**:

- Multiple users with isolated configurations
- Host-specific variations via families
- Pure data simplicity (user/host configs are just data)
- Platform-specific apps with graceful degradation

**Conclusion**: Dendritic solves "I'm one person with many identical machines." Our architecture solves "multiple users/hosts with platform-aware discovery." Migration cost far exceeds marginal benefit.

______________________________________________________________________

### 3. flake-parts

**Source**: [flake.parts](https://flake.parts/)

**What it does**: A module system for Nix flakes that provides `perSystem` abstraction and ecosystem module integration.

**Example**:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [ "aarch64-darwin" "x86_64-linux" ];
  perSystem = { pkgs, ... }: {
    packages.foo = pkgs.callPackage ./foo {};
    devShells.default = pkgs.mkShell { ... };
  };
};
```

**Problems flake-parts solves vs. our situation**:

| Problem flake-parts Solves | Do We Have This? |
|---------------------------|------------------|
| Repeating `system` everywhere | No - platform libs handle this |
| flake.nix is 500+ lines | No - ours is ~125 lines |
| Need to split flake.nix | No - already split into platform libs |
| Want devenv/treefmt integration | treefmt works without flake-parts |
| Package-heavy flake | No - configuration-only |

**What we'd lose**:

- Pure data user/host configs
- Custom discovery system with rich errors
- Hierarchical search (system → family → shared)

**Conclusion**: flake-parts is designed for package-heavy flakes. Our configuration-only flake already has good structure. No benefit justifies the migration.

______________________________________________________________________

### 4. treefmt-nix (Adopted)

**Source**: [github.com/numtide/treefmt-nix](https://github.com/numtide/treefmt-nix)

**What it does**: Nix-native configuration for treefmt, enabling multi-language formatting with a single command.

**Why we adopted it**:

| Factor | Assessment |
|--------|------------|
| Solves real problem | Yes - unified multi-language formatting |
| Integration cost | Low - ~20 lines of changes |
| Architectural impact | None - no restructuring needed |
| Dependency cost | One flake input |
| Works without flake-parts | Yes |

**See**: [docs/features/treefmt-nix.md](../features/treefmt-nix.md)

______________________________________________________________________

## Architecture Strengths

Our nix-config architecture provides capabilities these tools cannot match:

### 1. Pure Data Pattern

User and host configs are simple data structures, not modules:

```nix
# user/cdrokar/default.nix
{ user.applications = ["*"]; }
```

### 2. Hierarchical Discovery

Apps and settings search: `system → families → shared` with first-match wins:

```nix
discoverWithHierarchy {
  itemName = "git";
  itemType = "app";
  system = "darwin";
  families = ["linux", "gnome"];
  basePath = repoRoot;
}
```

### 3. Rich Error Messages

When apps aren't found, users get actionable suggestions:

```
error: Application 'gti' not found

Did you mean one of these?
  - git (in shared, darwin)

Tip: Check app name spelling or add the app to system/*/app/
```

### 4. Multi-User Isolation

Each user has isolated configuration with no interference.

### 5. Platform-Aware Graceful Degradation

User configs skip platform-specific apps automatically; host configs fail explicitly.

______________________________________________________________________

## Conclusion

The evaluated tools (import-tree, dendritic, flake-parts) solve problems we don't have or would require losing capabilities we value. Our architecture is well-suited for:

- Multi-user configuration management
- Multi-platform (darwin/nixos) support
- Pure data configuration patterns
- Rich developer experience (error messages, validation)

**treefmt-nix** was the only tool that provided clear value (multi-language formatting) without architectural cost, and has been adopted.

______________________________________________________________________

## References

- [import-tree](https://github.com/vic/import-tree)
- [Dendritic pattern](https://github.com/mightyiam/dendritic)
- [Dendrix documentation](https://dendrix.oeiuwq.com/Dendritic.html)
- [flake-parts](https://flake.parts/)
- [ez-configs](https://flake.parts/options/ez-configs)
- [treefmt-nix](https://github.com/numtide/treefmt-nix)
