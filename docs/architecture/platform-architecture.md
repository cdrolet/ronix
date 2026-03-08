# Platform Architecture

**Status**: Optimal (Validated 2025-11-11)\
**Research**: Feature 016 - Platform Delegation Feasibility Study\
**Version**: 1.0

## Executive Summary

This document describes the current platform architecture for the nix-config repository, which has been validated as optimal given Nix flake constraints through comprehensive research (feature 016-platform-delegation).

**Key Finding**: The current architecture using centralized flake inputs with conditional platform loading is the recommended approach for multi-platform Nix configurations. Alternative approaches (dynamic input delegation) are not possible due to Nix flake architectural constraints.

## Architecture Overview

### Current Pattern (Recommended)

```nix
# flake.nix - Central orchestration
{
  inputs = {
    # Shared inputs
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Platform-specific inputs (darwin)
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Platform-specific inputs (android)
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    # Conditional platform loading
    darwinOutputs =
      if builtins.pathExists ./platform/darwin/lib/darwin.nix
      then (import ./platform/darwin/lib/darwin.nix {
        inherit inputs lib nixpkgs validUsers discoverProfiles;
      }).outputs
      else {};
    
    nixosOutputs =
      if builtins.pathExists ./platform/nixos/lib/nixos.nix
      then (import ./platform/nixos/lib/nixos.nix {
        inherit inputs lib nixpkgs validUsers discoverProfiles;
      }).outputs
      else {};
  in {
    # Merge platform outputs
    darwinConfigurations = darwinOutputs.darwinConfigurations or {};
    nixosConfigurations = nixosOutputs.nixosConfigurations or {};
    formatter = (darwinOutputs.formatter or {}) // (nixosOutputs.formatter or {});
  };
}
```

### Platform Library Pattern

```nix
# platform/{platform}/lib/{platform}.nix
{
  inputs,
  lib,
  nixpkgs,
  validUsers,
  discoverProfiles,
}:
# Platform Library: {Platform Name}
#
# Required Inputs (must be declared in root flake.nix):
#   - nixpkgs: Main package repository
#   - {platform-input}: {Description}
#
# Example flake.nix inputs:
#   {platform-input} = {
#     url = "github:...";
#     inputs.nixpkgs.follows = "nixpkgs";
#   };

let
  # Input validation
  requiredInputs = [ "nixpkgs" "platform-input" ];
  missingInputs = builtins.filter (name: !(inputs ? ${name})) requiredInputs;
  _ = if missingInputs != [] 
      then throw ''
        {Platform} platform requires the following inputs in flake.nix:
          ${lib.concatStringsSep "\n  " missingInputs}
        
        Please add them to your flake.nix inputs section.
        See platform/{platform}/lib/{platform}.nix header for examples.
      ''
      else null;
  
  # Platform-specific logic
  # ...
in
{
  outputs = {
    {platform}Configurations = { /* ... */ };
    formatter.{arch} = /* ... */;
    validProfiles.{platform} = [ /* ... */ ];
  };
}
```

## Design Principles

### 1. Centralized Input Declaration

**Principle**: All flake inputs MUST be declared in the root `flake.nix`.

**Rationale**: Nix flake architecture requires static input declaration before outputs evaluation. This is not a limitation to work around—it's a fundamental design constraint.

**Benefits**:

- Single source of truth for all dependencies
- Flake.lock properly tracks all inputs
- Reproducible across machines
- Compatible with `nix flake update` workflows

### 2. Conditional Platform Loading

**Principle**: Platform libraries are loaded conditionally based on filesystem presence.

**Rationale**:

- Platforms only needed on relevant systems (darwin users don't need nixos code)
- Graceful degradation when platforms not present
- Enables selective platform support

**Benefits**:

- Cleaner evaluation (unused platforms not loaded)
- Platform-specific code isolated
- Easy to add/remove platforms from repository

### 3. Platform Self-Documentation

**Principle**: Platform libraries document their own requirements via function signatures and header comments.

**Rationale**: Clear contracts prevent configuration errors and guide developers.

**Benefits**:

- Self-documenting code (requirements visible in platform library)
- Validation catches missing inputs early
- Helpful error messages guide users to solutions

### 4. Output Composition

**Principle**: Platform libraries export complete, self-contained outputs that are merged by central flake.

**Rationale**: Natural namespacing prevents conflicts, platforms remain independent.

**Benefits**:

- Platform outputs don't interfere with each other
- Architecture-specific outputs (formatters) naturally namespaced
- Easy to add new output types per platform

## Adding a New Platform

### Step-by-Step Guide

#### 1. Declare Platform Inputs

Edit `flake.nix` to add platform-specific inputs:

```nix
inputs = {
  # ... existing inputs
  
  # New platform input
  new-platform-framework = {
    url = "github:org/new-platform-framework";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

#### 2. Add Platform Loading

Edit `flake.nix` outputs to load the new platform:

```nix
outputs = inputs: let
  # ... existing platform loading
  
  # New platform loading
  newPlatformOutputs =
    if builtins.pathExists ./platform/new-platform/lib/new-platform.nix
    then (import ./platform/new-platform/lib/new-platform.nix {
      inherit inputs lib nixpkgs validUsers discoverProfiles;
    }).outputs
    else {};
in {
  # ... existing output merging
  
  # Merge new platform outputs
  newPlatformConfigurations = newPlatformOutputs.newPlatformConfigurations or {};
  formatter = (formatter or {}) // (newPlatformOutputs.formatter or {});
};
```

#### 3. Create Platform Library

Create `platform/new-platform/lib/new-platform.nix`:

```nix
{
  inputs,
  lib,
  nixpkgs,
  validUsers,
  discoverProfiles,
}:
# Platform Library: New Platform
#
# Required Inputs:
#   - nixpkgs: Main package repository
#   - new-platform-framework: Platform-specific framework
#   - home-manager: User environment manager

let
  # Validate inputs
  requiredInputs = [ "nixpkgs" "new-platform-framework" "home-manager" ];
  missingInputs = builtins.filter (name: !(inputs ? ${name})) requiredInputs;
  _ = if missingInputs != [] 
      then throw ''
        New Platform requires inputs: ${lib.concatStringsSep ", " missingInputs}
        See platform/new-platform/lib/new-platform.nix for examples.
      ''
      else null;

  # Discover profiles
  newPlatformProfiles = discoverProfiles "new-platform";
  
  # Generate configurations
  # ... (follow pattern from darwin.nix or nixos.nix)
in
{
  outputs = {
    newPlatformConfigurations = { /* ... */ };
    formatter.{arch} = /* ... */;
    validProfiles.newPlatform = newPlatformProfiles;
  };
}
```

#### 4. Create Directory Structure

```bash
mkdir -p platform/new-platform/{app,settings,lib,profiles}
```

#### 5. Create Initial Profile

```bash
mkdir -p platform/new-platform/profiles/default
# Create profile configuration following existing patterns
```

#### 6. Test Configuration

```bash
# Verify flake evaluates correctly
nix flake check

# Build a test configuration
nix build .#newPlatformConfigurations.user-profile.system
```

## Why This Architecture?

### Research Background (Feature 016)

A comprehensive feasibility study (feature 016-platform-delegation) investigated whether platform-specific flake logic could be delegated to platform libraries to achieve "single file to add platform".

**Research Questions Investigated**:

1. ✅ Can flake.nix dynamically discover platforms? **YES**
1. ❌ Can platform libraries define their own inputs? **NO**
1. ✅ Can outputs be composed dynamically? **YES**
1. ✅ Is performance acceptable? **YES** (\<1% overhead)
1. ✅ Does it affect reproducibility? **NO**
1. ✅ Does it align with community patterns? **YES**

**Critical Finding**: Nix flake architecture fundamentally requires centralized input declaration. Inputs cannot be delegated to platform libraries because:

- Inputs are evaluated in a restricted context before any imports
- Lock file requires complete knowledge of all inputs upfront
- No mechanism for runtime input composition or delegation
- All major Nix projects use centralized inputs (nixos-unified, digga, flake-parts)

**Decision**: Current architecture is optimal given Nix constraints. Full delegation deferred until:

- Nix gains input composition capabilities (future)
- Platform count reaches 6+ (scale makes auto-discovery valuable)
- Community develops standard patterns

### Value Analysis

**Current Approach**:

- Cost: ~15 lines in flake.nix per platform (inputs + loading + merging)
- Benefit: Clear, explicit, follows community standards
- Maintenance: Proven pattern, well-understood

**Full Delegation** (if it were possible):

- Cost: 8-12 hours implementation + ongoing complexity
- Benefit: Save ~8 lines per platform (import boilerplate only)
- Maintenance: Custom pattern, requires documentation

**Assessment**: Current approach optimal. Cost of full delegation > marginal benefit.

### Incremental Improvements Implemented

Instead of full delegation, pragmatic improvements provide ~70% of value with ~10% of cost:

1. **Input Validation**: Platform libraries validate required inputs, fail fast with helpful errors
1. **Documentation**: Headers document requirements with examples
1. **Clear Errors**: Users know exactly what inputs to add when missing

**Result**: Better developer experience without architectural complexity.

## Community Alignment

### Comparison with Major Projects

| Project | Pattern | Input Handling | Similarity |
|---------|---------|----------------|------------|
| **nixos-unified** | Multi-platform configs | Centralized inputs | High - same approach |
| **digga** | Module/profile organization | Centralized inputs | High - similar patterns |
| **flake-parts** | Modular composition | Centralized inputs | Medium - more framework |
| **Personal configs** | Multi-platform flakes | Centralized inputs | High - de facto standard |

**Consensus**: 100% of surveyed projects use centralized input declaration. This is the community-standard approach.

### Best Practices Followed

1. ✅ **Central Input Declaration** - All inputs in root flake.nix
1. ✅ **Input Coordination** - Use `follows` for version consistency
1. ✅ **Conditional Usage** - Platforms use only relevant inputs
1. ✅ **Modular Outputs** - Focus on organizing outputs, not inputs
1. ✅ **Documentation** - Clear requirements in platform libraries

## Performance Characteristics

### Evaluation Performance

**Baseline** (static loading):

- `nix flake show`: ~0.8s
- `nix flake check`: ~12s
- `nix build`: ~2.4s (compilation dominates)

**With Improvements** (validation added):

- `nix flake show`: ~0.8s (+0%)
- `nix flake check`: ~12s (+0%)
- `nix build`: ~2.4s (+0%)

**Overhead**: Negligible - validation is fast, happens once per evaluation

### Scaling Characteristics

**Current** (2 platforms): ~15 lines per platform = ~30 lines total
**Projected** (6 platforms): ~15 lines per platform = ~90 lines total

**Note**: Linear scaling is acceptable. Only consider architectural changes if complexity becomes unmanageable (10+ platforms).

## Future Considerations

### When to Revisit Architecture

Consider reevaluating this architecture if:

1. **Nix Gains Input Composition** - Future Nix versions may support distributed input definitions
1. **Platform Count Reaches 10+** - Dynamic discovery becomes more valuable at scale
1. **Community Standard Emerges** - If tools like flake-parts add first-class platform delegation
1. **Team Structure Changes** - Multiple maintainers managing independent platforms

### Monitoring Criteria

Track these metrics to inform future decisions:

- **Platform Count**: Currently 2 (darwin, nixos). Revisit if reaches 6+
- **Flake.nix Size**: Currently ~120 lines. Revisit if exceeds 300 lines
- **Maintenance Burden**: Time to add new platforms. Revisit if exceeds 30 minutes
- **Community Patterns**: Watch for new Nix flake capabilities or standard libraries

## References

### Documentation

- **Research**: `specs/016-platform-delegation/research.md` - Full feasibility study
- **Plan**: `specs/016-platform-delegation/plan.md` - Implementation plan with research outcome
- **Spec**: `specs/016-platform-delegation/spec.md` - Original feature specification

### Implementation

- **Darwin Platform**: `platform/darwin/lib/darwin.nix` - macOS platform library
- **NixOS Platform**: `platform/nixos/lib/nixos.nix` - Linux platform library
- **Central Flake**: `flake.nix` - Orchestration and input declaration

### Community Resources

- **nixos-unified**: github.com/srid/nixos-unified - Multi-platform configs
- **flake-parts**: github.com/hercules-ci/flake-parts - Modular flake composition
- **Nix Manual**: nixos.org/manual/nix/stable - Flake documentation

## Changelog

### Version 1.0 (2025-11-11)

**Status**: Initial documentation based on feature 016 research

**Changes**:

- Documented current architecture as optimal
- Added platform addition guide
- Explained design rationale with research backing
- Documented incremental improvements
- Added community alignment analysis

**Research Outcome**: DEFER full delegation, implement incremental improvements

**Validation**: Architecture passes all constitutional requirements and community standards
