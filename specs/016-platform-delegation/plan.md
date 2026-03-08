# Implementation Plan: Platform Logic Delegation

**Branch**: `016-platform-delegation` | **Date**: 2025-11-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/016-platform-delegation/spec.md`

**Note**: This is a research-focused feature. Implementation (US2) only proceeds if research (US1) recommends IMPLEMENT based on decision criteria.

**RESEARCH OUTCOME**: ⏭️ **DEFER** - See research.md for full analysis

## Summary

This feature researched the feasibility of delegating platform-specific flake logic (inputs, outputs, configuration generation) to platform library files instead of defining them in the central flake.nix.

**Research Findings** (Phase 0 Complete):

- ✅ Dynamic discovery: Fully viable
- ❌ Input delegation: Not possible (Nix flake limitation)
- ✅ Output composition: Already working
- ✅ Performance: \<1% overhead
- ✅ Reproducibility: Maintained

**Decision**: DEFER implementation based on decision criteria analysis:

- **Feasibility**: Partial (40% reduction vs 80% target) - inputs cannot be delegated
- **Performance**: ✅ Met (\<1% vs \<5% target)
- **Maintainability**: Mixed - outputs easier, inputs still centralized
- **Community Alignment**: ✅ Met

**Recommendation**: Current architecture (feature 015) is already optimal given Nix flake constraints. Defer full delegation until Nix gains input composition capabilities or platform count reaches 6+.

**Value Analysis**: Implementation would save ~8 lines per platform (import boilerplate) but requires 8-12 hours work and adds complexity. Cost > Benefit for current 2-platform setup.

**Next Steps**: Document decision, close feature branch, consider incremental improvements (validation, documentation) instead.

## Technical Context

**Language/Version**: Nix 2.19+ (flakes enabled)
**Primary Dependencies**:

- nixpkgs (unstable channel)
- nix-darwin (for macOS platform)
- home-manager (user environment management)
- Nix flake system with input/output composition

**Storage**: File system (Nix expressions in .nix files, directory scanning)
**Testing**: Manual validation - build and activate configurations, measure performance
**Target Platform**: macOS (darwin) and Linux (nixos) system configurations
**Project Type**: Configuration management (declarative Nix configuration files)
**Performance Goals**:

- Configuration evaluation within 5% of current baseline
- Build times unchanged from current implementation
- Flake evaluation overhead \<100ms additional

**Constraints**:

- Must maintain backward compatibility (existing configurations unchanged)
- Flake outputs structure must remain consistent
- Platform-specific code must not load for unused platforms
- Discovery mechanism must work with Nix's pure evaluation model

**Scale/Scope**:

- Current: 2 platforms (darwin, nixos)
- Future: Potentially 4-6 platforms (darwin, nixos, nix-on-droid, freebsd, etc.)
- 3 users, multiple profiles per platform
- 40-50 app modules across platforms

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Declarative Configuration First

**Status**: ✅ COMPLIANT

- All platform delegation logic will be declarative Nix expressions
- No imperative steps, fully reproducible from files

### Principle II: Modularity and Reusability

**Status**: ✅ COMPLIANT

- Platform libraries will be self-contained modules
- Each platform library has single purpose (define platform-specific flake logic)
- Dependencies explicitly declared (inputs defined per platform)
- **App-Centric Organization**: No changes to existing app modules (\<200 lines)
- **Directory Structure**: Uses existing `platform/{platform}/lib/` structure

### Principle III: Documentation-Driven Development

**Status**: ✅ COMPLIANT

- Research document will include purpose, examples, decision rationale
- If implemented, platform library interface will be fully documented
- Quickstart guide will explain how to add new platforms

### Principle IV: Purity and Reproducibility

**Status**: ⚠️ REVIEW REQUIRED

- Dynamic discovery must work within Nix's pure evaluation model
- **Research Required**: Verify `builtins.readDir` and dynamic imports don't break purity
- **Research Required**: Confirm flake.lock properly pins dynamically loaded inputs
- If purity cannot be maintained → REJECT recommendation

### Principle V: Security Best Practices

**Status**: ✅ COMPLIANT (N/A)

- No security implications, configuration management only
- No new secrets, authentication, or sensitive data handling

### Principle VI: Cross-Platform Compatibility

**Status**: ✅ ENHANCES

- **Platform-Agnostic Orchestration**: Central flake.nix becomes truly platform-agnostic
- **Self-Contained Platforms**: Each platform fully encapsulated in its library
- **Conditional Loading**: Platform code only loads if platform directory exists
- This feature directly implements constitutional principle VI goals

### Additional Constitutional Requirements

**Module Size (\<200 lines)**: ✅ COMPLIANT

- Platform delegation logic will be in flake.nix (orchestration layer)
- Platform libraries already exist (darwin.nix, nixos.nix) and are compliant
- No new large modules created

**DRY Principle**: ✅ ENHANCES

- Eliminates duplication of platform loading patterns in flake.nix
- Standard delegation interface reduces boilerplate

**Version Control Discipline**: ✅ COMPLIANT

- All changes versioned in git
- Feature branch workflow (016-platform-delegation)
- No secrets in repository

**GATE DECISION**: ✅ PROCEED TO PHASE 0 RESEARCH

- All constitutional principles compliant or enhance existing compliance
- Principle IV requires research validation (purity with dynamic discovery)
- No violations requiring justification

## Project Structure

### Documentation (this feature)

```text
specs/016-platform-delegation/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (research findings and recommendation)
├── data-model.md        # Phase 1 output (platform delegation interface)
├── quickstart.md        # Phase 1 output (how to add new platforms)
├── contracts/           # Phase 1 output (platform library API contract)
│   └── platform-library-api.md
├── checklists/          # Validation checklists
│   └── requirements.md  # Spec quality checklist (complete)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT YET CREATED)
```

### Source Code (repository root)

```text
# Current Structure (feature 015 baseline)
flake.nix                 # Central orchestration, imports platform libs explicitly
platform/
├── darwin/
│   └── lib/
│       └── darwin.nix    # Darwin platform outputs (inputs, configurations, formatter)
├── nixos/
│   └── lib/
│       └── nixos.nix     # NixOS platform outputs (inputs, configurations)
└── shared/
    └── lib/
        └── discovery.nix # Discovery utilities (users, profiles)

# Proposed Structure (if US1 recommends IMPLEMENT)
flake.nix                 # Platform-agnostic orchestration, auto-discovers platforms
platform/
├── darwin/
│   └── lib/
│       ├── darwin.nix          # Current implementation (may become legacy)
│       └── flake-delegate.nix  # New delegation interface (if implemented)
├── nixos/
│   └── lib/
│       ├── nixos.nix           # Current implementation (may become legacy)
│       └── flake-delegate.nix  # New delegation interface (if implemented)
├── {new-platform}/             # Future platforms (e.g., freebsd, nix-on-droid)
│   └── lib/
│       └── flake-delegate.nix  # Only file needed to add platform
└── shared/
    └── lib/
        ├── discovery.nix       # Existing discovery utilities
        └── platform-discovery.nix  # New platform delegation discovery (if implemented)
```

**Structure Decision**:

- **Phase 0 (Research)**: No source changes, research only
- **Phase 1 (Design)**: Define `flake-delegate.nix` interface and discovery mechanism
- **Phase 2 (Implementation, conditional)**:
  - If IMPLEMENT: Create new delegation system, migrate darwin/nixos gradually
  - If DEFER/REJECT: Document findings, keep current structure

## Complexity Tracking

**No Violations**: All constitutional principles are compliant or enhanced by this feature.

**Research Validation Required** (Principle IV - Purity):

- Dynamic discovery with `builtins.readDir` must not break flake purity
- Dynamically loaded inputs must be properly tracked in flake.lock
- If purity cannot be maintained, research will recommend REJECT

______________________________________________________________________

## Phase 0: Research & Discovery

**Purpose**: Determine feasibility of platform delegation and make IMPLEMENT/DEFER/REJECT recommendation.

**Prerequisites**: Constitution Check passed ✅

**Success Criteria**:

- All 6 research questions answered with evidence
- Working code examples demonstrating capabilities or limitations
- Performance benchmarks (dynamic vs static)
- Community pattern analysis (3+ similar projects)
- Clear recommendation with justification

### Research Tasks

#### R1: Dynamic Discovery Capabilities

**Question**: Can flake.nix dynamically discover and load platform modules from filesystem?

**Investigation**:

- Test `builtins.readDir` to list platform directories
- Test dynamic imports: `import ./platform/${name}/lib/flake-delegate.nix`
- Verify discovery works within Nix's pure evaluation model
- Test conditional loading (skip platforms without lib/flake-delegate.nix)

**Prototype**:

```nix
# Test in flake.nix
let
  platformDirs = builtins.attrNames (builtins.readDir ./platform);
  availablePlatforms = lib.filter (name: 
    builtins.pathExists ./platform/${name}/lib/flake-delegate.nix
  ) platformDirs;
  
  loadPlatform = name: import ./platform/${name}/lib/flake-delegate.nix {
    inherit inputs lib nixpkgs validUsers discoverProfiles;
  };
  
  platformOutputs = map loadPlatform availablePlatforms;
in
  # Test that platforms load and export outputs
```

**Success Metric**: Prototype successfully discovers and loads platforms dynamically

#### R2: Flake Input Composition

**Question**: Can platform libraries define their own flake inputs without modifying central flake.nix?

**Investigation**:

- Research Nix flake input override mechanisms
- Test whether platform library can require specific inputs
- Investigate flake-parts, flake-utils patterns for input composition
- Determine if inputs must be centrally defined or can be distributed

**Key Scenarios**:

1. Darwin platform needs `nix-darwin` input
1. NixOS platform needs specific nixpkgs pin
1. New platform needs novel input (e.g., nix-on-droid)

**Research Sources**:

- Nix flake manual (input composition)
- flake-parts documentation
- flake-utils patterns
- nixos-unified architecture

**Success Metric**: Document whether input delegation is possible and how

#### R3: Output Composition Patterns

**Question**: Can platform libraries export complete outputs without central orchestration knowledge?

**Investigation**:

- Verify current pattern: Platform libs already export complete outputs
- Test merging outputs from multiple dynamically loaded platforms
- Ensure no output conflicts (namespacing)
- Validate flake output structure remains consistent

**Current Pattern** (baseline):

```nix
# darwin.nix exports:
{
  outputs = {
    darwinConfigurations = {...};
    formatter.aarch64-darwin = {...};
    validProfiles.darwin = [...];
  };
}

# flake.nix merges:
darwinConfigurations = darwinOutputs.darwinConfigurations or {};
```

**Proposed Pattern**:

```nix
# Each platform library exports same structure
# Flake.nix dynamically merges all platform outputs
```

**Success Metric**: Output merging works without central knowledge of output structure

#### R4: Performance Impact

**Question**: What is the performance impact of dynamic discovery vs static definitions?

**Benchmark Approach**:

1. Measure current flake evaluation time: `time nix flake show`
1. Implement prototype with dynamic discovery
1. Measure prototype evaluation time
1. Calculate overhead percentage
1. Test with 2, 4, 6 mock platforms to assess scaling

**Tools**:

- `time` command for basic measurement
- `nix --print-stats` for detailed analysis
- hyperfine for rigorous benchmarking

**Target**: \<5% performance degradation
**Fallback**: If 5-10%, document tradeoff (may still IMPLEMENT if benefits outweigh)
**Blocker**: If >10%, likely DEFER or REJECT

**Success Metric**: Performance impact documented with concrete measurements

#### R5: Flake.lock Impact

**Question**: How does dynamic discovery affect flake.lock and dependency management?

**Investigation**:

- Create prototype with dynamic platforms
- Run `nix flake lock` and examine lock file
- Verify all platform-specific inputs are tracked
- Test `nix flake update` with dynamic platforms
- Ensure reproducibility across machines (same lock = same build)

**Key Questions**:

- Are dynamically loaded inputs properly pinned?
- Does lock file structure change?
- Can specific platform inputs be updated independently?

**Success Metric**: Flake.lock properly tracks all inputs with dynamic loading

#### R6: Community Pattern Analysis

**Question**: What similar patterns exist in the Nix community?

**Research Targets**:

1. **nixos-unified**: Multi-system configuration patterns
1. **flake-parts**: Modular flake composition
1. **flake-utils**: Flake utility functions
1. **home-manager**: Modular configuration system
1. **nix-darwin**: Platform-specific patterns
1. **devenv**: Environment composition

**Analysis**:

- Document similar delegation/discovery patterns
- Identify best practices and anti-patterns
- Note community recommendations
- Assess alignment with proposed approach

**Success Metric**: Document 3+ similar projects and assess community alignment

### Research Consolidation

**Output**: `research.md` with sections:

1. **Executive Summary**

   - One-paragraph summary of feasibility
   - Clear recommendation: IMPLEMENT / DEFER / REJECT
   - Key decision factors

1. **Capability Analysis** (R1-R3)

   - Dynamic discovery findings with code examples
   - Input composition capabilities and limitations
   - Output composition validation

1. **Performance Analysis** (R4)

   - Benchmark results (table with times)
   - Overhead percentage
   - Scaling assessment

1. **Dependency Management** (R5)

   - Flake.lock behavior analysis
   - Reproducibility validation
   - Any limitations discovered

1. **Community Alignment** (R6)

   - Similar projects table (name, pattern, relevance)
   - Best practices identified
   - Anti-patterns to avoid

1. **Decision Matrix**

   - Each criterion assessed: ✅ Met / ⚠️ Partial / ❌ Not Met
   - Overall recommendation with justification
   - If DEFER: Conditions for future reconsideration
   - If REJECT: Why not feasible, alternatives

1. **Prototype Code**

   - Working examples demonstrating findings
   - Can be tested: `nix eval` or `nix build`

**Estimated Duration**: 4-6 hours of focused research

______________________________________________________________________

## Phase 1: Design & Contracts

**Prerequisites**:

- research.md complete with IMPLEMENT recommendation
- Constitution re-check passed

**Conditional**: Only proceed if Phase 0 recommends IMPLEMENT. If DEFER or REJECT, skip to Phase 2 (document-only completion).

### Design Artifacts

#### D1: Data Model (`data-model.md`)

**Purpose**: Define the platform delegation interface and discovery mechanism.

**Key Entities**:

1. **Platform Library** (`flake-delegate.nix`)

   - **Location**: `platform/{platform}/lib/flake-delegate.nix`
   - **Purpose**: Encapsulates all platform-specific flake logic
   - **Interface**:
     ```nix
     # Function signature
     { inputs, lib, nixpkgs, validUsers, discoverProfiles }: {
       # Required: Platform-specific inputs
       requiredInputs = {
         # Example for darwin:
         # nix-darwin = { url = "github:LnL7/nix-darwin"; follows = "nixpkgs"; };
       };
       
       # Required: Platform outputs
       outputs = {
         # Platform configurations (darwinConfigurations, nixosConfigurations, etc.)
         # Platform formatters
         # Platform validation data
       };
       
       # Optional: Platform metadata
       metadata = {
         name = "darwin";  # Platform identifier
         description = "macOS via nix-darwin";
         maintainer = "cdrokar";
       };
     }
     ```
   - **Validation Rules**:
     - File must export function with exact signature
     - Must return { requiredInputs, outputs, metadata }
     - Outputs must use platform-namespaced keys
   - **State Transitions**: N/A (stateless)

1. **Platform Discovery Service** (`platform/shared/lib/platform-discovery.nix`)

   - **Purpose**: Discover and load platform libraries
   - **Functions**:
     - `discoverPlatforms`: List available platforms from filesystem
     - `loadPlatform`: Import and validate platform library
     - `mergePlatformOutputs`: Combine outputs from all platforms
   - **Validation Rules**:
     - Skip platforms without flake-delegate.nix
     - Validate platform library exports
     - Detect and error on output conflicts

1. **Central Orchestration** (`flake.nix`)

   - **Current State**: Platform-specific imports and merging
   - **New State**: Platform-agnostic discovery and delegation
   - **Transformation**:
     - Remove explicit platform imports
     - Replace with `discoverPlatforms` call
     - Dynamically load and merge platform outputs

#### D2: API Contracts (`contracts/platform-library-api.md`)

**Contract**: Platform Library Interface

**Provider**: Each platform (`platform/{platform}/lib/flake-delegate.nix`)
**Consumer**: Central flake (`flake.nix`)

**Function Signature**:

```nix
{ inputs, lib, nixpkgs, validUsers, discoverProfiles }: {
  requiredInputs = { ... };
  outputs = { ... };
  metadata = { ... };
}
```

**Input Parameters**:

- `inputs`: All flake inputs from central flake
- `lib`: nixpkgs.lib utilities
- `nixpkgs`: nixpkgs flake input
- `validUsers`: List of valid users from discovery
- `discoverProfiles`: Function to discover profiles for platform

**Output Structure**:

- `requiredInputs`: Attribute set of required flake inputs for this platform
- `outputs`: Complete platform outputs (configurations, formatters, etc.)
- `metadata`: Platform metadata (name, description, maintainer)

**Validation Rules**:

- Function must accept exact parameter set
- Must return attribute set with `requiredInputs`, `outputs`, `metadata`
- Output keys must not conflict with other platforms
- Required inputs must specify url and optionally follows

**Error Handling**:

- Invalid exports: Clear error message identifying platform and issue
- Missing required fields: Error with field name
- Output conflicts: Error listing conflicting keys and platforms

**Example Implementation**:

```nix
# platform/darwin/lib/flake-delegate.nix
{ inputs, lib, nixpkgs, validUsers, discoverProfiles }: {
  requiredInputs = {
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      follows = "nixpkgs";
    };
  };
  
  outputs = {
    darwinConfigurations = /* ... */;
    formatter.aarch64-darwin = /* ... */;
    validProfiles.darwin = /* ... */;
  };
  
  metadata = {
    name = "darwin";
    description = "macOS platform via nix-darwin";
    maintainer = "cdrokar";
  };
}
```

#### D3: Quick Start Guide (`quickstart.md`)

**Audience**: Developers adding new platforms

**Structure**:

1. **Overview**: What is platform delegation
1. **Adding a New Platform**: Step-by-step guide
   - Create platform directory structure
   - Write `flake-delegate.nix` (template provided)
   - Test platform loads correctly
   - Verify outputs merge properly
1. **Platform Library Template**: Copy-paste starting point
1. **Testing Your Platform**: Validation commands
1. **Troubleshooting**: Common issues and solutions

### Agent Context Update

**Task**: Run `.specify/scripts/bash/update-agent-context.sh claude`

**Purpose**: Update CLAUDE.md with new technologies from this feature

**New Technologies** (if IMPLEMENT):

- Platform delegation pattern (Nix flake architecture)
- Dynamic platform discovery (builtins.readDir, dynamic imports)
- Platform library interface (flake-delegate.nix standard)

**Preserve**: All existing manual additions and technology listings

______________________________________________________________________

## Phase 2: Task Breakdown

**Note**: Phase 2 is performed by `/speckit.tasks` command (NOT by `/speckit.plan`).

**Inputs for tasks.md generation**:

- spec.md (user stories and acceptance criteria)
- plan.md (this file - technical approach)
- research.md (research findings)
- data-model.md (platform delegation interface)
- contracts/platform-library-api.md (API contract)

**Expected Task Structure** (for `/speckit.tasks` reference):

If research recommends IMPLEMENT:

- Phase 0: Research (already complete)
- Phase 1: Create platform-discovery.nix library
- Phase 2: Create flake-delegate.nix template
- Phase 3: Migrate darwin to delegation
- Phase 4: Migrate nixos to delegation
- Phase 5: Update flake.nix to use discovery
- Phase 6: Test and validate backward compatibility
- Phase 7: Documentation and cleanup

If research recommends DEFER or REJECT:

- Phase 0: Research (already complete)
- Phase 1: Document findings
- Phase 2: Update architecture decision record
- Phase 3: Close feature with recommendations

______________________________________________________________________

## Notes

**Key Design Decisions**:

1. **Research-First Approach**: US1 must complete before any implementation. Avoids wasted effort if delegation is not feasible.

1. **Backward Compatibility**: Critical priority. Existing configurations must work identically before and after any changes.

1. **Gradual Migration** (if implemented): Migrate one platform at a time (darwin first, then nixos) to validate approach incrementally.

1. **Constitutional Alignment**: This feature directly implements Principle VI (Cross-Platform Compatibility - Platform-Agnostic Orchestration).

1. **Performance Threshold**: 5% degradation is acceptable given benefits. >10% would require justification or deferral.

**Risk Mitigation**:

- **Risk**: Nix flakes don't support required dynamic capabilities

  - **Mitigation**: Phase 0 research identifies this early, recommends REJECT if true

- **Risk**: Flake.lock doesn't properly track dynamically loaded inputs

  - **Mitigation**: R5 research specifically validates this, REJECT if reproducibility compromised

- **Risk**: Community patterns don't exist (pioneering approach)

  - **Mitigation**: R6 research identifies this, document tradeoffs, may still IMPLEMENT if other criteria met

- **Risk**: Performance overhead exceeds threshold

  - **Mitigation**: R4 benchmarks measure actual impact, DEFER if >10%, document if 5-10%

**Success Indicators**:

- Research completes in 4-6 hours
- Clear IMPLEMENT/DEFER/REJECT recommendation with evidence
- If IMPLEMENT: Platform delegation reduces flake.nix complexity by ≥80%
- If DEFER: Clear conditions for future reconsideration documented
- If REJECT: Alternative approaches documented for future reference

**Follow-up Features** (if this recommends REJECT):

- Keep current architecture (feature 015 baseline)
- Future optimizations focus on other areas (build performance, etc.)
- Revisit if Nix flakes gain new capabilities in future versions
