# Research: Segregate Settings Directories

**Feature**: 039-segregate-settings-directories\
**Date**: 2026-01-11\
**Status**: Phase 0 - Research

## Research Questions

### Q1: How does the current discovery system load settings?

**Investigation**: Examined `system/shared/lib/discovery.nix` and `system/shared/lib/config-loader.nix`

**Current Mechanism**:

1. **Settings Discovery** (via `discoverModules`):

   - Recursively scans a settings directory for all `.nix` files
   - Excludes `default.nix` to prevent circular imports
   - Returns list of relative file paths (e.g., `["dock.nix", "desktop/gnome-core.nix"]`)

1. **Settings Loading** (via `config-loader.nix`):

   - `resolveSettings` function resolves setting names to absolute paths
   - Hierarchical search: system → families → shared
   - Uses `discoverWithHierarchy` for family support

1. **Auto-Discovery Pattern**:

   - Each settings directory has a `default.nix` that imports all modules:

   ```nix
   # system/nixos/settings/default.nix
   { config, lib, pkgs, ... }:
   let
     discovery = import ../../shared/lib/discovery.nix { inherit lib; };
   in {
     imports = map (file: ./${file}) (discovery.discoverModules ./.);
   }
   ```

1. **Context Handling** (Current - Fragile):

   - Settings use `lib.optionalAttrs (options ? home)` to check context
   - System-level settings skip when `options ? home` is true
   - User-level settings skip when `options ? home` is false
   - Problem: Guards are manual and frequently forgotten

**Answer**: Discovery scans entire settings directories recursively. Context is currently handled by manual guards within each module, not at the directory level.

______________________________________________________________________

### Q2: Where are settings currently imported in the build process?

**Investigation**: Examined `system/darwin/lib/darwin.nix` and platform libraries

**Import Locations**:

1. **System-Level Settings** (darwin/nixos):

   - Imported in platform library before home-manager
   - Example: `darwin.nix` imports `system/darwin/settings/default.nix`
   - Applied during `darwin-rebuild` or `nixos-rebuild`
   - No access to `home` option (system context only)

1. **Family Settings** (auto-installed):

   - System-level: `system/shared/family/{name}/settings/default.nix`
   - Imported when host declares `family = [...]`
   - Applied at system level (NixOS only currently)

1. **User-Level Settings** (home-manager):

   - Imported in `user/shared/lib/home.nix` via home-manager modules
   - Applied during home-manager activation
   - Has access to `home` option (home-manager context)

**Two-Stage Build** (Feature 036 - Standalone Home Manager):

- **Stage 1**: System build (darwin/nixos) - no `home` option
- **Stage 2**: Home-manager activation - has `home` option

**Answer**: Settings are imported at two distinct stages with different contexts. Current guards try to handle both contexts in the same file.

______________________________________________________________________

### Q3: How to modify discovery to filter by subdirectory based on context?

**Design Options**:

**Option A: Context Parameter in discoverModules**

```nix
# Add context parameter to discoverModules
discoverModules = { basePath, context ? "all" }:
  let
    subdirPath = 
      if context == "system" then basePath + "/system"
      else if context == "user" then basePath + "/user"
      else basePath;
  in
    # Scan subdirPath instead of basePath
```

**Option B: New Function `discoverModulesInContext`**

```nix
# New specialized function
discoverModulesInContext = { basePath, context }:
  let
    subdirPath = basePath + "/${context}";
  in
    if builtins.pathExists subdirPath
    then discoverModules subdirPath
    else [];
```

**Option C: Separate Functions Per Context**

```nix
# Most explicit approach
discoverSystemSettings = basePath: 
  if builtins.pathExists (basePath + "/system")
  then discoverModules (basePath + "/system")
  else [];

discoverUserSettings = basePath:
  if builtins.pathExists (basePath + "/user")
  then discoverModules (basePath + "/user")
  else [];
```

**Recommendation**: **Option B** - Clean separation, backward compatible with existing `discoverModules`, clear intent.

**Answer**: Add new `discoverModulesInContext` function to discovery.nix that scans `{basePath}/{context}/` subdirectory.

______________________________________________________________________

### Q4: How to categorize existing settings as system vs user level?

**Classification Criteria**:

**System-Level Settings** (requires system rebuild, modifies system state):

- Services, daemons, systemd units
- Boot configuration, kernel settings
- Network configuration, firewall rules
- Display managers (GDM, SDDM)
- Desktop environment installation (GNOME Shell packages)
- System-wide security policies
- User account creation
- Homebrew installation (darwin)

**User-Level Settings** (applies during home-manager, modifies user environment):

- Shell aliases, environment variables
- User preferences (dconf, gsettings)
- User-specific fonts, themes
- User dotfiles, config files
- GTK/Qt theme settings
- Keyboard shortcuts (user-level)
- Application-specific user preferences
- Password activation scripts

**Existing Settings Audit**:

| File | Current Location | Target Directory | Reason |
|------|-----------------|------------------|---------|
| `system/darwin/settings/dock.nix` | darwin/settings | **system** | Uses `system.defaults.dock` and `system.activationScripts` |
| `system/nixos/settings/security.nix` | nixos/settings | **system** | Firewall, sudo, polkit (system services) |
| `system/shared/family/gnome/settings/ui.nix` | gnome/settings | **user** | dconf/GTK settings (user preferences) |
| `system/shared/family/gnome/settings/desktop/gnome-core.nix` | gnome/settings | **system** | Installs GNOME Shell, GDM (system packages) |
| `system/shared/settings/password.nix` | shared/settings | **user** | Home-manager activation script with `options ? home` guard |
| `system/nixos/settings/locale.nix` | nixos/settings | **user** | User locale preferences |
| `system/darwin/settings/fonts.nix` | darwin/settings | **user** | User font configuration |

**Edge Cases**:

- **Locale settings**: Can be both system (timezone) and user (language) - split into two files
- **Keyboard settings**: System-level (hardware repeat rate) vs user-level (shortcuts) - split
- **Font settings**: System installation vs user selection - currently user-level only

**Answer**: Categorize by whether the setting modifies system state (requires rebuild) or user environment (home-manager). Some settings need splitting.

______________________________________________________________________

### Q5: What changes are needed to `default.nix` files in settings directories?

**Current Pattern**:

```nix
# system/darwin/settings/default.nix
{ config, lib, pkgs, ... }:
let
  discovery = import ../../shared/lib/discovery.nix { inherit lib; };
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

**New Pattern** (two default.nix files per settings directory):

```nix
# system/darwin/settings/system/default.nix
{ config, lib, pkgs, ... }:
let
  discovery = import ../../../shared/lib/discovery.nix { inherit lib; };
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

```nix
# system/darwin/settings/user/default.nix
{ config, lib, pkgs, ... }:
let
  discovery = import ../../../shared/lib/discovery.nix { inherit lib; };
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

**Where Imported**:

- `system/default.nix` → imported at system level (darwin/nixos build)
- `user/default.nix` → imported at home-manager level

**Changes Required**:

1. Create two `default.nix` files per settings directory
1. Update platform libraries to import correct `default.nix` based on context
1. Update family settings to have both subdirectories
1. Remove old top-level `default.nix` after migration

**Answer**: Each settings directory gets two `default.nix` files (one per subdirectory). Platform/family loaders import appropriate one based on build stage.

______________________________________________________________________

### Q6: How to handle hierarchical discovery with subdirectories?

**Current Hierarchical Search** (for apps):

- System → Families → Shared
- First match wins, no merging

**Settings Hierarchical Search** (with subdirectories):

**System-Level Settings**:

1. `system/{platform}/settings/system/`
1. `system/shared/family/{family1}/settings/system/`
1. `system/shared/family/{family2}/settings/system/`
1. `system/shared/settings/system/`

**User-Level Settings**:

1. `system/{platform}/settings/user/`
1. `system/shared/family/{family1}/settings/user/`
1. `system/shared/family/{family2}/settings/user/`
1. `system/shared/settings/user/`

**Implementation Strategy**:

Option 1: Modify `resolveSettings` in `config-loader.nix`:

```nix
resolveSettings = { system, settings, context ? "system" }:
  # Add /system or /user to paths
  map (settingPath: settingPath + "/${context}") standardPaths;
```

Option 2: New function `resolveSettingsInContext`:

```nix
resolveSettingsInContext = { system, settings, context }:
  # Build paths with subdirectory included
```

**Recommendation**: Modify existing `resolveSettings` to accept optional `context` parameter (backward compatible, defaults to existing behavior).

**Answer**: Extend hierarchical discovery to append `/{context}/` to each search path. Modify `resolveSettings` in config-loader.nix.

______________________________________________________________________

### Q7: What is the migration strategy for existing settings?

**Migration Phases**:

**Phase 1: Create Directory Structure**

- Create `system/` and `user/` subdirectories in all settings locations
- Create `default.nix` in each subdirectory
- Empty initially, no settings moved yet

**Phase 2: Categorize and Move Settings**

- Audit all 51 existing settings files (from glob results)
- Categorize each as system or user level
- Move files to appropriate subdirectory
- Split dual-purpose files (locale, keyboard) into separate files

**Phase 3: Update Discovery and Loaders**

- Add `discoverModulesInContext` to discovery.nix
- Update `config-loader.nix` to support context parameter
- Update platform libraries (darwin.nix, nixos.nix) to import system settings
- Update home-manager bootstrap to import user settings

**Phase 4: Remove Guards**

- Remove `lib.optionalAttrs (options ? home)` from all migrated settings
- Verify settings only contain their relevant context code
- Clean up any dual-context logic

**Phase 5: Cleanup**

- Remove old top-level settings `default.nix` files
- Update documentation (CLAUDE.md, constitution)
- Create user-facing guide in docs/features/

**Verification at Each Phase**:

- `nix flake check` passes
- `nix build .#darwinConfigurations.{user}-{host}.system` succeeds
- `nix build .#homeConfigurations.{user}.activationPackage` succeeds
- No context mismatch errors in any builds

**Answer**: 5-phase migration with verification at each step. Start with structure, move files, update discovery, remove guards, cleanup.

______________________________________________________________________

### Q8: Are there any settings that genuinely need both contexts?

**Investigation**: Reviewing settings that might need coordination between system and user.

**Potential Dual-Context Settings**:

1. **Locale** (`locale.nix`):

   - System: Timezone, system locale
   - User: Language preferences, regional formats
   - **Solution**: Split into two files

1. **Keyboard** (`keyboard.nix`):

   - System: Repeat rate, hardware settings
   - User: Shortcuts, user-specific mappings
   - **Solution**: Split into two files

1. **Fonts** (`fonts.nix`):

   - System: Font package installation
   - User: Font selection, rendering preferences
   - **Current**: Only user-level (packages via home-manager)
   - **Solution**: Keep in user/ (no system component needed)

1. **First-Boot** (`first-boot.nix`):

   - System: Creates systemd service
   - User: N/A (runs home-manager activation)
   - **Solution**: Move to system/

1. **Password** (`password.nix`):

   - System: Grants sudo NOPASSWD for chpasswd
   - User: Runs password update activation
   - **Current**: Only user-level with guard
   - **Solution**: Keep in user/, system sudo config elsewhere

**Answer**: No settings genuinely need to exist in both contexts. Settings that coordinate between levels should be split into separate files (system component + user component).

______________________________________________________________________

## Technical Decisions

### Decision 1: Subdirectory Naming

**Options**:

- `system/` and `user/`
- `sys/` and `usr/`
- `platform/` and `home/`

**Choice**: `system/` and `user/`

**Rationale**:

- Clear, self-documenting names
- Matches terminology in codebase (system-level vs user-level)
- Not abbreviated (maintainability)
- Avoids confusion with `/usr` filesystem path

______________________________________________________________________

### Decision 2: Discovery Function Design

**Options**:

- Modify existing `discoverModules`
- Add new `discoverModulesInContext`
- Create separate functions per context

**Choice**: Add new `discoverModulesInContext` function

**Rationale**:

- Backward compatible with existing code
- Clear intent from function name
- Allows gradual migration
- Doesn't complicate existing discovery function

______________________________________________________________________

### Decision 3: Default.nix Structure

**Options**:

- Single `default.nix` that checks context
- Two `default.nix` files (one per subdirectory)
- No `default.nix`, import files directly

**Choice**: Two `default.nix` files (one per subdirectory)

**Rationale**:

- Maintains existing auto-discovery pattern
- Each subdirectory is self-contained
- No conditional logic needed
- Platform libraries can import correct one based on stage

______________________________________________________________________

### Decision 4: Settings Categorization

**Principle**: Settings belong in `system/` if they:

- Modify system-level state (services, boot, network)
- Require system rebuild to apply
- Use darwin `system.*` options or NixOS system options

Settings belong in `user/` if they:

- Modify user environment or preferences
- Apply during home-manager activation
- Use `home.*`, `dconf.*`, `gtk.*`, or `xdg.*` options

**Edge Cases**: Split into separate files (e.g., `keyboard-system.nix` + `keyboard-user.nix`)

______________________________________________________________________

## Risks and Mitigations

### Risk 1: Breaking Existing Builds During Migration

**Severity**: High\
**Probability**: Medium

**Mitigation**:

- Incremental migration with phase-by-phase verification
- Keep old settings in place until new structure verified
- Test both system and home-manager builds at each phase
- Use feature branch, only merge when complete

______________________________________________________________________

### Risk 2: Miscategorizing Settings

**Severity**: Medium\
**Probability**: Low

**Mitigation**:

- Clear categorization criteria documented
- Review each setting individually
- Test builds to verify correct context
- Watch for `options ? home` errors during testing

______________________________________________________________________

### Risk 3: Missing Settings in Hierarchical Discovery

**Severity**: Medium\
**Probability**: Low

**Mitigation**:

- Verify all search paths include `/system/` or `/user/` suffix
- Test family settings hierarchical discovery
- Build configurations for multiple families (gnome, linux)

______________________________________________________________________

### Risk 4: Guard Removal Causing Immediate Errors

**Severity**: Low\
**Probability**: Medium

**Mitigation**:

- Remove guards AFTER directory structure in place
- Verify structural separation working first
- Remove guards as final step, not early step

______________________________________________________________________

## Open Questions

1. **Q**: Should `system/shared/settings/` have system/user subdirectories if no shared settings exist?
   **A**: Yes, create structure proactively for future settings. Password.nix moves to user/.

1. **Q**: How to handle settings that are platform-specific but user-level (e.g., darwin font.nix)?
   **A**: They go in `system/darwin/settings/user/` - platform determines directory tree, context determines subdirectory.

1. **Q**: Should discovery functions accept context as enum or string?
   **A**: String is simpler, matches existing patterns. Valid values: "system", "user".

1. **Q**: What happens if a settings subdirectory is empty?
   **A**: `discoverModulesInContext` returns empty list, `default.nix` has no imports. No error.

______________________________________________________________________

## Implementation Blockers

**None identified** - All technical questions resolved through research.

The implementation can proceed with Phase 1 (directory structure creation).

______________________________________________________________________

## Next Steps

1. ✅ **Research Complete** - All questions answered
1. **Phase 1 Design** - Create data model and contracts
1. **Phase 2 Implementation** - Execute migration phases
1. **Phase 3 Testing** - Verify builds and remove guards
1. **Phase 4 Documentation** - Update guides and constitution

Research phase is complete and ready to proceed to Phase 1 (Design).
