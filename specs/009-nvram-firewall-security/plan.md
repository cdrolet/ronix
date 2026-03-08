# Implementation Plan: NVRAM, Firewall, and Security Configuration

**Branch**: `009-nvram-firewall-security` | **Date**: 2025-10-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-nvram-firewall-security/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Migrate three higher-risk unresolved items from spec 002 after MVP validation in spec 008. Configures system-level security settings: firewall protection (enable, stealth mode, disable logging), login security (disable guest account, set per-host NetBIOS hostname), and NVRAM boot configuration (verbose mode, mute startup sound). Builds on helper library pattern from specs 006-008, requiring new helpers for system preferences and NVRAM operations.

## Technical Context

**Language/Version**: Nix 2.19+, Bash 5.x\
**Primary Dependencies**: nix-darwin, nixpkgs, macOS system utilities (defaults, nvram, socketfilterfw)\
**Storage**: Nix expressions in .nix files, system preferences in /Library/Preferences/, NVRAM firmware variables\
**Testing**: nix flake check, nix-instantiate, darwin-rebuild switch --dry-run, manual verification of system settings\
**Target Platform**: macOS (nix-darwin only)\
**Project Type**: Single project - system configuration\
**Performance Goals**: All activation scripts complete within 30 seconds during darwin-rebuild\
**Constraints**:

- Requires sudo for all system-level preferences (/Library/Preferences/)
- Firewall changes may require service restart
- NVRAM changes require reboot to take effect
- All operations must be idempotent
- Per-host hostname configurability required
  **Scale/Scope**: 3 user stories, 3+ new helper functions, 3 modules (firewall, security, nvram)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Core Principles Compliance

**I. Declarative Configuration First**: PASS

- All settings declared in Nix expressions
- No manual configuration steps required
- Activation scripts generated from declarative helper functions
- Per-host hostname configured via module options

**II. Modularity and Reusability**: PASS

- Helper functions in darwin library (`modules/darwin/lib/mac.nix`)
- Each module has single responsibility (firewall, security, nvram)
- Follows topic-based organization pattern from Feature 002
- Per-host configuration via nix-darwin options

**III. Documentation-Driven Development**: PASS

- Specification complete with all user stories documented
- Module headers will reference dotfiles source and security rationale
- Helper functions will include inline documentation
- Quickstart guide planned for Phase 1

**IV. Purity and Reproducibility**: PASS

- All commands use absolute paths
- No network access during build
- Idempotency ensures deterministic behavior
- Configuration state fully reproducible (except NVRAM requires reboot)

**V. Testing and Validation**: PASS

- Validation plan includes nix flake check
- Dry-run testing before deployment
- Idempotency testing (safe to rerun)
- Manual verification commands documented
- Security verification (port scan for stealth mode)

**VI. Cross-Platform Compatibility**: PASS (macOS only)

- Feature is darwin-specific by design
- No cross-platform considerations for system-level macOS security

### ✅ Architectural Standards Compliance

**Flakes as Entry Point**: PASS

- Uses existing flake structure
- No new inputs required

**Home Manager Integration**: PASS (N/A)

- No user-level configuration
- All settings are system-level

**Directory Structure Standard**: PASS

- Follows canonical structure exactly
- Helper library: `modules/darwin/lib/mac.nix` (extends existing from spec 006)
- Modules: `modules/darwin/system/` (established pattern)

### ✅ Development Standards Compliance

**Specification Management**: PASS

- Following specification-driven process
- No conflicts with existing specs
- Builds on spec 008 MVP foundation
- Documentation plan includes `docs/features/`

**Version Control Discipline**: PASS

- All changes committed to feature branch
- No secrets in scope

**Code Organization**: PASS

- Hierarchical directory structure maintained
- Modules under 200 lines each (estimated 50-100 lines per module)
- Three focused modules (firewall, security, nvram)

**Module Organization Pattern**: PASS

- Follows topic-based pattern from Feature 002
- Firewall, security, and NVRAM are distinct topics
- Each module has single responsibility
- Will include header documentation

**Activation Scripts and Helper Libraries**: PASS

- Uses helper library pattern from Feature 006
- New functions: `mkSystemDefaultsSet`, `mkNvramSet`, `mkFirewallRestart` (TBD in research)
- All operations idempotent with read-before-write pattern
- High-level declarative style

### 📋 Constitution Gates Summary

| Principle | Status | Notes |
|-----------|--------|-------|
| Declarative First | ✅ PASS | Fully declarative with per-host options |
| Modularity | ✅ PASS | Single-responsibility modules, shared helpers |
| Documentation | ✅ PASS | Comprehensive spec and planned docs |
| Purity | ✅ PASS | Idempotent, absolute paths, reproducible |
| Testing | ✅ PASS | Validation plan with security checks |
| Cross-Platform | ✅ PASS | Darwin-specific by design |
| Flakes | ✅ PASS | Uses existing flake structure |
| Directory Structure | ✅ PASS | Follows canonical layout |
| Module Organization | ✅ PASS | Topic-based pattern maintained |
| Helper Libraries | ✅ PASS | Extends Feature 006 pattern |

**Result**: All constitutional gates PASS. Proceed to Phase 0 research.

## Project Structure

### Documentation (this feature)

```text
specs/009-nvram-firewall-security/
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
│   └── mac.nix                    # EXTENDED: Add mkSystemDefaultsSet, mkNvramSet, helpers
│
└── system/
    ├── default.nix                # UPDATED: Import new modules
    ├── firewall.nix               # NEW: Firewall configuration
    ├── security.nix               # NEW: Login window & hostname security
    └── nvram.nix                  # NEW: NVRAM boot configuration
```

**Structure Decision**: Single project structure. All work happens in darwin system modules. Helper functions extend the existing `modules/darwin/lib/mac.nix` library created in Feature 006. Each module represents one functional topic (firewall, security, nvram) following the topic-based organization pattern from Feature 002.

## Implementation Phases

### Phase 0: Research (Technical Investigation)

**Objective**: Resolve technical unknowns before design phase

#### R1: System Defaults Command Research

**Questions**:

- How to read system-level defaults from /Library/Preferences/ (requires sudo)?
- What's the format for checking current values for idempotency?
- How to handle different value types (int, bool, string)?
- Do system defaults require process/service restarts?
- What happens if preference domain doesn't exist yet?

**Research Tasks**:

- Test `sudo defaults read /Library/Preferences/com.apple.alf globalstate`
- Test `sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1`
- Research value type handling (-int, -bool, -string)
- Test idempotency: read current value, compare, conditionally write
- Document error handling when domain/key doesn't exist
- Research file permissions on /Library/Preferences/ files

**Deliverable**: `research.md` section documenting system defaults behavior, read-before-write pattern, type handling, and error cases

#### R2: Firewall Configuration Research

**Questions**:

- Does firewall require service restart after defaults write?
- How to verify firewall is actually running after configuration?
- What's the command to restart firewall service?
- Are there dependencies between globalstate, stealthenabled, loggingenabled?
- How to test stealth mode is working (port scanning)?

**Research Tasks**:

- Test firewall configuration sequence: write defaults → restart service
- Research `/usr/libexec/ApplicationFirewall/socketfilterfw` commands
- Test `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on`
- Verify with `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate`
- Document whether defaults write alone is sufficient or if socketfilterfw required
- Research stealth mode verification (nmap or nc from another machine)

**Deliverable**: `research.md` section documenting firewall activation process, verification commands, and service restart requirements

#### R3: NVRAM Configuration Research

**Questions**:

- How to check current NVRAM values for idempotency?
- What's the output format of `nvram -p` or `nvram boot-args`?
- Are there any risks with NVRAM writes (corruption, boot failure)?
- How to communicate reboot requirement to users?
- What happens if NVRAM write fails (SIP, firmware password)?

**Research Tasks**:

- Test `nvram -p | grep boot-args` output parsing
- Test `sudo nvram boot-args="-v"` command
- Test `nvram boot-args` to read current value
- Research NVRAM write failure modes (SIP restrictions, firmware password)
- Document error handling strategies
- Test idempotency: check current value before writing
- Research SystemAudioVolume NVRAM variable

**Deliverable**: `research.md` section documenting NVRAM read/write patterns, error handling, reboot notification, and safety considerations

#### R4: NetBIOS Hostname Configuration

**Questions**:

- How to make NetBIOS hostname configurable per-host?
- What's the nix-darwin option structure for per-host configuration?
- How do host configs override module defaults?
- Are there hostname validation rules (length, characters)?

**Research Tasks**:

- Review nix-darwin module system for defining options
- Test hostname with special characters or spaces
- Research NetBIOS hostname requirements (max 15 chars, no special chars)
- Design module option: `system.defaults.smb.netbiosName`
- Document how hosts override in `hosts/<hostname>/default.nix`

**Deliverable**: `research.md` section documenting per-host configuration pattern, option definition, and hostname validation

#### R5: Helper Function Design Patterns

**Questions**:

- Should we create generic `mkSystemDefaultsSet` or specific helpers per domain?
- How to handle different value types in one helper?
- Should NVRAM helper be separate from system defaults helper?
- How to implement read-before-write pattern for multiple value types?

**Research Tasks**:

- Review existing helper patterns from spec 006-008
- Design `mkSystemDefaultsSet` signature with domain, key, value, type
- Design `mkNvramSet` signature for NVRAM variables
- Consider whether firewall needs custom helper or can use generic
- Document type coercion strategies (nix int → bash string → defaults -int)

**Deliverable**: `research.md` section documenting helper function design decisions, signatures, and implementation patterns

**Phase 0 Output**: Complete `research.md` with findings from R1-R5

______________________________________________________________________

### Phase 1: Design (Data Model & Contracts)

**Objective**: Define interfaces, data structures, and validation rules

#### D1: Helper Function Signatures

**mkSystemDefaultsSet Design** (NEEDS RESEARCH):

```nix
mkSystemDefaultsSet = {
  domain,       # string: preference domain (e.g., "/Library/Preferences/com.apple.alf")
  key,          # string: preference key (e.g., "globalstate")
  value,        # any: value to set (e.g., 1, false, "Workstation")
  type          # string: value type ("int", "bool", "string")
}: string;      # Returns: idempotent shell script string
```

**Behavior**:

- Read current value with `sudo defaults read <domain> <key>`
- Compare with desired value
- Only run `sudo defaults write <domain> <key> -<type> <value>` if different
- Handle missing domain/key gracefully
- Log actions for debugging
- Return exit code 0 (non-blocking)

**mkNvramSet Design** (NEEDS RESEARCH):

```nix
mkNvramSet = {
  variable,     # string: NVRAM variable name (e.g., "boot-args", "SystemAudioVolume")
  value         # any: value to set (e.g., "-v", 0)
}: string;      # Returns: idempotent shell script string with reboot notice
```

**Behavior**:

- Read current value with `nvram <variable>`
- Parse output to extract current value
- Only run `sudo nvram <variable>=<value>` if different
- Log actions with reboot notice
- Return shell script with user notification
- Return exit code 0 (non-blocking even on failure)

**mkFirewallRestart Design** (NEEDS RESEARCH - may not be needed):

```nix
mkFirewallRestart = {}: string;  # Returns: shell script to restart firewall
```

**Behavior**: TBD based on research

- May use `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on`
- Or may not be needed if defaults write is sufficient

#### D2: Module Configuration Options

**firewall.nix** (NEW):

```nix
options.system.defaults.firewall = {
  enable = mkOption {
    type = types.bool;
    default = true;
    description = "Enable macOS application firewall";
  };
  
  stealthMode = mkOption {
    type = types.bool;
    default = true;
    description = "Enable stealth mode (no response to ICMP ping or port scans)";
  };
  
  logging = mkOption {
    type = types.bool;
    default = false;
    description = "Enable firewall logging";
  };
};
```

**security.nix** (NEW):

```nix
options.system.defaults.loginwindow = {
  GuestEnabled = mkOption {
    type = types.bool;
    default = false;
    description = "Enable guest account access";
  };
};

options.system.defaults.smb = {
  netbiosName = mkOption {
    type = types.str;
    default = "Workstation";
    description = "NetBIOS hostname for SMB server identification (max 15 chars)";
  };
};
```

**nvram.nix** (NEW):

```nix
options.system.nvram = {
  bootArgs = mkOption {
    type = types.str;
    default = "-v";
    description = "NVRAM boot arguments (verbose boot). Requires reboot.";
  };
  
  muteStartupSound = mkOption {
    type = types.bool;
    default = true;
    description = "Mute startup sound (SystemAudioVolume=0). Requires reboot.";
  };
};
```

#### D3: Validation Rules

**System Defaults Validation**:

- Domain path must exist or be creatable in /Library/Preferences/
- Key must be valid preference key (alphanumeric + dots)
- Type must be one of: int, bool, string
- Value must match type (coercion allowed)
- Command must run with sudo or log error

**Firewall Validation**:

- globalstate: 0 (off) or 1 (on)
- stealthenabled: 0 (off) or 1 (on)
- loggingenabled: 0 (off) or 1 (on)
- Verify settings with defaults read after write
- Optional: verify with socketfilterfw --getglobalstate

**NVRAM Validation**:

- boot-args must be valid kernel flags string
- SystemAudioVolume must be integer 0-255 (0 = mute)
- Write must succeed or log error with SIP/firmware password note
- Verify with nvram read after write

**NetBIOS Hostname Validation**:

- Must be 1-15 characters (NetBIOS limitation)
- Must not contain spaces or special characters
- Should be alphanumeric + hyphens only
- Warn if truncation or sanitization needed

#### D4: Error Handling Strategy

**System Defaults Errors**:

- If read fails (domain missing): log info, attempt write anyway
- If write fails (permission denied): log error with sudo note, exit 0
- If value type mismatch: log error with type note, exit 0
- Don't block other activation scripts

**Firewall Errors**:

- If defaults write fails: log error, exit 0 (non-critical for boot)
- If service restart fails: log warning, continue
- If verification fails: log warning with manual fix instructions
- Don't block system boot/activation

**NVRAM Errors**:

- If read fails: log warning, attempt write anyway
- If write fails (SIP/firmware password): log error with instructions, exit 0
- If verification fails: log error with reboot reminder
- Include SIP disable instructions in error message
- Don't block activation (NVRAM is diagnostic, not critical)

**Hostname Validation Errors**:

- If too long: truncate to 15 chars, log warning
- If invalid chars: sanitize (remove/replace), log warning
- If empty: use default "Workstation", log warning
- Don't fail activation on hostname issues

**Phase 1 Outputs**:

- `data-model.md`: Entity definitions, helper function signatures, validation rules, error handling
- `quickstart.md`: Testing instructions, verification commands, troubleshooting guide, security verification

______________________________________________________________________

### Phase 2: Task Generation (NOT in /speckit.plan)

**Note**: Phase 2 is handled by the `/speckit.tasks` command, which reads the complete planning artifacts (spec.md, plan.md, research.md, data-model.md, quickstart.md) and generates a dependency-ordered task list in `tasks.md`.

**Expected Tasks** (preview, not exhaustive):

1. Research system defaults read/write patterns
1. Research firewall service restart requirements
1. Research NVRAM read/write patterns
1. Design helper function signatures
1. Extend `modules/darwin/lib/mac.nix` with `mkSystemDefaultsSet`
1. Extend `modules/darwin/lib/mac.nix` with `mkNvramSet`
1. Create `modules/darwin/system/firewall.nix` module
1. Create `modules/darwin/system/security.nix` module
1. Create `modules/darwin/system/nvram.nix` module
1. Update `modules/darwin/system/default.nix` to import new modules
1. Test helper functions with `nix-instantiate`
1. Test configuration with `darwin-rebuild switch --dry-run`
1. Verify firewall enabled and stealth mode active
1. Verify guest account disabled
1. Verify NetBIOS hostname set correctly per-host
1. Verify NVRAM boot-args set to "-v"
1. Verify SystemAudioVolume set to 0
1. Test idempotency (rerun activation scripts)
1. Test security: port scan to verify stealth mode
1. Test hostname per-host configuration
1. Update `specs/002-darwin-system-restructure/unresolved-migration.md`
1. Create `docs/features/009-nvram-firewall-security.md`
1. Commit all changes

______________________________________________________________________

## Risk Mitigation

### Technical Risks

**Risk**: Firewall configuration fails to apply or doesn't persist

- **Mitigation**: Research both defaults write and socketfilterfw approaches
- **Fallback**: Document manual System Settings configuration
- **Likelihood**: Low (standard macOS configuration method)

**Risk**: NVRAM writes fail due to SIP or firmware password

- **Mitigation**: Detect failure, provide clear error message with fix instructions
- **Fallback**: Document manual nvram command execution
- **Likelihood**: Medium (SIP/firmware password common in secure environments)

**Risk**: NVRAM boot-args cause boot failure

- **Mitigation**: Use safe flags only ("-v" is diagnostic, safe)
- **Fallback**: Document NVRAM reset procedure (Cmd+Option+P+R)
- **Likelihood**: Very low (verbose mode is safe)

**Risk**: NetBIOS hostname validation too strict or too lenient

- **Mitigation**: Research NetBIOS RFC requirements
- **Fallback**: Sanitize inputs with clear logging
- **Likelihood**: Low (well-defined specification)

**Risk**: System defaults require service restarts we don't know about

- **Mitigation**: Research each preference domain's requirements
- **Fallback**: Document logout/reboot requirements in module comments
- **Likelihood**: Medium (display settings precedent from spec 008)

### Security Risks

**Risk**: Firewall misconfiguration leaves system vulnerable

- **Mitigation**: Default to most secure settings (enable, stealth, no logging)
- **Fallback**: Include security verification in quickstart
- **Likelihood**: Very low (explicit configuration)

**Risk**: Guest account doesn't actually get disabled

- **Mitigation**: Verify on login screen after configuration
- **Fallback**: Document manual System Settings verification
- **Likelihood**: Very low (standard macOS setting)

### Architectural Risks

**Risk**: Helper functions become too complex with type handling

- **Mitigation**: Keep functions under 50 lines each
- **Fallback**: Split into type-specific helpers if needed
- **Likelihood**: Medium (multiple value types to handle)

**Risk**: Per-host configuration pattern unclear to users

- **Mitigation**: Document clearly in quickstart with examples
- **Fallback**: Provide per-host examples in quickstart
- **Likelihood**: Low (standard nix-darwin pattern)

______________________________________________________________________

## Success Criteria

### Phase 0 Complete When:

- [ ] All research questions answered in `research.md`
- [ ] System defaults read/write pattern documented
- [ ] Firewall service restart requirements known
- [ ] NVRAM read/write patterns documented
- [ ] Per-host configuration pattern designed
- [ ] Helper function signatures drafted

### Phase 1 Complete When:

- [ ] `data-model.md` defines all entities and signatures
- [ ] `quickstart.md` provides testing and security verification instructions
- [ ] Helper function interfaces finalized
- [ ] Module option structures defined
- [ ] Validation rules documented
- [ ] Error handling strategy defined

### Phase 2 Complete When:

- [ ] All tasks executed successfully
- [ ] All tests pass (see Acceptance Criteria in spec.md)
- [ ] Security verification complete (port scan shows stealth mode)
- [ ] Per-host hostname configuration tested on multiple hosts
- [ ] NVRAM configuration verified after reboot
- [ ] Documentation complete
- [ ] Feature merged to main branch

### Overall Feature Success:

All acceptance criteria from `spec.md` must pass:

1. Firewall enabled, stealth mode active, logging disabled
1. Guest account disabled on login screen
1. NetBIOS hostname configurable per-host and set correctly
1. NVRAM boot-args set to "-v" (verbose mode after reboot)
1. SystemAudioVolume set to 0 (silent startup after reboot)
1. All operations idempotent (safe to rerun)
1. Security verified (network port scan confirms stealth mode)

______________________________________________________________________

## Next Steps

1. **Continue with Phase 0 research** (automatic in /speckit.plan workflow)

   - Creates `research.md` with findings from R1-R5
   - Resolves all technical unknowns

1. **Continue with Phase 1 design** (automatic after Phase 0)

   - Creates `data-model.md` with entity definitions
   - Creates `quickstart.md` with testing instructions
   - Updates agent context (CLAUDE.md)

1. **Review planning artifacts** before implementation

   - Verify all technical unknowns resolved
   - Confirm helper function signatures
   - Validate error handling strategy
   - Review security implications

1. **Run `/speckit.tasks`** to generate implementation tasks

   - Creates `tasks.md` with dependency-ordered task list
   - Ready for `/speckit.implement` execution

______________________________________________________________________

## References

- **Parent Spec**: [002-darwin-system-restructure](../002-darwin-system-restructure/spec.md)
- **MVP Spec**: [008-008-complete-unresolved-migration](../008-008-complete-unresolved-migration/spec.md)
- **Helper Library Spec**: [006-reusable-helper-library](../006-reusable-helper-library/spec.md)
- **Module Organization Guide**: `docs/guides/module-organization.md`
- **Helper Library Guide**: `docs/guides/helper-libraries.md`
- **Constitution**: `.specify/memory/constitution.md`
- **Dotfiles Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`
- **macOS Security**: `/usr/libexec/ApplicationFirewall/socketfilterfw --help`
- **NVRAM**: `man nvram`
