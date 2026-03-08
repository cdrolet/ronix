# Research: Darwin System Defaults Restructuring and Migration

**Feature**: Darwin System Defaults Restructuring and Migration\
**Date**: 2025-10-26\
**Purpose**: Research nix-darwin capabilities, mapping strategies, and best practices for modular system configuration

## Research Questions

1. How are nix-darwin system defaults organized and what options are available?
1. How to map bash `defaults write` commands to nix-darwin options?
1. What settings from system.sh cannot be expressed in nix-darwin?
1. Best practices for topic-based module organization in Nix?
1. How to handle deprecated macOS settings during migration?

## Findings

### 1. nix-darwin System Defaults Organization

**Decision**: Use nix-darwin's `system.defaults` attribute set with platform-specific sub-attributes

**Rationale**:

- nix-darwin provides structured `system.defaults` options for common macOS settings
- Main categories: `dock`, `finder`, `trackpad`, `NSGlobalDomain`, `screencapture`, `CustomUserPreferences`
- Each category maps directly to macOS preference domains
- Type-safe with proper validation via Nix option system
- Automatically applies settings on `darwin-rebuild switch`

**Alternatives considered**:

- **Raw activation scripts**: More flexible but loses type safety, harder to maintain
- **CustomUserPreferences for everything**: Works but bypasses nix-darwin's type checking
- **Chosen approach**: Use typed `system.defaults` where available, fall back to `CustomUserPreferences` for unsupported settings

**Reference**: [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html#opt-system.defaults.dock.autohide)

______________________________________________________________________

### 2. Mapping bash `defaults write` to nix-darwin

**Decision**: Create systematic mapping table from bash domains to nix-darwin paths

**Rationale**:

- Most `defaults write com.apple.dock ...` → `system.defaults.dock.*`
- Most `defaults write NSGlobalDomain ...` → `system.defaults.NSGlobalDomain.*`
- Most `defaults write com.apple.finder ...` → `system.defaults.finder.*` or `CustomUserPreferences."com.apple.finder"`
- Some settings require nix-darwin equivalents, not direct mappings (e.g., `KeyRepeat` values differ in scale)
- Application-specific settings generally go in `CustomUserPreferences`

**Mapping Strategy**:

1. Check if setting exists in nix-darwin's typed options first
1. If not available, use `system.defaults.CustomUserPreferences."<domain>"`
1. For settings requiring `sudo` (system-wide), document in unresolved-migration.md
1. For deprecated settings, skip and document in deprecated-settings.md

**Common mappings**:

```nix
# Bash: defaults write com.apple.dock autohide -bool true
# Nix:  system.defaults.dock.autohide = true;

# Bash: defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Nix:  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;

# Bash: defaults write com.apple.finder ShowPathbar -bool true
# Nix:  system.defaults.finder.ShowPathbar = true;

# Bash: defaults write com.apple.ActivityMonitor ShowCategory -int 100
# Nix:  system.defaults.CustomUserPreferences."com.apple.ActivityMonitor".ShowCategory = 100;
```

**Alternatives considered**:

- **One-to-one bash command execution**: Loses Nix benefits, not declarative
- **Complete CustomUserPreferences**: Works but bypasses type checking for common settings
- **Chosen approach**: Typed options first, CustomUserPreferences as fallback

______________________________________________________________________

### 3. Settings that Cannot be Migrated

**Decision**: Document in `unresolved-migration.md` with three categories

**Rationale**:

- Some settings require `sudo` and system-wide modification (e.g., `nvram`, `/Library/Preferences/`)
- These may require nix-darwin activation scripts but need careful evaluation
- Some settings modify system services (`brew services`, `launchd`)
- Some are procedural (killall, mdutil) rather than declarative state

**Categories**:

1. **System-wide settings requiring elevated privileges**

   - Example: `sudo nvram boot-args="-v"` (verbose boot)
   - Example: `sudo defaults write /Library/Preferences/...`
   - Potential solution: nix-darwin `system.activationScripts`

1. **Service management**

   - Example: `brew services start borders`
   - Example: Startup applications (requires LaunchAgents)
   - Potential solution: nix-darwin services or launchd configuration

1. **Procedural operations**

   - Example: `killall Dock` (happens automatically on darwin-rebuild)
   - Example: `sudo mdutil -i on /` (one-time indexing)
   - Potential solution: Document as manual post-install steps

**Alternatives considered**:

- **Skip all complex settings**: Too restrictive, loses valuable configuration
- **Convert everything to activation scripts**: Loses declarative benefits
- **Chosen approach**: Evaluate each setting's intent, find declarative equivalent where possible, document unsupported

______________________________________________________________________

### 4. Topic-Based Module Organization

**Decision**: Create one Nix file per macOS preference domain with clear responsibility boundaries

**Rationale**:

- Aligns with macOS's own organization (Dock, Finder, Trackpad, etc.)
- Each file remains under 200 lines (constitutional requirement)
- Easy to locate settings: "Want to change Dock? → dock.nix"
- Application-specific settings belong to the application (Finder shortcuts in finder.nix)
- System-wide input settings (keyboard repeat rate) stay in keyboard.nix

**Module organization pattern**:

```nix
# modules/darwin/system/default.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ./dock.nix
    ./finder.nix
    ./trackpad.nix
    ./keyboard.nix
    ./screen.nix
    ./security.nix
    ./network.nix
    ./power.nix
    ./ui.nix
    ./accessibility.nix
    ./applications.nix
    ./system.nix
  ];
}

# modules/darwin/defaults.nix (becomes orchestrator)
{ config, lib, pkgs, ... }:
{
  imports = [
    ./system
  ];
}
```

**Best practices**:

- Each topic module includes header documentation
- Options grouped logically within the file
- Comments explain non-obvious settings
- Use `lib.mkDefault` for settings that hosts might override

**Alternatives considered**:

- **Single monolithic file**: Hard to navigate, violates modularity principle
- **Very fine-grained files** (one per setting): Too many files, overhead
- **Chosen approach**: One file per macOS domain, balances modularity with manageability

______________________________________________________________________

### 5. Handling Deprecated Settings

**Decision**: Skip migration, document in post-migration report with reasoning

**Rationale**:

- Deprecated settings may cause errors on newer macOS versions
- No value in preserving settings that no longer function
- Documentation provides audit trail and context for future reviewers
- Users can decide if they want to manually add back specific settings

**Identification criteria**:

- Settings for removed macOS features (e.g., Dashboard, which was removed in macOS Catalina)
- Settings with warnings in Apple documentation
- Settings that no longer have effect (verified by testing)

**Documentation format**:

```markdown
## Deprecated Setting: Dashboard Development Mode

**Original command**: `defaults write com.apple.dashboard devmode -bool true`
**Reason for exclusion**: Dashboard was removed in macOS 10.15 Catalina
**Impact**: None, feature no longer exists
**Alternative**: N/A
```

**Alternatives considered**:

- **Migrate everything, let macOS ignore**: Clutters configuration with dead code
- **Comment out in Nix**: Still clutters, unclear if intentional
- **Chosen approach**: Skip entirely, document separately

______________________________________________________________________

## Technology Stack Summary

**Primary Technologies**:

- **Nix 2.19+**: Configuration language and system
- **nix-darwin**: macOS system configuration framework
- **nixpkgs (darwin-specific modules)**: Package and option definitions

**Development Tools**:

- **darwin-rebuild**: Build and apply configurations
- **nix flake check**: Validate syntax and build
- **defaults read**: Verify applied settings at runtime
- **alejandra**: Nix code formatter

**Configuration Approach**:

- Declarative Nix expressions
- Type-safe option system
- Modular topic-based organization
- Git version control

______________________________________________________________________

## Migration Strategy

### Phase 1: Restructure Existing Configuration

1. Create `modules/darwin/system/` directory
1. Create topic-specific .nix files
1. Extract settings from current `defaults.nix` to appropriate topic files
1. Create `system/default.nix` to import all topic modules
1. Update `defaults.nix` to import `./system`
1. Test: `darwin-rebuild build` should succeed with identical behavior

### Phase 2: Analyze system.sh

1. Parse system.sh to extract all `defaults write` commands
1. Categorize by domain (dock, finder, keyboard, etc.)
1. Identify deprecated settings → document in deprecated-settings.md
1. Identify unsupported settings → document in unresolved-migration.md
1. Map supported settings to nix-darwin options

### Phase 3: Migrate Settings

1. For each topic file, add new settings from system.sh
1. Use typed options where available
1. Use CustomUserPreferences for application-specific settings
1. Test incrementally: apply, verify with `defaults read`, rollback if issues
1. Document edge cases and alternatives

### Phase 4: Validation

1. Compare system state before and after migration
1. Verify all settings apply correctly
1. Test on darwin hosts
1. Document final unresolved and deprecated settings

______________________________________________________________________

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing configurations | High | Incremental testing, maintain backwards compatibility during restructure |
| Settings don't apply correctly | Medium | Validate each setting with `defaults read`, compare before/after |
| Unsupported settings | Low | Document in unresolved-migration.md, provide alternatives |
| Performance degradation | Low | nix-darwin handles settings efficiently, no expected impact |
| Loss of deprecated settings | Low | Users weren't benefiting from them anyway, documented for transparency |

______________________________________________________________________

## Open Questions

**Q1**: Should we use activation scripts for settings requiring sudo?
**A1**: Only as last resort. Prefer declarative options. If required, document thoroughly and test carefully.

**Q2**: How to handle settings that conflict between defaults.nix and system.sh?
**A2**: system.sh settings take precedence (per specification). defaults.nix becomes import-only.

**Q3**: Should we preserve settings order from system.sh?
**A3**: No, organize logically by topic. Nix applies settings in dependency order regardless of definition order.

**Q4**: What if a setting exists in multiple bash domains (e.g., duplicates)?
**A4**: Consolidate to single definition in appropriate nix-darwin location. Document the consolidation.

______________________________________________________________________

## Next Steps

1. **Phase 1 Design**: Create data-model.md defining module structure and setting categorization
1. **Phase 1 Design**: Generate quickstart.md with testing and validation procedures
1. **Phase 2 Implementation**: Generate tasks.md with detailed restructuring and migration tasks
