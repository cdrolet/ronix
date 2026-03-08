# Research: Reusable Helper Library for Activation Scripts

**Feature**: Reusable Helper Library for Activation Scripts\
**Date**: 2025-10-26\
**Purpose**: Research Nix patterns for creating reusable helper libraries that generate shell scripts for system activation, focusing on function generators, idempotency, platform abstraction, and library organization.

## Research Questions

1. What are the best patterns for structuring Nix functions that generate shell script text?
1. How can we ensure generated shell scripts are idempotent (safe to run multiple times)?
1. What strategies work best for abstracting platform-specific operations while maintaining clean code separation?
1. How should helper libraries be organized in a hierarchical structure for maintainability and discoverability?

## Findings

### 1. Nix Function Generator Patterns

**Decision**: Use indented strings (`'' ... ''`) with curried function parameters and compositional helpers that return shell script text as strings.

**Rationale**:

- Indented strings minimize escaping requirements for shell scripts (only `''$` needed for shell variables vs `\$` in regular strings)
- Currying enables partial application and function composition
- String-returning functions compose naturally through Nix's string concatenation and interpolation
- Clear separation between Nix-time evaluation and runtime execution
- Pattern used extensively in nix-darwin and home-manager

**Alternatives considered**:

- **writeShellScript derivations**: Too heavyweight for inline script generation; creates separate store paths for each fragment
- **Regular double-quoted strings**: Require excessive escaping (`\${` for every shell variable), harder to read and maintain
- **Monolithic script functions**: Difficult to test and reuse components, violates single responsibility

**Implementation Pattern**:

```nix
# Basic script generator with parameters
mkIdempotentFile = { path, content, mode ? "644" }: ''
  if [ ! -f "${path}" ] || ! grep -qF "${content}" "${path}"; then
    echo "${content}" > "${path}"
    chmod ${mode} "${path}"
  fi
'';

# Curried function for composability
mkRunAsUser = user: cmd: ''
  sudo -u ${user} ${cmd}
'';

# Higher-order generator with list composition
mkDockSettings = settings: lib.concatStringsSep "\n" (
  lib.mapAttrsToList (key: value: ''
    defaults write com.apple.dock "${key}" ${toString value}
  '') settings
);
```

**Key Guidelines**:

- Use `lib.escapeShellArg` for dynamic values
- Apply `toString` explicitly when interpolating non-strings
- Leverage `optionalString` for conditional inclusion
- Use `let` bindings to organize intermediate script fragments

______________________________________________________________________

### 2. Shell Script Idempotency

**Decision**: Implement state-checking guards before modifications, support DRY_RUN mode for testing, and use error handling with status tracking.

**Rationale**:

- Activation scripts run on every system rebuild and must be safe to execute repeatedly
- State checks prevent unnecessary operations and reduce activation time
- DRY_RUN mode enables testing without side effects
- Proper error handling prevents partial application states
- Pattern proven in home-manager's activation system

**Alternatives considered**:

- **Always-execute approach**: Wastes time and creates unnecessary system load on every rebuild
- **Complex diff-based systems**: Too heavyweight; adds fragility and maintenance burden
- **Transactional rollback**: Not supported by most macOS defaults commands or systemd operations

**Implementation Pattern**:

```nix
# State-checking wrapper for macOS defaults
mkIdempotentDefault = domain: key: value: ''
  current=$(defaults read ${domain} ${key} 2>/dev/null || echo "__unset__")
  if [ "$current" != "${toString value}" ]; then
    defaults write ${domain} ${key} ${toString value}
  fi
'';

# Filesystem idempotency
mkIdempotentDir = { path, owner ? "root", mode ? "755" }: ''
  if [ ! -d "${path}" ]; then
    mkdir -p "${path}"
    chmod ${mode} "${path}"
    chown ${owner} "${path}"
  fi
'';

# DRY_RUN support pattern (from home-manager)
mkSafeCommand = cmd: ''
  if [ -n "''${DRY_RUN:-}" ]; then
    echo "would run: ${cmd}"
  else
    ${cmd}
  fi
'';

# Error handling with status tracking
mkRobustScript = content: ''
  set -euo pipefail
  _status=0
  trap "_status=1" ERR
  
  ${content}
  
  if (( _status > 0 )); then
    echo "Script failed" >&2
    exit 1
  fi
'';
```

**Critical Elements**:

- Check current state before modification (`defaults read`, `systemctl is-enabled`, file existence)
- Use `|| echo "__unset__"` pattern for handling missing values
- Implement early exit on errors with `set -e`
- Support verbose mode for debugging
- Use conditional execution (`if` checks) not `|| true` which masks real errors

______________________________________________________________________

### 3. Platform Abstraction

**Decision**: Use separate module directories for platform-specific code (darwin/, linux/, nixos/, kali/) with conditional imports at module level, combined with shared cross-platform utilities.

**Rationale**:

- Physical directory separation provides clear organizational boundaries
- Conditional imports at module level avoid infinite recursion issues
- Shared utilities can be pure functions without platform checks
- Platform-specific code is isolated and independently testable
- Pattern follows nixpkgs and nix-darwin conventions

**Alternatives considered**:

- **Runtime conditionals everywhere**: Creates option definition errors on unsupported platforms, complex to maintain
- **Duplicate code per platform**: Violates DRY principle, increases maintenance burden significantly
- **Complex abstraction layers**: Adds cognitive overhead without proportional benefit, harder to understand

**Implementation Pattern**:

```nix
# Directory structure approach (chosen)
modules/
├── shared/lib/        # Pure cross-platform utilities
│   └── shell.nix      # mkRunAsUser, mkIdempotentFile, etc.
├── linux/lib/         # Linux system type libraries
│   └── systemd.nix    # mkSystemdEnable, mkSystemdStart, etc.
├── darwin/lib/        # macOS-specific
│   └── mac.nix        # mkDockClear, mkNvramSet, etc.
└── nixos/lib/         # NixOS-specific (imports systemd.nix)
    └── nixos.nix      # mkNixosRebuild, etc.

# Import pattern in darwin module
{ config, lib, pkgs, ... }:
let
  macLib = import ../lib/mac.nix { inherit lib pkgs config; };
  sharedLib = import ../../shared/lib { inherit lib pkgs; };
in {
  # Use platform-specific and shared libraries
  system.activationScripts.dock = {
    text = ''
      ${macLib.mkDockClear}
      ${macLib.mkDockAddApp { app = "/Applications/Safari.app"; }}
      ${macLib.mkDockRestart}
    '';
  };
}

# Import pattern in nixos module
{ config, lib, pkgs, ... }:
let
  nixosLib = import ../lib/nixos.nix { inherit lib pkgs config; };
  systemdLib = import ../../linux/lib/systemd.nix { inherit lib pkgs; };
in {
  # NixOS library imports systemd library automatically
  system.activationScripts.services = {
    text = ''
      ${nixosLib.mkSystemdReload}
      ${nixosLib.mkSystemdEnable "firewalld"}
    '';
  };
}
```

**Organization Principles**:

1. **Physical separation**: Platform code in separate directories
1. **Import-based composition**: Platforms import shared and generic libraries
1. **No platform checks in shared code**: Shared libraries are completely platform-agnostic
1. **Unidirectional dependencies**: module scripts → platform libs → linux libs → shared libs

**Anti-patterns to Avoid**:

- Using `pkgs.stdenv.isDarwin` checks in shared libraries (violates platform-agnostic principle)
- Conditionally importing files with `lib.optionals` on option existence (causes infinite recursion)
- Mixing platform-specific code in shared utilities

______________________________________________________________________

### 4. Library Organization

**Decision**: Use hierarchical structure with `lib/default.nix` as public API entry point, domain-specific submodules (shell.nix, systemd.nix, mac.nix), and clear documentation for each function.

**Rationale**:

- Mirrors nixpkgs `lib/` structure familiar to Nix community
- Single import point simplifies consumption
- Domain separation (shell utilities, platform operations) improves maintainability
- Clear public API enables refactoring internals without breaking consumers
- Follows established conventions from nix-darwin and home-manager

**Alternatives considered**:

- **Flat file structure**: Doesn't scale beyond ~5 helpers, becomes difficult to navigate
- **Deep nesting by category**: Creates long import paths and unclear boundaries between categories
- **Single monolithic lib.nix**: Becomes unmaintainable above ~500 lines, difficult to review changes

**Implementation Pattern**:

```nix
# modules/shared/lib/default.nix (public API entry point)
{ lib, pkgs }:
let
  shell = import ./shell.nix { inherit lib pkgs; };
in {
  # Export shell utilities
  inherit shell;
  
  # Convenience re-exports for commonly used functions
  inherit (shell) mkRunAsUser mkIdempotentFile mkIdempotentDir;
  inherit (shell) mkLoggedCommand mkConditional mkKillProcess;
}

# modules/shared/lib/shell.nix (domain-specific module)
{ lib, pkgs }:
{
  # Pure cross-platform shell script generators
  
  /* Run command as specific user
   * Type: mkRunAsUser :: String -> String -> String
   * Example: mkRunAsUser "charles" "dockutil --add Safari.app"
   */
  mkRunAsUser = user: cmd: ''
    sudo -u ${user} ${cmd}
  '';

  /* Create file idempotently (only if missing or content differs)
   * Type: mkIdempotentFile :: AttrSet -> String
   * Example: mkIdempotentFile { path = "/etc/config"; content = "data"; mode = "644"; }
   */
  mkIdempotentFile = { path, content, mode ? "644" }: ''
    if [ ! -f "${path}" ] || ! grep -qF "${content}" "${path}"; then
      echo "${content}" > "${path}"
      chmod ${mode} "${path}"
    fi
  '';
  
  # ... other functions with similar documentation
}

# modules/darwin/lib/mac.nix (platform-specific library)
{ lib, pkgs, config }:
let
  sharedLib = import ../../shared/lib { inherit lib pkgs; };
  inherit (sharedLib.shell) mkRunAsUser mkLoggedCommand;
  
  user = config.system.primaryUser;
  asUser = cmd: mkRunAsUser user cmd;
in {
  # macOS-specific activation functions
  
  /* Clear all Dock items
   * Type: mkDockClear :: String
   * Returns: Shell script text that removes all Dock items
   */
  mkDockClear = asUser "${pkgs.dockutil}/bin/dockutil --remove all --no-restart";
  
  /* Add application to Dock
   * Type: mkDockAddApp :: AttrSet -> String
   * Example: mkDockAddApp { app = "/Applications/Safari.app"; position = "1"; }
   */
  mkDockAddApp = { app, position ? "end" }:
    asUser "${pkgs.dockutil}/bin/dockutil --add '${app}' --position ${position} --no-restart";
  
  # ... more platform-specific functions
}
```

**Organization Structure**:

```
modules/
├── shared/lib/              # Cross-platform utilities
│   ├── default.nix          # Public API, aggregates and re-exports
│   └── shell.nix            # Shell script generators
│
├── linux/lib/               # Linux system type libraries
│   ├── systemd.nix          # Systemd-based distributions
│   └── scripts/             # Complex scripts >50 lines
│
├── darwin/lib/              # macOS-specific
│   ├── mac.nix              # High-level macOS functions
│   └── scripts/             # Complex scripts >50 lines
│
└── nixos/lib/               # NixOS-specific
    ├── nixos.nix            # NixOS functions (imports systemd.nix)
    └── scripts/
```

**Documentation Conventions**:

- Every public function has:
  - Type signature (Haskell-style notation)
  - Purpose description
  - Parameter documentation
  - Usage example
  - Return value description
- Use JSDoc-style comments for consistency
- Include examples in `:::{.example}` blocks for nixos manual integration

**Naming Conventions**:

- `mk*` prefix for generator functions (mkRunAsUser, mkDockClear)
- `is*`/`has*` for predicate functions
- Domain prefixes for specificity (mkSystemd\*, mkDock\*, mkNvram\*)
- Descriptive names that convey purpose (mkIdempotentFile not mkFile)

______________________________________________________________________

## Technology Stack Summary

**Primary Technologies**:

- **Nix 2.19+**: Function definition and string generation
- **Bash 5.x**: Generated shell scripts (POSIX-compatible subset)
- **nix-darwin**: macOS system configuration framework
- **nixpkgs lib**: Utility functions (mapAttrs, concatStrings, escapeShell, etc.)

**Platform-Specific Tools**:

- **macOS**: defaults, nvram, pmset, socketfilterfw, dockutil, launchctl
- **Linux**: systemctl, firewall-cmd, ufw, useradd, groupadd

**Development Tools**:

- **alejandra**: Nix code formatter
- **shellcheck**: Shell script linter (for validation)
- **nix flake check**: Syntax and build validation

______________________________________________________________________

## Implementation Strategy

### Phase 1: Shared Library Foundation

1. Create `modules/shared/lib/` structure
1. Implement 6 core shell generators: mkRunAsUser, mkIdempotentFile, mkIdempotentDir, mkLoggedCommand, mkConditional, mkKillProcess
1. Add comprehensive function documentation
1. Test with simple activation scripts on both darwin and linux

### Phase 2: Linux System Type Library

1. Create `modules/linux/lib/systemd.nix`
1. Implement systemd functions: mkSystemdEnable, mkSystemdStart, mkSystemdRestart, mkSystemdStop
1. Add firewall functions: mkFirewalldEnable, mkUfwEnable
1. Add user management functions: mkUserAdd, mkGroupAdd
1. Import and use shared library functions

### Phase 3: Darwin Platform Library

1. Create `modules/darwin/lib/mac.nix`
1. Implement Dock management: mkDockClear, mkDockAddApp, mkDockAddFolder, mkDockRestart
1. Implement NVRAM functions: mkNvramSet, mkNvramGet
1. Implement power management: mkPmsetSet
1. Implement firewall: mkFirewallEnable, mkFirewallSetStealthMode
1. Implement LaunchAgent: mkLoadLaunchAgent, mkLoadLaunchDaemon
1. Import and use shared library functions

### Phase 4: NixOS Platform Library

1. Create `modules/nixos/lib/nixos.nix`
1. Import `modules/linux/lib/systemd.nix`
1. Re-export all systemd functions
1. Add NixOS-specific extensions: mkNixosRebuild, mkNixosCleanGenerations
1. Ensure no duplication with systemd library

### Phase 5: Refactoring and Validation

1. Refactor 3 existing activation scripts to use new libraries
1. Verify idempotency (run activation twice, check for errors)
1. Document library usage patterns in docs/guides/
1. Update constitution if needed (already done)

______________________________________________________________________

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing activation scripts | High | Incremental rollout, comprehensive testing, keep old patterns working during transition |
| Platform-specific code leaking into shared libraries | Medium | Strict review process, automated checks for pkgs.stdenv references in shared/ |
| Library functions generate incorrect shell code | High | Manual testing on target platforms, shellcheck validation, example-driven development |
| Poor documentation leads to misuse | Medium | Document every function with type signature and examples, create comprehensive guide |
| Performance degradation from function composition | Low | Nix evaluation is fast, generated scripts are similar complexity to hand-written |

______________________________________________________________________

## Open Questions

**Q1**: Should we create a testing framework for validating generated shell scripts?
**A1**: Phase 1 implementation should include manual testing procedures. Automated testing can be added later if needed. Focus on example-driven development and manual validation.

**Q2**: How to handle platform-specific functions that have similar purpose but different implementations?
**A2**: Keep implementations completely separate in platform libraries. Don't try to abstract when behavior diverges significantly. Clear separation is better than complex abstraction.

**Q3**: Should module-specific scripts (lib/scripts/) be bash files or Nix functions that generate bash?
**A3**: Prefer Nix functions for consistency and composability. Only use raw bash files for scripts >200 lines or when external tools need direct bash access.

**Q4**: How to version library functions if we need to make breaking changes?
**A4**: Libraries version with repository (no separate versioning). Breaking changes require updating all call sites in same commit. Use deprecation warnings for gradual migrations.

______________________________________________________________________

## Next Steps

1. **Phase 1 Design**: Create data-model.md defining library function signatures and relationships
1. **Phase 1 Design**: Create quickstart.md with testing and validation procedures
1. **Phase 2 Implementation**: Generate tasks.md with detailed implementation tasks using `/speckit.tasks`
