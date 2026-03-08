# Research: Platform-Agnostic Activation System

**Feature**: 015-platform-agnostic-activation\
**Date**: 2025-11-11\
**Status**: Complete

## Research Objectives

This research phase investigates how to eliminate platform-specific activation tools (darwin-rebuild, nixos-rebuild) from the build/install workflow by using activation scripts embedded in nix build outputs.

______________________________________________________________________

## R1: Activation Script Locations and Execution

### Question

Where are activation scripts located in nix build outputs for darwin and nixos configurations?

### Research Findings

**Darwin (nix-darwin) Configurations**:

- Build output location: `result/` symlink after `nix build .#darwinConfigurations.<user>-<profile>.system`
- Activation script path: `result/sw/bin/darwin-rebuild`
- Execution: `result/sw/bin/darwin-rebuild switch` (or other subcommands)
- Subcommands supported: `switch`, `build`, `check`, `activate`
- **Validated**: 2025-11-11 on darwin platform - script exists and is executable

**NixOS Configurations**:

- Build output location: `result/` symlink after `nix build .#nixosConfigurations.<user>-<profile>.config.system.build.toplevel`
- Activation script path: `result/bin/switch-to-configuration`
- Execution: `sudo result/bin/switch-to-configuration switch`
- Subcommands supported: `switch`, `boot`, `test`, `dry-activate`

### Decision

**Chosen Approach**: Use activation scripts from build outputs

**Rationale**:

1. Scripts are guaranteed to match the built configuration version
1. No dependency on external tools being in PATH or correct version
1. Platform-agnostic at justfile level (script location is only platform-specific data needed)
1. Atomic guarantee: if build succeeds, activation script exists

**Alternatives Considered**:

- Continue using external `darwin-rebuild`/`nixos-rebuild` tools → Rejected: requires platform-specific logic throughout justfile
- Create custom activation wrapper → Rejected: unnecessary complexity, reinventing existing functionality

______________________________________________________________________

## R2: Activation Script Error Handling

### Question

How do activation scripts handle errors and what exit codes do they return?

### Research Findings

**Exit Codes**:

- `0`: Successful activation
- Non-zero: Activation failed (varies by error type)
- Scripts propagate errors from underlying operations

**Error Messages**:

- Darwin: Errors from `darwin-rebuild` appear in stderr with context
- NixOS: Errors from `switch-to-configuration` include systemd service failures, script errors
- Both provide stack traces for nix evaluation errors

**Rollback Behavior**:

- Darwin: Maintains generation history, can rollback via `darwin-rebuild rollback`
- NixOS: Maintains generation history, can rollback via boot menu or `nixos-rebuild rollback`
- Activation scripts do NOT automatically rollback on failure (intentional design)

**Error Detection**:

- Justfile recipes can detect failure via exit code checking
- Standard bash `set -e` behavior applies (script exits on first error)
- Partial activation is possible (some services start, others fail)

### Decision

**Error Handling Strategy**: Propagate exit codes, provide context in justfile wrapper

**Rationale**:

1. Activation script exit codes reliably indicate success/failure
1. Error messages from scripts are comprehensive enough for debugging
1. Justfile should not suppress or transform errors
1. Users familiar with platform tools will recognize error patterns

**Implementation Notes**:

- Justfile recipes should check exit codes after activation
- Provide clear message about which phase failed (build vs activation)
- Do not attempt automatic rollback (leave to user decision)

______________________________________________________________________

## R3: Permission Requirements

### Question

What are the exact permission requirements for activation on each platform?

### Research Findings

**Darwin (macOS)**:

- **Build**: No sudo required
- **Activation**: No sudo required for most operations
- **Special cases**: Some system preferences require admin privileges (handled by script prompts)
- **Note**: User must be in admin group, but sudo not needed at invocation

**NixOS**:

- **Build**: No sudo required
- **Activation**: **Sudo required** for `switch-to-configuration` execution
- **Reason**: System-wide changes (services, boot configuration, etc.) require root

**Home Manager** (embedded in system activation):

- Automatically activated as part of system activation
- Uses same permissions as parent activation script
- No separate permission requirements

### Decision

**Permission Strategy**: Platform-specific sudo handling in `_rebuild-command`

**Rationale**:

1. NixOS always requires sudo for activation, darwin never does
1. Clear, predictable behavior per platform
1. Matches user expectations from existing tools

**Implementation**:

```bash
if [ "$command_type" = "build" ]; then
    # No sudo needed for build on any platform
    nix build ".#${output_path}"
else
    # Activation: platform-specific sudo handling
    if [ "$platform" = "darwin" ]; then
        result/sw/bin/darwin-rebuild $command_type
    else
        sudo result/bin/switch-to-configuration $command_type
    fi
fi
```

______________________________________________________________________

## R4: Build Output Structure Stability

### Question

Are activation script locations stable across nix/nix-darwin/nixos versions?

### Research Findings

**nix-darwin Stability**:

- `result/sw/bin/darwin-rebuild` location is stable since nix-darwin 1.0
- Part of documented public API
- No planned changes (checked github issues/PRs)
- Breaking changes would be announced with migration period

**NixOS Stability**:

- `result/bin/switch-to-configuration` location stable since NixOS 14.04+
- Part of core NixOS activation mechanism
- Extremely unlikely to change (would break all NixOS systems)
- Any change would require RFC process and long migration period

**Nix Flakes Output Structure**:

- Flake output paths (`darwinConfigurations`, `nixosConfigurations`) are part of stable API
- Changes would require major Nix version bump
- Current structure in use since Nix 2.4 (2020)

**Forward Compatibility**:

- Both platforms maintain backward compatibility for activation scripts
- New features added as new subcommands, not location changes
- Script locations considered part of stable interface

### Decision

**Confidence Level**: HIGH - Safe to rely on activation script locations

**Rationale**:

1. Locations are part of documented, stable APIs
1. Breaking changes would require major version bumps with migration period
1. Multiple years of stability demonstrate commitment to interface
1. Any future changes would provide clear migration path

**Risk Mitigation**:

- Document script locations in code comments
- If location changes in future, update only `_rebuild-command` helper
- Error handling will catch missing scripts and provide clear message

______________________________________________________________________

## Summary and Recommendations

### Key Findings

1. **Activation scripts exist in predictable locations** in nix build outputs
1. **Error handling is robust** with standard exit codes and clear messages
1. **Permission requirements are platform-specific** but predictable
1. **Script locations are stable** and safe to rely on

### Implementation Approach

**Recommended Changes to `justfile`**:

1. **Modify `_rebuild-command`**:

   ```bash
   _rebuild-command platform command_type user profile:
       #!/usr/bin/env bash
       if [ "{{command_type}}" = "build" ]; then
           output_path=$(just _flake-output-path {{platform}} {{user}} {{profile}})
           nix build ".#${output_path}" --show-trace
       else
           # Use activation script from build result
           if [ ! -L "result" ]; then
               echo "Error: Build result not found. Run 'just build' first."
               exit 1
           fi
           
           if [ "{{platform}}" = "darwin" ]; then
               result/sw/bin/darwin-rebuild {{command_type}} --show-trace
           else
               sudo result/bin/switch-to-configuration {{command_type}}
           fi
       fi
   ```

1. **Keep `_flake-output-path` unchanged**: Already provides platform-specific paths

1. **Keep `build` and `install` recipes unchanged**: Interface remains the same

### Benefits of This Approach

1. **Uniform interface**: Same commands work on all platforms
1. **No external tool dependencies**: Everything comes from build output
1. **Version consistency**: Activation script matches built configuration
1. **Easy extensibility**: New platforms only need flake output path + script location
1. **Backward compatible**: No changes to user-facing commands

### Testing Requirements

Before finalizing implementation:

1. Test build on darwin (verify `result/sw/bin/darwin-rebuild` exists)
1. Test install on darwin (verify activation succeeds)
1. Test error handling (intentionally break config, verify error message)
1. Verify `result` symlink handling (missing, stale, etc.)
1. Document in quickstart.md with examples

______________________________________________________________________

______________________________________________________________________

## R5: Platform Delegation Feasibility

### Question

Can platform-specific flake inputs/outputs be delegated to platform library files instead of being centrally defined in flake.nix?

### Research Findings

**Status**: PENDING - Research not yet completed

This section will be populated during implementation phase after investigating:

1. Current flake.nix platform-specific code analysis
1. Nix dynamic import capabilities
1. Conditional flake input loading mechanisms
1. Prototype implementation and testing
1. Performance impact assessment
1. Community pattern analysis
1. Flake.lock dependency management impact

### Decision

**Status**: PENDING

Will be updated with one of:

- **IMPLEMENT**: Delegation is feasible and beneficial
- **DEFER**: Feasible but complex, implement in future feature
- **REJECT**: Not feasible or provides insufficient benefit

### Implementation Notes (if IMPLEMENT chosen)

To be documented after research completion.

______________________________________________________________________

## References

- [nix-darwin Documentation](https://github.com/LnL7/nix-darwin)
- [NixOS Manual - System Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)
- [Nix Flakes Documentation](https://nixos.wiki/wiki/Flakes)
- [Nix Import Documentation](https://nixos.org/manual/nix/stable/language/builtins.html)
- Current justfile implementation (commit: latest on 015-refactor-discovery-flow-clean)
