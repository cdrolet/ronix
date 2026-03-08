# Research: Refactor System Structure

**Feature**: 013-refactor-system-structure\
**Created**: 2025-01-27\
**Purpose**: Research technical decisions and best practices for system structure refactoring

## Research Questions

### 1. Nix Module Options for hostSpec Validation

**Question**: What is the best way to validate required fields in a Nix module option and fail with clear error messages?

**Decision**: Use `lib.mkOption` with type checking and `lib.mkIf` for conditional validation, or use `assert` statements for required fields.

**Rationale**:

- Nix module system provides type checking via `lib.types` (e.g., `lib.types.submodule`, `lib.types.attrsOf`)
- `lib.mkIf` can conditionally enable configuration based on option values
- `assert` statements provide clear error messages when conditions fail
- Nix evaluation will naturally fail if required attributes are missing (attribute set access on undefined)
- Best practice: Use `lib.types.submodule` with required attribute checks for structured config

**Alternatives Considered**:

- Custom validation functions: More complex, less idiomatic
- Warning messages: Spec requires strict validation (fail fast)
- Optional fields with defaults: Does not meet requirement for strict validation

**Implementation Pattern**:

```nix
options.hostSpec = lib.mkOption {
  type = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Hostname identifier";
      };
      display = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable display name";
      };
      platform = lib.mkOption {
        type = lib.types.str;
        description = "Target platform architecture";
      };
    };
  };
  description = "Host identification configuration";
};
```

**Sources**: NixOS manual (module system), nix-darwin examples, Home Manager module patterns

______________________________________________________________________

### 2. Recursive Directory Discovery in Nix

**Question**: How to recursively discover all `.nix` files in a directory tree using pure Nix?

**Decision**: Use `builtins.readDir` recursively with Nix list functions, filtering for files with `.nix` extension.

**Rationale**:

- Nix provides `builtins.readDir` for directory reading (returns attribute set)
- Recursive traversal requires nested function calls or `lib.forEach` patterns
- File extension checking via `lib.hasSuffix ".nix"`
- Existing discovery functions in flake.nix provide pattern to follow
- Need to handle directory traversal while excluding `defaults.nix` itself

**Alternatives Considered**:

- External script: Violates Constitution (must be pure Nix)
- Single-level discovery only: Does not meet requirement (spec requires recursive)
- Using nix-gitignore or similar: Overkill, adds dependency

**Implementation Pattern**:

```nix
discoverModules = basePath: let
  entries = builtins.readDir basePath;
  files = lib.filterAttrs (name: type: 
    type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
  ) entries;
  dirs = lib.filterAttrs (name: type: type == "directory") entries;
  
  # Recursively discover subdirectories
  subdirFiles = lib.flatten (lib.mapAttrsToList (name: _:
    map (file: "${name}/${file}") (discoverModules (basePath + "/${name}"))
  ) dirs);
in
  (lib.attrNames files) ++ subdirFiles;
```

**Sources**: Nix manual (builtins), existing flake.nix discovery functions, NixOS module system patterns

______________________________________________________________________

### 3. Nix Module Import Patterns for Auto-Discovery

**Question**: How to dynamically generate imports list from discovered file paths in a Nix module?

**Decision**: Use `builtins.map` to convert discovered paths to import statements in the `imports` attribute.

**Rationale**:

- Nix module `imports` attribute accepts list of paths
- Paths can be generated dynamically using string interpolation
- Pattern: `map (file: ./${file}) discoveredFiles`
- Works within Nix's evaluation model (paths are known at eval time)
- Standard pattern used in NixOS profiles and Home Manager configs

**Alternatives Considered**:

- Using `import` directly in expressions: More complex, not standard pattern
- External generation script: Violates Constitution (must be declarative)
- Manual import list: Defeats purpose of auto-discovery

**Implementation Pattern**:

```nix
imports = map (file: ./${file}) (
  discoverModules ./.  # Returns list like ["dock.nix", "finder.nix", "dev/git.nix"]
);
```

**Sources**: NixOS manual (module system), Home Manager examples, nix-darwin profiles

______________________________________________________________________

### 4. nix-darwin Built-in Capabilities vs Custom Functions

**Question**: Which Darwin library functions might be redundant with nix-darwin built-in options?

**Decision**: Review nix-darwin documentation and source to identify overlap, particularly for:

- Dock management (system.defaults.dock.\*)
- Power management (system.defaults.EnergySaver.\*)
- System preferences (system.defaults.\* namespace)

**Rationale**:

- nix-darwin provides extensive `system.defaults.*` options for macOS preferences
- Custom activation scripts may duplicate functionality available declaratively
- Need to verify which functions provide value beyond nix-darwin defaults
- Functions in `dock.nix`, `power.nix`, `system-defaults.nix` likely candidates

**Alternatives Considered**:

- Keep all functions: Increases maintenance burden, potential confusion
- Remove without review: Risk removing useful functionality
- Full audit approach: Recommended - systematic review ensures correctness

**Review Areas**:

- `dock.nix`: Check against `system.defaults.dock.*` options
- `power.nix`: Check against `system.defaults.EnergySaver.*` options
- `system-defaults.nix`: Check against `system.defaults.*` namespace
- `mac.nix`: Evaluate if re-export layer adds value or can be eliminated

**Sources**: nix-darwin GitHub repository, nix-darwin documentation, existing usage in profiles

______________________________________________________________________

### 5. system.stateVersion Override Pattern

**Question**: How to set a default system.stateVersion in darwin.nix while allowing profile-level overrides?

**Decision**: Use Nix module system precedence - set default in darwin.nix module list, profiles can override using `mkDefault` or direct assignment.

**Rationale**:

- Nix module system applies later definitions override earlier ones
- If darwin.nix sets `system.stateVersion = 5;` in its module list, profiles can override
- Use `lib.mkDefault` in darwin.nix if we want override priority, or direct assignment if profiles should always win
- Spec clarifies: profile overrides central, so use direct assignment in profiles (no mkDefault needed)
- Best practice: Central default in darwin.nix, profiles override as needed

**Alternatives Considered**:

- Using mkForce: Too aggressive, prevents any overrides
- Using mkDefault: Would make central value harder to override
- Conditional checks: Unnecessary complexity

**Implementation Pattern**:

```nix
# In darwin/lib/darwin.nix
modules = [
  # Central default (lowest priority)
  {
    system.stateVersion = 5;
  }
  
  # Profile module (higher priority, can override)
  ../profiles/${profile}
];
```

**Sources**: NixOS manual (module system precedence), nix-darwin examples

______________________________________________________________________

### 6. mac.nix Necessity Evaluation

**Question**: Is `mac.nix` serving a necessary purpose, or can modules be imported directly?

**Decision**: Evaluate based on:

- Does it add value beyond re-exporting?
- Does it provide abstraction or convenience?
- Is it reducing duplication or adding it?

**Rationale**:

- Re-export layers can add unnecessary indirection
- Spec notes maintenance burden (updating mac.nix when adding functions)
- Direct imports are clearer and more maintainable
- Keep only if it provides meaningful abstraction or prevents duplication

**Evaluation Criteria**:

- If mac.nix only re-exports: Remove it
- If mac.nix provides unified interface: Keep it
- If mac.nix reduces import complexity: Evaluate case-by-case

**Current Assessment** (based on code review):

- mac.nix currently only re-exports dock, power, and system-defaults functions
- No abstraction or unified interface provided
- Adds maintenance overhead (must update when adding functions)
- Recommendation: Remove mac.nix, import dock.nix, power.nix, system-defaults.nix directly

**Sources**: Existing mac.nix implementation, Constitution (modularity principles), code review

______________________________________________________________________

## Summary of Decisions

1. **hostSpec Validation**: Use `lib.types.submodule` with required attributes for type-safe validation
1. **Recursive Discovery**: Implement recursive `builtins.readDir` traversal with file filtering
1. **Dynamic Imports**: Use `map (file: ./${file})` pattern for auto-generated imports
1. **Function Review**: Audit dock.nix, power.nix, system-defaults.nix against nix-darwin capabilities
1. **State Version Override**: Set default in darwin.nix, profiles override via module precedence
1. **mac.nix Removal**: Remove re-export layer, use direct imports

All technical decisions align with Constitution principles and Nix best practices. No external dependencies required beyond existing nix-darwin and nixpkgs.

______________________________________________________________________

## Darwin Library Function Review (Completed 2025-01-27)

### dock.nix - KEEP (Provides unique functionality)

**Functionality**: Uses dockutil to manage Dock apps programmatically (add/remove specific apps)

**nix-darwin Coverage**: `system.defaults.dock.*` only provides preferences (autohide, tilesize, etc.), NOT app management

**Verdict**: **KEEP** - dock.nix provides functionality not available in nix-darwin

- Declarative dock configuration via activation scripts
- Manages which apps appear in Dock (add/remove)
- nix-darwin doesn't provide equivalent functionality

**Usage**: Currently used in `system/darwin/settings/dock.nix`

### power.nix - KEEP (Provides specific pmset functionality)

**Functionality**: Uses pmset to configure power management settings with idempotency

**nix-darwin Coverage**: Limited `system.defaults.EnergySaver.*` options (basic sleep settings)

**Verdict**: **KEEP** - power.nix provides finer-grained control

- Covers settings not exposed via nix-darwin (standbydelay, etc.)
- Idempotent activation scripts with current value checking
- Useful for specific power management requirements

**Usage**: Currently used in `system/darwin/settings/power.nix`

### system-defaults.nix - KEEP (System-level /Library/Preferences)

**Functionality**: Sets system-level preferences in /Library/Preferences/ (requires sudo)

**nix-darwin Coverage**: Extensive `system.defaults.*` namespace for user-level preferences

**Verdict**: **KEEP** - system-defaults.nix handles system-level settings

- nix-darwin primarily handles user-level defaults
- System-level preferences in /Library/Preferences/ require sudo
- Used for security settings, firewall configuration, etc.

**Usage**: Currently used in `system/darwin/settings/initial-setup.nix`

### mac.nix - REMOVE (Unnecessary re-export layer)

**Functionality**: Re-exports functions from dock.nix, power.nix, system-defaults.nix

**Assessment**:

- Pure re-export layer with no added functionality
- Used in 3 files: dock.nix, power.nix, initial-setup.nix
- Adds maintenance overhead (must update when functions added)
- Direct imports are clearer

**Verdict**: **REMOVE** - Update 3 files to import directly

- Replace `import ../lib/mac.nix` with direct imports
- Example: `import ../lib/dock.nix { inherit pkgs lib; }`

**Files to Update**:

1. `system/darwin/settings/dock.nix`
1. `system/darwin/settings/power.nix`
1. `system/darwin/settings/initial-setup.nix`

### Conclusion

**Functions to Keep**: All 3 libraries (dock.nix, power.nix, system-defaults.nix) provide unique value

- Each provides functionality not fully covered by nix-darwin
- Used for activation scripts (imperative operations)
- Complement nix-darwin's declarative settings

**Functions to Remove**: mac.nix (re-export layer)

- No functional value, just indirection
- Direct imports improve clarity and maintainability
