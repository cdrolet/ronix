# Implementation Plan: Unresolved Migration MVP

**Branch**: `008-008-complete-unresolved-migration` | **Date**: 2025-10-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-008-complete-unresolved-migration/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Migrate three low-risk unresolved items from spec 002 using the helper library pattern established in specs 006-007. Creates power management (pmset), display configuration (HiDPI), and one-time setup operations using two new helper functions: `mkPmsetSet` and `mkOneTimeOperation`. MVP validates approach before tackling higher-risk items (NVRAM, firewall, security) in future specs.

## Technical Context

**Language/Version**: Nix 2.19+, Bash 5.x\
**Primary Dependencies**: nix-darwin, nixpkgs, macOS system utilities (pmset, defaults, chflags, mdutil)\
**Storage**: Nix expressions in .nix files, marker files for one-time operations\
**Testing**: nix flake check, nix-instantiate, darwin-rebuild switch --dry-run\
**Target Platform**: macOS (nix-darwin only)\
**Project Type**: Single project - system configuration\
**Performance Goals**: All activation scripts complete within 10 seconds during darwin-rebuild\
**Constraints**:

- Requires sudo for pmset and system-level defaults
- HiDPI setting may require logout/reboot to take effect
- All operations must be idempotent
  **Scale/Scope**: 3 user stories, 2 new helper functions, 3 modules (1 update + 2 new)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Core Principles Compliance

**I. Declarative Configuration First**: PASS

- All settings declared in Nix expressions
- No manual configuration steps required
- Activation scripts generated from declarative helper functions

**II. Modularity and Reusability**: PASS

- Helper functions in shared library (`modules/darwin/lib/mac.nix`)
- Each module has single responsibility (power, display, initial setup)
- Follows topic-based organization pattern from Feature 002
- Dependencies explicitly declared

**III. Documentation-Driven Development**: PASS

- Specification complete with all user stories documented
- Module headers will reference dotfiles source
- Helper functions will include inline documentation
- Quickstart guide planned for Phase 1

**IV. Purity and Reproducibility**: PASS

- All commands use absolute paths
- No network access during build
- Idempotency ensures deterministic behavior
- Configuration state fully reproducible

**V. Testing and Validation**: PASS

- Validation plan includes nix flake check
- Dry-run testing before deployment
- Idempotency testing (safe to rerun)
- Manual verification commands documented

**VI. Cross-Platform Compatibility**: PASS (macOS only)

- Feature is darwin-specific by design
- No cross-platform considerations for MVP
- Future specs may extend to NixOS equivalents

### ✅ Architectural Standards Compliance

**Flakes as Entry Point**: PASS

- Uses existing flake structure
- No new inputs required

**Home Manager Integration**: PASS (N/A)

- No user-level configuration in MVP
- All settings are system-level

**Directory Structure Standard**: PASS

- Follows canonical structure exactly
- Helper library: `modules/darwin/lib/mac.nix` (existing)
- Modules: `modules/darwin/system/` (established pattern)

### ✅ Development Standards Compliance

**Specification Management**: PASS

- Following specification-driven process
- No conflicts with existing specs
- Documentation plan includes `docs/features/`

**Version Control Discipline**: PASS

- All changes committed to feature branch
- No secrets in MVP scope

**Code Organization**: PASS

- Hierarchical directory structure maintained
- Modules under 200 lines each (estimated 50-100 lines per module)

**Module Organization Pattern**: PASS

- Follows topic-based pattern from Feature 002
- Power, display, and initial setup are distinct topics
- Each module has single responsibility
- Will include header documentation

**Activation Scripts and Helper Libraries**: PASS

- Uses helper library pattern from Feature 006
- Two new functions: `mkPmsetSet`, `mkOneTimeOperation`
- All operations idempotent
- High-level declarative style

### 📋 Constitution Gates Summary

| Principle | Status | Notes |
|-----------|--------|-------|
| Declarative First | ✅ PASS | Fully declarative with activation scripts |
| Modularity | ✅ PASS | Single-responsibility modules, shared helpers |
| Documentation | ✅ PASS | Comprehensive spec and planned docs |
| Purity | ✅ PASS | Idempotent, absolute paths, reproducible |
| Testing | ✅ PASS | Validation plan complete |
| Cross-Platform | ✅ PASS | Darwin-specific by design |
| Flakes | ✅ PASS | Uses existing flake structure |
| Directory Structure | ✅ PASS | Follows canonical layout |
| Module Organization | ✅ PASS | Topic-based pattern maintained |
| Helper Libraries | ✅ PASS | Extends Feature 006 pattern |

**Result**: All constitutional gates PASS. Proceed to Phase 0 research.

## Project Structure

### Documentation (this feature)

```text
specs/008-008-complete-unresolved-migration/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
modules/darwin/
├── lib/
│   └── mac.nix                    # EXTENDED: Add mkPmsetSet, mkOneTimeOperation
│
└── system/
    ├── default.nix                # UPDATED: Import new modules
    ├── power.nix                  # NEW: Power management (pmset)
    ├── screen.nix                 # UPDATED: Add HiDPI configuration
    └── initial-setup.nix          # NEW: One-time operations
```

**Structure Decision**: Single project structure. All MVP work happens in the darwin system modules. Helper functions extend the existing `modules/darwin/lib/mac.nix` library created in Feature 006. Each module represents one functional topic (power, display, initial setup) following the topic-based organization pattern from Feature 002.

## Implementation Phases

### Phase 0: Research (Technical Investigation)

**Objective**: Resolve technical unknowns before design phase

#### R1: pmset Command Research

**Questions**:

- How to check current pmset value before setting (idempotency)?
- What scopes are available (-a, -b, -c, -u)?
- How to verify setting persistence across reboots?
- Are there any pmset settings that conflict with standbydelay?
- What happens if pmset command fails?

**Research Tasks**:

- Read `man pmset` for command structure
- Test `pmset -g` output format for parsing current values
- Verify `sudo pmset -a standbydelay 86400` syntax
- Research error handling strategies for pmset failures
- Document scope flags: -a (all), -b (battery), -c (charger), -u (UPS)

**Deliverable**: `research.md` section documenting pmset behavior, parsing strategy, and idempotency check implementation

#### R2: HiDPI Configuration Research

**Questions**:

- How to check if HiDPI is already enabled (idempotency)?
- Does this setting require logout/reboot to take effect?
- What happens if no external display is connected?
- Are there any side effects on built-in displays?

**Research Tasks**:

- Test `defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled`
- Verify write command: `sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true`
- Research logout/reboot requirements
- Document user verification steps (System Settings > Displays)

**Deliverable**: `research.md` section documenting HiDPI behavior, verification method, and user impact

#### R3: One-Time Operation Patterns

**Questions**:

- Best pattern for marker files (location, naming, cleanup)?
- How to handle marker files across system reinstalls?
- Should marker files be per-user or system-wide?
- Alternative to marker files (check commands)?

**Research Tasks**:

- Review existing one-time operation patterns in nix-darwin
- Research marker file best practices (~/.nix-darwin-\* or /var/lib/nix-darwin/)
- Test `chflags nohidden ~/Library` idempotency (safe to rerun?)
- Test `sudo mdutil -i on /` idempotency
- Document check commands: `test ! -f ~/Library/.hidden`, `mdutil -s /`

**Deliverable**: `research.md` section documenting marker file strategy, check command patterns, and idempotency design

#### R4: Activation Script Ordering

**Questions**:

- Does one-time setup need to run before other activation scripts?
- Are there dependencies between power, display, and setup operations?
- How to handle activation script failures?

**Research Tasks**:

- Review nix-darwin activation script execution order
- Identify any dependencies (none expected for MVP)
- Document error handling strategies

**Deliverable**: `research.md` section documenting activation script ordering and dependencies

**Phase 0 Output**: Complete `research.md` with findings from R1-R4

______________________________________________________________________

### Phase 1: Design (Data Model & Contracts)

**Objective**: Define interfaces, data structures, and validation rules

#### D1: Helper Function Signatures

**mkPmsetSet Design**:

```nix
mkPmsetSet = {
  setting,      # string: pmset setting name (e.g., "standbydelay")
  value,        # string/int: setting value (e.g., 86400)
  scope ? "-a"  # string: scope flag (-a, -b, -c, -u)
}: string;      # Returns: shell script string
```

**Behavior**:

- Check current value with `pmset -g | grep <setting>`
- Only run `sudo pmset <scope> <setting> <value>` if different
- Log actions for debugging
- Return idempotent shell script

**mkOneTimeOperation Design**:

```nix
mkOneTimeOperation = {
  name,           # string: unique operation identifier (e.g., "unhide-library")
  command,        # string: shell command to run (e.g., "chflags nohidden ~/Library")
  checkCommand    # string: command to check if operation needed (e.g., "test ! -f ~/Library/.hidden")
}: string;        # Returns: shell script string
```

**Behavior**:

- Use marker file at `~/.nix-darwin-<name>-complete`
- Check marker file existence first
- If marker exists, skip operation
- Otherwise, run checkCommand to verify if operation needed
- Run command if checkCommand indicates operation needed
- Create marker file on success
- Log all steps for debugging
- Return idempotent shell script

#### D2: Module Configuration Options

**power.nix** (NEW):

```nix
# No options defined - uses helper library directly in activation script
# Future: Could expose options.darwin.power.standbyDelay for user override
```

**screen.nix** (UPDATE):

```nix
# Add to existing screen.nix configuration
# No new options - uses helper library in activation script
# Future: Could expose options.darwin.screen.enableHiDPI boolean
```

**initial-setup.nix** (NEW):

```nix
# No options defined - uses helper library directly in activation script
# Future: Could expose options.darwin.initialSetup.operations list
```

#### D3: Validation Rules

**pmset Validation**:

- Setting name must be valid pmset parameter
- Value must be appropriate type for setting (int for standbydelay)
- Scope must be one of: -a, -b, -c, -u
- Command must succeed or log error

**HiDPI Validation**:

- Setting must be boolean (true/false)
- Plist file must be writable (requires sudo)
- Verify with `defaults read` after write

**One-Time Operations Validation**:

- Marker file must be in user home directory
- Check command must return valid exit code
- Command must be safe to run multiple times

#### D4: Error Handling Strategy

**pmset Errors**:

- If current value check fails: log warning, attempt set anyway
- If set command fails: log error, continue (non-critical)
- Exit code 0 regardless (don't block activation)

**HiDPI Errors**:

- If read check fails: log warning, attempt write anyway
- If write fails: log error, continue (non-critical)
- Exit code 0 regardless

**One-Time Operation Errors**:

- If marker file can't be created: log error, skip operation
- If check command fails: log warning, skip operation
- If main command fails: log error, don't create marker
- Exit code 0 regardless (don't block other activations)

**Phase 1 Outputs**:

- `data-model.md`: Entity definitions, helper function signatures, validation rules
- `quickstart.md`: Testing instructions, verification commands, troubleshooting guide

______________________________________________________________________

### Phase 2: Task Generation (NOT in /speckit.plan)

**Note**: Phase 2 is handled by the `/speckit.tasks` command, which reads the complete planning artifacts (spec.md, plan.md, research.md, data-model.md, quickstart.md) and generates a dependency-ordered task list in `tasks.md`.

**Expected Tasks** (preview, not exhaustive):

1. Extend `modules/darwin/lib/mac.nix` with `mkPmsetSet` function
1. Extend `modules/darwin/lib/mac.nix` with `mkOneTimeOperation` function
1. Create `modules/darwin/system/power.nix` module
1. Update `modules/darwin/system/screen.nix` with HiDPI configuration
1. Create `modules/darwin/system/initial-setup.nix` module
1. Update `modules/darwin/system/default.nix` to import new modules
1. Test helper functions with `nix-instantiate`
1. Test configuration with `darwin-rebuild switch --dry-run`
1. Verify pmset standby delay setting
1. Verify HiDPI modes available
1. Verify Library folder visible
1. Verify Spotlight indexing enabled
1. Test idempotency (rerun activation scripts)
1. Update `specs/002-darwin-system-restructure/unresolved-migration.md`
1. Create `docs/features/008-unresolved-migration-mvp.md`
1. Commit all changes

______________________________________________________________________

## Risk Mitigation

### Technical Risks

**Risk**: pmset setting doesn't persist across reboots

- **Mitigation**: Test on real hardware with reboot
- **Fallback**: Document manual verification in quickstart
- **Likelihood**: Very low (pmset designed for persistence)

**Risk**: HiDPI setting requires logout but isn't documented

- **Mitigation**: Test on system with external display
- **Fallback**: Add logout requirement to module comments
- **Likelihood**: Medium (common for display settings)

**Risk**: Marker files deleted by user or system cleanup

- **Mitigation**: Use check commands as fallback
- **Fallback**: Operations are safe to rerun anyway
- **Likelihood**: Low (hidden files rarely cleaned)

**Risk**: Activation scripts fail silently

- **Mitigation**: Use `mkLoggedCommand` from shared library
- **Fallback**: Manual verification commands in quickstart
- **Likelihood**: Low (comprehensive error logging)

### Architectural Risks

**Risk**: Helper functions become too complex

- **Mitigation**: Keep functions under 30 lines each
- **Fallback**: Refactor into sub-functions if needed
- **Likelihood**: Low (MVP scope is minimal)

**Risk**: Module organization doesn't scale

- **Mitigation**: Follow topic-based pattern from Feature 002
- **Fallback**: Refactor into sub-modules if >200 lines
- **Likelihood**: Very low (each module ~50-100 lines)

______________________________________________________________________

## Success Criteria

### Phase 0 Complete When:

- [ ] All research questions answered in `research.md`
- [ ] pmset parsing strategy documented
- [ ] HiDPI behavior verified
- [ ] Marker file pattern decided
- [ ] Activation script ordering understood

### Phase 1 Complete When:

- [ ] `data-model.md` defines all entities and signatures
- [ ] `quickstart.md` provides testing instructions
- [ ] Helper function interfaces finalized
- [ ] Validation rules documented
- [ ] Error handling strategy defined

### Phase 2 Complete When:

- [ ] All tasks executed successfully
- [ ] All tests pass (see Acceptance Criteria in spec.md)
- [ ] Documentation complete
- [ ] Feature merged to main branch

### Overall Feature Success:

All acceptance criteria from `spec.md` must pass:

1. Helper functions created and documented
1. Modules implemented using helper library
1. Testing complete with verification
1. Documentation updated

______________________________________________________________________

## Next Steps

1. **Run `/speckit.plan` command** to execute Phase 0 research workflow

   - Creates `research.md` with findings from R1-R4
   - Agent will research pmset, HiDPI, marker files, and activation ordering

1. **Continue with Phase 1** (automatic after Phase 0)

   - Creates `data-model.md` with entity definitions
   - Creates `quickstart.md` with testing instructions

1. **Review planning artifacts** before implementation

   - Verify all technical unknowns resolved
   - Confirm helper function signatures
   - Validate error handling strategy

1. **Run `/speckit.tasks`** to generate implementation tasks

   - Creates `tasks.md` with dependency-ordered task list
   - Ready for `/speckit.implement` execution

______________________________________________________________________

## References

- **Parent Spec**: [002-darwin-system-restructure](../002-darwin-system-restructure/spec.md)
- **Helper Library Spec**: [006-reusable-helper-library](../006-reusable-helper-library/spec.md)
- **Dock Migration**: [007-007-complete-dock-migration](../007-007-complete-dock-migration/spec.md)
- **Module Organization Guide**: `docs/guides/module-organization.md`
- **Helper Library Guide**: `docs/guides/helper-libraries.md`
- **Constitution**: `.specify/memory/constitution.md`
- **Dotfiles Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`
