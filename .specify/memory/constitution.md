<!--
SYNC IMPACT REPORT

Version Change: 2.2.1 → 2.3.0
Change Type: MINOR - Add mandatory context validation for settings and applications

Modified Sections:
  - Development Standards > Context Validation (NEW):
    - MANDATORY context checks for all settings and application modules
    - Settings/apps MUST use lib.optionalAttrs with (options ? home) check
    - Prevents "option does not exist" errors in wrong context
    - Guards home-manager-specific code from system-level evaluation
    - Pattern codified from Feature 037 implementation learnings

Rationale:
  - MINOR version: New architectural requirement affecting all future modules
  - Prevents infinite recursion from accessing config._configContext
  - Ensures settings work correctly in both system and home-manager contexts
  - Codifies best practice discovered during wildcard implementation
  - Makes context validation mandatory for all new code

Breaking Changes:
  ⚠️ All new settings/apps must include context validation
  ⚠️ Existing modules should be updated to follow pattern (gradual migration)
  ✅ Prevents common error pattern discovered in production

Benefits:
  ✅ No more "option 'home' does not exist" errors
  ✅ No infinite recursion from config access in conditionals
  ✅ Settings safely skip when not in appropriate context
  ✅ Constitutional requirement prevents future violations
  ✅ Clear pattern for all developers to follow

Templates Requiring Updates:
  ⚠️ .specify/templates/spec-template.md - Add context validation to requirements checklist
  ⚠️ .specify/templates/tasks-template.md - Add context validation as implementation task
  ⚠️ docs/ - Update module development guides with context validation pattern

Previous Version (2.2.0 → 2.2.1):
Change Type: PATCH - Add "No Backward Compatibility" principle

[Previous sync report content preserved...]
-->

# Nix-Config Constitution

## Core Principles

### I. Declarative Configuration First

All system configurations MUST be declared in Nix expressions. No imperative configuration steps are permitted in production environments. Every system state MUST be reproducible from the Nix configuration files alone.

**Rationale**: Declarative configurations ensure reproducibility, auditability, and version control of all system states. This prevents configuration drift and enables rollbacks.

### II. Modularity and Reusability

Configuration modules MUST be self-contained, independently composable, and reusable across different hosts or environments. Each module MUST have a single, well-defined purpose. Modules MUST declare their dependencies explicitly.

The repository MUST follow a hierarchical user/system split directory layout for improved modularity and multi-user management:

**Required directories**:

- **user/** - User-specific configurations and personal app selections
  - `user/{username}/default.nix` - Per-user configuration with app imports
  - `user/shared/lib/` - User environment helper libraries (Home Manager bootstrap)
  - `user/shared/profiles/` - Shared user profile templates (optional)
- **system/** - System-wide configurations organized hierarchically
  - `system/shared/{app,settings,lib}/` - Universal cross-platform configurations
  - `system/shared/profiles/{family}/` - Cross-platform family profiles (linux, linux-gnome)
  - `system/{platform}/{app,settings,lib}/` - Platform-specific configurations (darwin, nixos, kali)
  - `system/{platform}/profiles/{context}/` - Platform + context profiles (darwin/profiles/work)
- **secrets/** - Encrypted secrets managed by agenix
  - `secrets/users/{username}/` - User-specific secrets
  - `secrets/system/{platform}/` - System-specific secrets
  - `secrets/shared/` - Cross-platform shared secrets
  - `secrets/secrets.nix` - Single source of truth for age key mappings

**Placement rules** (User/System Split pattern):

- User app selections → `user/{username}/default.nix`
- Cross-platform apps → `system/shared/app/{category}/{app}.nix`
- Platform family apps (linux, linux-gnome) → `system/shared/profiles/{family}/app/`
- Platform-specific apps → `system/{platform}/app/{category}/{app}.nix`
- System settings → `system/{platform}/settings/`
- Helper libraries → `system/shared/lib/` (cross-platform) or `system/{platform}/lib/` (platform-specific)
- Secrets → `secrets/` with centralized key management

**App-Centric Organization**:

- Each application MUST be in a single self-contained module file
- App modules MUST bundle: package declaration, configuration, shell aliases, file associations
- App modules MUST be \<200 lines (refactor if exceeded)
- Dependencies MUST be declared explicitly via `imports` at module top
- Circular dependencies are FORBIDDEN

**Rationale**: The hierarchical user/system split improves modularity by:

- App-centric organization: Single file per application instead of scattered configs
- Multi-user management: Clear separation between user selections and system configurations
- Scalability: Handles 40-50 apps across 3 users and 3 platforms without confusion
- Platform families: Reusable bundles (linux, linux-gnome) prevent duplication across NixOS/Kali
- Composability: Hierarchical profiles enable flexible system deployment

**Community Standards**: This structure extends Nix community patterns (Blueprint, Home Manager) with app-centric organization and hierarchical profiles. The user/system split maintains modularity principles while improving multi-user and multi-platform scalability.

### III. Documentation-Driven Development (NON-NEGOTIABLE)

Every configuration module MUST include:

- Clear documentation of purpose and usage
- Description of all options and their defaults
- Examples demonstrating typical use cases
- Dependencies and requirements explicitly stated

Code changes without corresponding documentation updates are NOT permitted.

**Rationale**: Nix configurations can become complex; documentation ensures maintainability and knowledge transfer, especially for system administrators unfamiliar with the codebase.

### IV. Purity and Reproducibility

Configurations MUST be pure and deterministic. No network access during build time (except through fixed-output derivations with hash verification). All external dependencies MUST be pinned with explicit versions or content hashes.

**Rationale**: Reproducibility is a core Nix principle. Impure configurations lead to non-reproducible builds and defeat the purpose of using Nix.

### V. Testing and Validation

All configuration changes MUST be validated before deployment:

- Syntax validation via `nix flake check` or equivalent
- Build verification in isolated environments
- Integration tests for critical system services
- Rollback procedures documented and tested

**Rationale**: System configuration errors can render systems unbootable. Rigorous testing prevents production failures and ensures reliable deployments.

### VI. Cross-Platform Compatibility (NON-NEGOTIABLE)

**Platform-Agnostic Orchestration** (v2.0.4+):

- The flake.nix MUST be a thin orchestration layer that only loads platforms that exist
- Each platform lib (`platform/{platform}/lib/{platform}.nix`) MUST export complete outputs for that platform
- Platform-specific code MUST NOT be loaded if that platform is not in use
- Benefits: Users of one platform never load code for other platforms
- Each platform is completely self-contained and independent
- The configuration is platform-agnostic: functions and structure can be applied to any platform supporting Home Manager and Nix packages

**Platform Examples** (not exhaustive):

- Platform configurations in `platform/` (e.g., darwin, nixos) serve as examples
- The architecture supports any platform with Home Manager and Nix packages
- No specific platforms are required or expected
- Directory structure shows possibilities, not limitations

**Note**: The term "hosts" refers to physical/virtual machines, while "profiles" refer to the configuration bundles in `platform/{platform}/profiles/`. Profiles are the deployable units that configure specific hosts.

**Rationale**: Platform-agnostic design maximizes flexibility and reusability. Supporting multiple platforms requires disciplined separation of platform-agnostic and platform-specific code. Users can add any platform that supports the required tooling without modifying the core architecture.

## Architectural Standards

### Flakes as Entry Point (NON-NEGOTIABLE)

The repository MUST use Nix flakes as the primary entry point:

- `flake.nix` at repository root defines all inputs and outputs
- All nixpkgs and dependency inputs MUST be pinned in `flake.lock`
- Use `nix flake update` for dependency updates (never manual pin changes)
- Follow latest Nix flakes best practices and conventions

**Rationale**: Flakes provide reproducible dependency management, standardized structure, and improved caching. They are the modern standard for Nix configuration repositories.

### Home Manager Integration (NON-NEGOTIABLE)

Home Manager MUST be used for declarative user environment management:

- User-specific configurations (dotfiles, packages, services) managed via Home Manager
- User configurations located in `user/{username}/default.nix` for per-user configs
- Shared user helper libraries located in `user/shared/lib/` (e.g., home.nix bootstrap)
- User configurations MUST be modular and reusable across systems
- All user environment state MUST be declarative (no imperative `home-manager` commands)

**Rationale**: Home Manager enables declarative user environment configuration, complementing system-level NixOS/nix-darwin configurations. This ensures complete system reproducibility including user spaces.

### Directory Structure Standard

The repository MUST follow this canonical structure:

```
nix-config/
├── flake.nix              # Flake entry point with user/profile combinations
├── flake.lock             # Locked dependencies
├── .envrc                 # direnv integration
├── justfile               # Installation command interface (just install <user> <profile>)
│
├── docs/                  # User-facing documentation (wiki structure)
│   ├── README.md          # Documentation index
│   ├── features/          # Feature summaries from specifications
│   ├── guides/            # User guides and tutorials
│   └── architecture/      # Architecture decisions and patterns
│
├── user/                  # User-specific configurations
│   ├── cdrokar/           # User persona configurations
│   │   └── default.nix    # User's app selections and personal settings
│   ├── cdrolet/
│   │   └── default.nix
│   ├── cdrixus/
│   │   └── default.nix
│   └── shared/
│       ├── lib/
│       │   └── home.nix   # Home Manager bootstrap module
│       └── profiles/      # Shared user profile templates (optional)
│
├── system/                # System-wide configurations (hierarchical)
│   ├── shared/            # Universal cross-platform
│   │   ├── app/           # Apps that work on ANY platform
│   │   │   ├── dev/       # Development tools (git, python, etc.)
│   │   │   ├── editor/    # Text editors (helix, zed, etc.)
│   │   │   ├── shell/     # Shell tools (zsh, starship, etc.)
│   │   │   └── browser/   # Web browsers (zen, brave, etc.)
│   │   ├── settings/      # Cross-platform system settings
│   │   ├── lib/           # Helper libraries (file-associations.nix)
│   │   └── profiles/      # Cross-platform family profiles
│   │       ├── linux/     # Linux family (NixOS, Kali, Ubuntu)
│   │       │   ├── app/
│   │       │   ├── settings/
│   │       │   └── lib/
│   │       └── linux-gnome/  # GNOME desktop family
│   │           ├── app/
│   │           ├── settings/
│   │           └── lib/
│   │
│   ├── darwin/            # macOS-specific (nix-darwin)
│   │   ├── app/           # macOS apps (aerospace, borders, etc.)
│   │   ├── settings/      # macOS system settings (dock, finder, etc.)
│   │   ├── lib/           # macOS helper libraries
│   │   └── profiles/      # Platform + context profiles
│   │       ├── home/      # Home/personal profile
│   │       │   └── default.nix
│   │       └── work/      # Work/restricted profile
│   │           └── default.nix
│   │
│   └── nixos/             # NixOS-specific (full system)
│       ├── app/           # NixOS-specific apps
│       ├── settings/      # NixOS system settings
│       ├── lib/           # NixOS helper libraries
│       └── profiles/      # NixOS profiles
│           ├── gnome-desktop-1/
│           ├── kde-desktop-1/
│           └── server-1/
│
├── secrets/               # Encrypted secrets (agenix)
│   ├── users/             # User-specific secrets
│   │   ├── cdrokar/
│   │   ├── cdrolet/
│   │   └── cdrixus/
│   ├── system/            # System-specific secrets
│   │   ├── darwin/
│   │   └── nixos/
│   ├── shared/            # Cross-platform shared secrets
│   └── secrets.nix        # Single source of truth for age key mappings
│
└── README.md
```

**This structure implements the User/System Split pattern with hierarchical organization. The structure is defined by Constitution v2.0.0 and reflects app-centric, multi-user architecture.**

## Development Standards

### Context Validation (NON-NEGOTIABLE)

All settings and application modules MUST validate their execution context to prevent evaluation errors and ensure correct behavior across different build stages.

**Mandatory Context Checks**:

Every module that uses home-manager-specific options (e.g., `home.packages`, `home.activation`, `home.file`, `dconf.settings`) MUST guard those options with context validation:

```nix
{
  config,
  lib,
  pkgs,
  options,  # REQUIRED: Must include options in module arguments
  ...
}: {
  # Guard home-manager-specific configuration
  config = lib.optionalAttrs (
    (options ? home)     # Check if home option exists (home-manager context)
    && otherConditions   # Additional feature-specific conditions
  ) {
    home.packages = [ ... ];
    home.activation.myFeature = ...;
    # Other home-manager options
  };
}
```

**Required Pattern**:

- **MUST use `lib.optionalAttrs`** - Returns empty set when condition false, preventing option evaluation
- **MUST check `(options ? home)`** - Verifies home-manager context without accessing config
- **MUST NOT access `config._configContext`** - Causes infinite recursion with `lib.optionalAttrs`
- **MUST include `options` in module arguments** - Required for context check

**Why This Pattern**:

- **`lib.mkIf` fails**: Module system validates option existence even when condition is false
- **`config._configContext` fails**: Accessing config in `lib.optionalAttrs` causes infinite recursion
- **`options ? home` succeeds**: Checks capability without config access, no recursion

**Context Scenarios**:

1. **Darwin system (Stage 1)**: `options ? home` is `false` → settings skipped
1. **NixOS system (Stage 1)**: `options ? home` is `false` → settings skipped
1. **Standalone home-manager (Stage 2)**: `options ? home` is `true` → settings applied

**Examples**:

```nix
# Settings module with home-manager-specific activation
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  hasFeature = config.user.enableFeature or false;
in {
  config = lib.optionalAttrs (
    (options ? home)
    && hasFeature
  ) {
    home.activation.myFeature = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Activation script here
    '';
  };
}

# App module with home.packages
{
  config,
  lib,
  pkgs,
  options,
  ...
}: {
  config = lib.optionalAttrs (options ? home) {
    home.packages = [ pkgs.myapp ];
  };
}

# App with both system-level (homebrew) and home-manager config
{
  config,
  lib,
  pkgs,
  options,
  ...
}: lib.mkMerge [
  # System-level (works in both contexts)
  (lib.optionalAttrs (options ? homebrew) {
    homebrew.casks = ["myapp"];
  })
  
  # Home-manager-level (only in home-manager context)
  (lib.optionalAttrs (options ? home) {
    home.packages = [ pkgs.myapp ];
    xdg.configFile."myapp/config.json".text = ''...'';
  })
]
```

**Anti-Patterns Prohibited**:

- ❌ Using `lib.mkIf` for context checks (option existence still validated)
- ❌ Accessing `config._configContext` in `lib.optionalAttrs` condition (infinite recursion)
- ❌ No context check when using `home.*` options (causes "option does not exist" errors)
- ❌ Using conditional expressions `if/then/else` with config access (infinite recursion)

**Rationale**: Context validation prevents common errors when modules are imported in both system and home-manager contexts. The `options ? home` pattern safely checks capability without triggering infinite recursion. This requirement codifies the lesson learned during Feature 037 implementation and prevents future violations.

### Specification Management (NON-NEGOTIABLE)

All feature development MUST follow a specification-driven process with integrity checks between iterations:

**Between Specification Iterations**:

- Check integrity against previous iterations to identify inconsistencies
- Remove duplications across specification documents
- Expect and actively resolve contradictions between old and new specifications
- Update affected documentation when specifications evolve

**Documentation Repository**:

- Project MUST maintain a `docs/` folder organized as a wiki structure
- Documentation MUST remain synchronized with current system state
- Documentation is intended for users to understand how to use the system
- Documentation MUST NOT reference specifications, project tracking, historical decisions, or implementation tasks
- Focus exclusively on "how to use" instructions for end users

**Specification Lifecycle**:

1. **Draft**: Created via `/speckit.specify`, stored in `specs/###-feature-name/spec.md`
1. **Planned**: Enhanced via `/speckit.plan`, design artifacts generated in `specs/###-feature-name/`
1. **Implemented**: Executed via `/speckit.implement`, code changes made
1. **Documented**: User documentation created in `docs/features/###-feature-name.md` explaining usage
1. **Archived**: Original specification preserved in `specs/` for historical reference

**Integrity Checks**:

- Before creating new specifications, review related existing specs for conflicts
- When updating constitution, check for contradictions with existing principles
- When modifying modules, verify specifications are still accurate
- Quarterly review of documentation to remove outdated content

### Refactoring Discipline (NON-NEGOTIABLE)

When refactoring code, ALWAYS distinguish between "fix mode" and "refactor mode":

**Before "Fixing" Missing/Broken Functions**:

1. **STOP**: Ask "Is this function part of the OLD pattern we're eliminating?"
1. **CHECK**: Does the function name reveal it belongs to deprecated approach?
1. **DECIDE**: Remove the caller instead of implementing the function if it's part of old pattern
1. **VALIDATE**: Verify removal doesn't break actual functionality (only breaks old interface)

**Refactoring Checklist**:

- [ ] Identify what old pattern is being replaced
- [ ] List all functions/interfaces that belong to old pattern
- [ ] Remove old pattern functions instead of fixing them
- [ ] Implement new pattern functions that replace old functionality
- [ ] Update all call sites to use new pattern
- [ ] Verify no old pattern remnants remain

**Rationale**: During refactoring, "broken" code often signals what needs removal, not repair. Fixing old pattern functions wastes effort and delays proper refactoring.

### No Backward Compatibility (NON-NEGOTIABLE)

This project does NOT maintain backward compatibility:

**Breaking Changes Are Permitted**:

- Configuration structure can change at any time
- APIs and interfaces can be redesigned without deprecation periods
- Module names, paths, and signatures can change freely
- No compatibility layers or shims required

**Prohibited Patterns**:

- ❌ Backward compatibility aliases (e.g., `oldName = newName;`)
- ❌ Deprecated function warnings with "use X instead"
- ❌ Conditional logic supporting both old and new patterns
- ❌ Migration shims or compatibility wrappers

**When Breaking Changes Occur**:

1. Make the breaking change directly (no transition period)
1. Update all affected code in the same commit
1. Document the change in commit message
1. Use semantic versioning (MAJOR bump for breaking changes)

**Rationale**: As a single-user project, backward compatibility adds unnecessary complexity without benefit. Clean, direct changes are faster to implement and easier to maintain. The sole user can adapt configurations immediately without supporting multiple versions.

**Exception**: If the project gains multiple users in the future, this principle should be revisited and a deprecation strategy established.

### Implementation Blockers (NON-NEGOTIABLE)

When a task cannot be implemented in a straightforward way and faces multiple unseen obstacles:

**STOP Implementation**:

- Do NOT proceed with workarounds or complex solutions
- Do NOT attempt to "push through" blocking issues
- Do NOT accumulate technical debt to bypass problems

**Document in UNRESOLVED.md**:

- Create `specs/###-feature-name/UNRESOLVED.md` documenting all blocking issues
- List each obstacle with clear description of the problem
- Explain what was attempted and why it failed
- Identify missing information or unclear requirements
- Note dependencies on external factors or decisions

**Requirements for UNRESOLVED.md**:

- Clear problem statement for each blocker
- Context about what was tried
- Questions that need answers before proceeding
- Impact assessment (what can't be done without resolution)

**Resolution Process**:

- Review UNRESOLVED.md with stakeholders
- Clarify requirements and constraints
- Make necessary architectural decisions
- Update specifications based on resolution
- Only then resume implementation

**Rationale**: Forcing implementation through blockers creates technical debt, poor solutions, and wasted effort. Documenting blockers enables proper problem-solving and prevents accumulation of workarounds. Clean implementation requires clear requirements.

### Version Control Discipline

- All changes MUST be committed to version control
- Commit messages MUST follow conventional commit format
- Sensitive data (secrets, passwords, keys) MUST NEVER be committed in plaintext
- Use agenix for secrets management with age encryption and centralized key mapping in `secrets/secrets.nix`

### Code Organization

- Follow the hierarchical directory structure defined in Architectural Standards
- Group related configurations by purpose and scope
- Use meaningful, descriptive names for modules and options
- Avoid deeply nested directory structures (max 3-4 levels)
- Each module file SHOULD be under 200 lines; refactor into sub-modules if larger

### Nix Expression Style

- Use alejandra for consistent formatting
- Prefer explicit attribute names over `with` statements
- Document complex expressions with inline comments
- Use `lib.mkOption` with proper type declarations for all module options
- Define sensible defaults for all options where applicable

### Configuration Module Organization (NON-NEGOTIABLE)

All configuration files MUST follow a topic-based organizational pattern for maintainability and discoverability:

**Structure Requirements**:

- **Category directories**: Group related configurations by category (e.g., `system/darwin/app/`, `system/darwin/settings/`)
- **Topic-based files**: Individual files for each functional domain within a category
- **Aggregator pattern**: Use `default.nix` to import and expose all files in a directory when needed

**Configuration File Requirements**:

- **Single responsibility**: Each file configures one functional domain or application only
- **Size limit**: Maximum 200 lines per file (refactor into sub-modules if exceeded)
- **Clear naming**: File name must immediately convey the configuration's purpose
- **Header documentation**: Purpose, dependencies, key options, and usage examples
- **Default values**: All settings MUST use `lib.mkDefault` for user overridability (except when explicit override is required)

**Example Pattern** (darwin system settings):

```
system/darwin/
├── settings/
│   └── default.nix           # Aggregates all darwin settings
├── app/
│   ├── aerospace.nix         # Window manager configuration
│   ├── borders.nix           # Window borders configuration
│   └── rectangle.nix         # Window management configuration
└── lib/
    └── helpers.nix           # Platform-specific helper functions
```

**Topic Identification Criteria**:

1. Functional cohesion - configuration controls the same component/application
1. Independent management - users modify topics independently
1. Size consideration - configuration stays under 200 lines
1. Naming clarity - unambiguous, specific file names

**Anti-Patterns Prohibited**:

- ❌ Monolithic configuration files exceeding 200 lines
- ❌ Generic file names (misc.nix, other.nix, utils.nix)
- ❌ Mixed concerns (unrelated settings grouped for convenience)
- ❌ Hardcoded values without `lib.mkDefault` (prevents user customization)
- ❌ Missing header documentation

**Rationale**: Topic-based organization ensures maintainability, discoverability, and scalability. Small, focused configuration files are easier to understand, modify, and review. The pattern prevents monolithic files that become difficult to navigate and maintain as the system grows.

### Platform-Specific Code

- Isolate platform-specific logic using `lib.mkIf pkgs.stdenv.isDarwin` or `lib.mkIf pkgs.stdenv.isLinux`
- Document platform requirements in module comments
- Test configurations on both platforms when making cross-platform changes
- Prefer platform-agnostic solutions when possible

### Helper Libraries and Activation Scripts (NON-NEGOTIABLE)

Helper libraries provide reusable functions to eliminate code duplication and ensure consistent, maintainable logic across all configuration files.

**Helper Library Structure**:

- **Shared libraries** (`system/shared/lib/`): Pure cross-platform utilities with ZERO platform-specific logic
- **Platform family libraries** (`system/shared/profiles/{family}/lib/`): Shared utilities for platform families (linux, linux-gnome)
- **Platform-specific libraries** (`system/darwin/lib/`, `system/nixos/lib/`): Platform-specific helper functions

**Dependency Flow** (unidirectional):

```
system profile lib → system platform lib → system shared platform family lib → system shared lib
```

**Library Organization Requirements**:

- **Shared libraries** (`system/shared/lib/`):

  - MUST be completely platform-agnostic (no `pkgs.stdenv.isDarwin` checks)
  - Provide pure functions usable across all platforms
  - Examples: `mkFileAssociation` (cross-platform file associations)

- **Platform family libraries** (`system/shared/profiles/linux/lib/`):

  - Container for utilities shared across platform family members
  - Example: systemd helpers for systemd-based distributions (NixOS, Kali, Ubuntu, Debian)
  - MUST import and use shared libraries when applicable

- **Platform-specific libraries** (`system/darwin/lib/`, `system/nixos/lib/`):

  - Provide high-level declarative functions abstracting platform-specific operations
  - Example: `mkDockClear` (darwin), `mkSystemdEnable` (nixos)
  - Import and use shared libraries when applicable

**Activation Script Requirements** (when needed):

- MUST be idempotent (safe to run multiple times)
- MUST use helper libraries instead of duplicating patterns
- MUST use high-level declarative functions (avoid verbose inline commands)
- MUST document root privilege requirements
- SHOULD minimize use of activation scripts (prefer declarative configuration)

**Anti-Patterns Prohibited**:

- ❌ Duplicating common patterns across activation scripts
- ❌ Platform-specific checks in shared libraries
- ❌ Verbose inline commands without helper functions
- ❌ Non-idempotent activation scripts
- ❌ Shared libraries depending on platform-specific code
- ❌ Code duplication across platform family members

**Best Practices**:

- Extract reusable logic into helper libraries (`system/{platform}/lib/`)
- Use descriptive function names that make intent clear
- Prefer declarative Nix options over imperative activation scripts
- Document why activation scripts are necessary (when declarative options don't exist)

**Rationale**: Helper libraries eliminate code duplication, ensure consistent behavior, and improve maintainability. The hierarchical dependency flow (profile → platform → family → shared) prevents duplication while enabling platform-specific functionality when needed.

## Quality Assurance

### Pre-Deployment Checks

Before deploying any configuration change, the following MUST pass:

1. **Syntax validation**: `nix flake check` exits with code 0
1. **Build verification**: Configuration builds successfully in clean environment
1. **Platform testing**: Verify on target platform (macOS or NixOS)
1. **Breaking change review**: Assess impact on existing deployments
1. **Rollback plan**: Document steps to revert if deployment fails

### Performance and Resource Constraints

- Build closures SHOULD remain under reasonable size (document thresholds per use case)
- Avoid unnecessary dependencies that bloat the closure size
- Profile builds if closure size increases significantly (>20% from baseline)
- Document resource requirements (disk, memory) for configurations
- Cache frequently-built derivations to improve rebuild times

### Security Requirements

- Keep nixpkgs inputs updated to receive security patches (monthly minimum)
- Review security advisories for included packages
- Minimize attack surface by enabling only required services
- Use platform security hardening modules where applicable
- Rotate secrets regularly and never commit unencrypted secrets
- Use sops-nix with age for secret encryption

## Governance

### Constitution Authority

This constitution supersedes all other development practices and coding conventions. When conflicts arise, constitution principles take precedence. All configuration reviews, pull requests, and deployments MUST verify compliance with these principles.

### Amendment Process

**For Personal/Solo Projects** (single maintainer, no team):

Amendments to this constitution require:

1. Proposed changes documented with rationale (in commit message or spec)
1. **No waiting period required** - changes take effect immediately upon commit
1. Migration plan for changes affecting existing configurations (if MAJOR)
1. Version bump according to semantic versioning
1. Update SYNC IMPACT REPORT with rationale and migration guidance

**For Team Projects** (multiple maintainers):

Amendments to this constitution require:

1. Proposed changes documented with rationale
1. Review period for feedback (minimum 48 hours for MINOR/PATCH, 1 week for MAJOR)
1. Approval from project maintainer(s)
1. Migration plan for changes affecting existing configurations
1. Version bump according to semantic versioning

### Version Semantics

- **MAJOR**: Backward-incompatible principle removals or fundamental governance changes (e.g., removing a NON-NEGOTIABLE principle, restructuring directory layout)
- **MINOR**: New principles added or existing principles materially expanded (e.g., adding architectural standards, new required tooling)
- **PATCH**: Clarifications, wording improvements, typo fixes, non-semantic refinements

### Compliance and Review

- All pull requests MUST include a constitution compliance statement
- Complexity or principle violations MUST be justified in writing
- Use `.specify/memory/constitution.md` as the authoritative reference for development guidance
- Regular constitution review (quarterly recommended) to ensure relevance
- Architecture decisions MUST reference relevant constitutional principles

**Version**: 2.3.0 | **Ratified**: 2025-10-21 | **Last Amended**: 2026-01-04
