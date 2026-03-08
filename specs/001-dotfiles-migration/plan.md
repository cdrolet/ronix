# Implementation Plan: Dotfiles to Nix Configuration Migration

**Branch**: `001-dotfiles-migration` | **Date**: 2025-10-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-dotfiles-migration/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Migrate existing Homebrew-based dotfiles repository to a declarative Nix configuration system supporting both macOS (via nix-darwin + Home Manager) and NixOS. The migration will preserve all 60+ applications, custom zsh configuration with modular loading system, editor configurations, and tool-specific dotfiles while adopting Nix flakes, Home Manager for user environment management, and sops-nix for secrets. The system must support cross-platform configuration sharing, single-command installation, atomic updates, and generational rollback capabilities.

## Technical Context

**Language/Version**: Nix expression language (Nix 2.19+), Shell scripts (Bash), Zsh configuration\
**Primary Dependencies**:

- nix-darwin (macOS system management)
- Home Manager (user environment management)
- sops-nix (secrets encryption)
- nixpkgs-unstable (latest packages)
- Determinate Systems Nix Installer (macOS installation)

**Storage**: File-based configuration (Nix expressions, YAML for secrets), Git repository\
**Testing**: `nix flake check` for syntax validation, VM testing for full system builds\
**Target Platform**: macOS 13+ (Ventura) and NixOS 23.11+\
**Project Type**: Configuration Management (follows constitutional directory structure)\
**Performance Goals**:

- Shell startup time \<200ms
- macOS installation \<30 minutes
- NixOS rebuild \<15 minutes
- Configuration changes applied \<2 minutes

**Constraints**:

- Must maintain 100% compatibility with existing dotfiles functionality
- Zero unencrypted secrets in version control
- Cross-platform builds must succeed without errors
- Rollback must be available for all changes

**Scale/Scope**:

- 60+ applications to migrate
- 2 platforms (macOS, NixOS)
- Single user initially (multi-user extensible)
- 8 zsh module categories with ~15 individual modules
- 10+ tool-specific configuration files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Declarative Configuration First

✅ **PASS** - All system configurations will be declared in Nix expressions. Migration eliminates imperative Homebrew installation scripts in favor of declarative flake.nix and module system.

### Principle II: Modularity and Reusability

✅ **PASS** - Design follows Blueprint directory structure (Constitution v1.5.0):

- `hosts/` for per-host configurations:
  - nix-darwin: work-macbook, home-macmini, darwin-dev
  - NixOS: nixos-dev
  - Nix-on-Linux: kali-pentest (Home Manager only)
  - Nix-on-Droid: pixel-phone (Android terminal environment)
- `modules/` for system-level modules (darwin/, nixos/, shared/)
- `home/` for Home Manager modules (programs/, services/, shell/)
- `profiles/` for composable configurations (work-restricted, personal, development, pentest, mobile, server)
- `overlays/` for package customizations
- `secrets/` for encrypted secrets (work/, personal/)

Placement rules adhered to (Blueprint standard):

- Host-specific hardware/networking → `hosts/<hostname>/`
- System-level modules → `modules/` (darwin/ for nix-darwin, nixos/ for NixOS only, shared/ for cross-platform)
- User environment modules → `home/` (usable by all platform types including Nix-on-Droid)
- Composable configurations → `profiles/`
- Nix-on-Linux hosts → Home Manager only, no system modules
- Nix-on-Droid hosts → Nix-on-Droid config only, no system modules

### Principle III: Documentation-Driven Development (NON-NEGOTIABLE)

✅ **PASS** - Requirements include:

- FR-035: Comprehensive installation instructions for both platforms
- FR-036: Directory structure and module organization documentation
- FR-037: Usage examples for common tasks
- FR-038: Migration path documentation
- FR-039: Rollback and recovery procedures
- Each module will include purpose, usage, options, examples, and dependencies

### Principle IV: Purity and Reproducibility

✅ **PASS** - Design ensures:

- All dependencies pinned in `flake.lock` (FR-030)
- No network access during build (Nix flakes standard)
- Reproducible builds across machines
- Hash-verified fixed-output derivations for external resources

### Principle V: Testing and Validation

✅ **PASS** - Testing strategy includes:

- Syntax validation via `nix flake check` before deployment (FR-027)
- Build verification in clean environments
- VM testing for full system validation
- Rollback procedures (FR-028, FR-029)
- SC-005: System builds successfully on both platforms

### Principle VI: Cross-Platform Compatibility (NON-NEGOTIABLE)

✅ **PASS** - Cross-platform requirements explicitly addressed:

- FR-031: Conditional logic for platform-specific configurations
- FR-032: Shared configurations across macOS and NixOS
- FR-033: Platform-specific features documented
- FR-034: Graceful handling of incompatible tools
- Use of `pkgs.stdenv.isDarwin` and `pkgs.stdenv.isLinux` for detection
- **Nix-on-Linux support** (Constitution v1.5.0): kali-pentest uses Home Manager only, preserving Kali's native tools
- **Nix-on-Droid support** (Constitution v1.5.0): pixel-phone uses Nix-on-Droid config for Android terminal environment, no root required

### Architectural Standards: Flakes as Entry Point (NON-NEGOTIABLE)

✅ **PASS** - Design mandates:

- FR-008: `flake.nix` at repository root
- FR-030: Dependencies pinned in `flake.lock`
- `nix flake update` for updates
- Latest flakes best practices

### Architectural Standards: Home Manager Integration (NON-NEGOTIABLE)

✅ **PASS** - Design requires:

- FR-010: Home Manager for user configurations in `common/users/`
- FR-020: Home Manager for user-level packages and dotfiles
- FR-006: Declarative shell environment via Home Manager
- FR-012: Tool configurations managed through Home Manager

### Architectural Standards: Directory Structure Standard

✅ **PASS** - FR-007 explicitly requires following constitutional structure. Project structure section below implements canonical layout.

### Development Standards

✅ **PASS** - Adhered to:

- Version Control: Git repository (Assumption #5), conventional commits
- Code Organization: Constitutional directory structure, meaningful names
- Nix Expression Style: Will use alejandra formatter, explicit attribute names, lib.mkOption with types
- Platform-Specific Code: Isolated with lib.mkIf, documented, tested on both platforms

### Quality Assurance

✅ **PASS** - Addressed:

- Pre-Deployment: FR-027 (test changes), syntax validation, platform testing
- Performance: SC-007 (shell \<200ms), SC-001/SC-002 (installation times), closure size monitoring
- Security: FR-022-025 (sops-nix), FR-024 (no unencrypted secrets), SC-011 (pre-commit hooks)

### Overall Constitution Compliance

✅ **ALL GATES PASSED** - Zero violations. Feature design is fully compliant with all constitutional principles (v1.5.0), architectural standards, development practices, and quality requirements.

**Platform Types Supported**:

1. nix-darwin (macOS): 3 hosts with full system configuration
1. NixOS (Linux): 1 host with complete declarative system
1. Nix-on-Linux (non-NixOS): 1 host with Home Manager only
1. Nix-on-Droid (Android): 1 host with terminal environment only

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nix-config/
├── flake.nix                           # Flake entry point with inputs/outputs
├── flake.lock                          # Pinned dependencies
├── .envrc                              # direnv integration (auto dev shell)
├── justfile                            # Command runner (install, update, check, fmt)
├── README.md                           # Main documentation
│
├── hosts/                              # Per-host configurations
│   ├── work-macbook/                   # Work MacBook Pro (nix-darwin, restricted)
│   │   ├── default.nix                 # Host entry point
│   │   ├── hardware-configuration.nix  # Hardware config
│   │   └── configuration.nix           # Host-specific settings
│   ├── home-macmini/                   # Home Mac Mini (nix-darwin, unrestricted)
│   │   ├── default.nix
│   │   ├── hardware-configuration.nix
│   │   └── configuration.nix
│   ├── nixos-dev/                      # NixOS development VM (full NixOS)
│   │   ├── default.nix
│   │   ├── hardware-configuration.nix
│   │   └── configuration.nix
│   ├── kali-pentest/                   # Kali Linux + Nix (Home Manager only)
│   │   ├── default.nix                 # Home Manager config only
│   │   └── home.nix                    # User environment config
│   ├── pixel-phone/                    # GrapheneOS Pixel (Nix-on-Droid)
│   │   ├── default.nix                 # Nix-on-Droid config
│   │   └── home.nix                    # Terminal environment config
│   └── darwin-dev/                     # Darwin development VM (nix-darwin, unrestricted)
│       ├── default.nix
│       ├── hardware-configuration.nix
│       └── configuration.nix
│
├── modules/                            # System-level modules
│   ├── darwin/                         # macOS-specific modules (nix-darwin)
│   │   ├── defaults.nix                # macOS system defaults
│   │   ├── aerospace.nix               # Tiling window manager (unrestricted hosts)
│   │   ├── borders.nix                 # Window borders (unrestricted hosts)
│   │   └── kitty.nix                   # Kitty terminal (work-macbook)
│   ├── nixos/                          # NixOS-specific modules (NOT for Nix-on-Linux)
│   │   ├── desktop.nix                 # Desktop environment
│   │   └── vm.nix                      # VM-specific settings
│   └── shared/                         # Cross-platform system modules
│       ├── nix.nix                     # Nix daemon, flakes, gc
│       ├── fonts.nix                   # Fonts configuration
│       └── users.nix                   # User accounts
│
├── home/                               # Home Manager modules (user environment)
│   ├── programs/                       # Program configurations
│   │   ├── git.nix                     # Git config
│   │   ├── starship.nix                # Starship prompt
│   │   ├── helix.nix                   # Helix editor
│   │   ├── zsh/                        # Zsh configuration
│   │   │   ├── default.nix
│   │   │   ├── environment.nix         # Environment variables (10.)
│   │   │   ├── completion.nix          # Completions (40.)
│   │   │   ├── tools.nix               # Tool configs (50.)
│   │   │   ├── directory.nix           # Directory nav (55.)
│   │   │   ├── syntax.nix              # Syntax highlighting (60.)
│   │   │   ├── history.nix             # History (62.)
│   │   │   ├── editor.nix              # Editor bindings (64.)
│   │   │   ├── suggestions.nix         # Auto-suggestions (66.)
│   │   │   └── os.nix                  # OS-specific (80.)
│   │   ├── ghostty.nix                 # Ghostty terminal (unrestricted)
│   │   ├── kitty.nix                   # Kitty terminal (work-macbook)
│   │   ├── atuin.nix                   # Shell history
│   │   ├── lazygit.nix                 # Git TUI
│   │   └── bat.nix                     # Cat replacement
│   ├── services/                       # User-level services
│   │   └── gpg-agent.nix               # GPG agent
│   └── shell/                          # Shell configurations
│       └── aliases.nix                 # Shell aliases
│
├── profiles/                           # Composable profile configurations
│   ├── work-restricted/                # Work environment with app restrictions
│   │   ├── default.nix                 # Profile aggregator
│   │   └── apps.nix                    # Approved apps only (kitty, no ghostty)
│   ├── personal/                       # Personal unrestricted environment
│   │   ├── default.nix
│   │   └── apps.nix                    # All apps (ghostty, aerospace, borders)
│   ├── development/                    # Development workstation profile
│   │   ├── default.nix
│   │   ├── languages.nix               # Node, Python, Go, Rust, Ruby
│   │   ├── tools.nix                   # Docker, Kubernetes, databases
│   │   └── editors.nix                 # Helix, Zed
│   ├── pentest/                        # Penetration testing profile (Kali)
│   │   ├── default.nix
│   │   └── tools.nix                   # Kali pentest tools
│   ├── mobile/                         # Mobile profile (Android/Nix-on-Droid)
│   │   ├── default.nix
│   │   └── terminal.nix                # Mobile-optimized CLI tools
│   └── server/                         # Server profile (minimal)
│       └── default.nix
│
├── overlays/                           # Nixpkgs package overlays
│   └── default.nix                     # Custom package modifications
│
├── secrets/                            # Encrypted secrets (sops-nix)
│   ├── work/                           # Work-related secrets
│   │   └── secrets.yaml
│   ├── personal/                       # Personal secrets
│   │   └── secrets.yaml
│   └── .sops.yaml                      # Sops configuration
│
└── .specify/                           # Specification artifacts
    ├── memory/
    │   └── constitution.md
    ├── templates/
    └── scripts/
```

**Structure Decision**: Pure Blueprint pattern (Constitution v1.5.0). This structure:

1. **Follows Blueprint Standard Exactly**:

   - hosts/, modules/, home/, profiles/, overlays/, secrets/
   - No custom organizational concepts
   - Community-recognized directory names

1. **Multi-Host Scenario Support** (4 platform types):

   - **work-macbook**: MacBook Pro (nix-darwin, restricted apps)
   - **home-macmini**: Mac Mini (nix-darwin, unrestricted)
   - **nixos-dev**: NixOS development VM (full NixOS)
   - **kali-pentest**: Kali Linux VM (Nix-on-Linux, Home Manager only)
   - **pixel-phone**: GrapheneOS Pixel (Nix-on-Droid, terminal environment)
   - **darwin-dev**: Darwin development VM (nix-darwin, unrestricted)

1. **Profile-Based Restrictions**:

   - **work-restricted**: Uses kitty, excludes unauthorized apps
   - **personal**: Full access to all apps
   - **development**: Complete dev environment (languages, tools, editors)
   - **pentest**: Security tools (via Home Manager on Kali)
   - **mobile**: Mobile-optimized terminal environment (Android)
   - **server**: Minimal server configuration

1. **Home Manager Modules** (home/):

   - programs/ for application configs
   - services/ for user services
   - shell/ for shell configuration
   - Preserves modular zsh structure (10-80 modules)

1. **System Modules** (modules/):

   - darwin/ for macOS-specific (aerospace, borders, kitty, defaults)
   - nixos/ for NixOS-specific (desktop, kali tools)
   - shared/ for cross-platform (nix, fonts, users)

**No conflicting views** - Single source of truth following Blueprint pattern.

## Blueprint Pattern Explanation

### Directory Structure (Constitution v1.3.0)

The structure follows the Nix community Blueprint pattern exactly:

1. **hosts/** - Per-host configurations

   - Contains complete configuration for each physical/virtual machine
   - Each host imports modules and profiles it needs
   - Hardware configuration auto-generated or manually specified

1. **modules/** - System-level reusable modules

   - **darwin/** - macOS-specific system modules
   - **nixos/** - NixOS-specific system modules
   - **shared/** - Cross-platform system modules
   - Imported by hosts as needed

1. **home/** - Home Manager modules (user environment)

   - **programs/** - Application configurations (git, zsh, helix, etc.)
   - **services/** - User-level services
   - **shell/** - Shell aliases and functions
   - Applied per-user, not per-host

1. **profiles/** - Composable configuration profiles

   - **work-restricted/** - Work laptop with app restrictions
   - **personal/** - Personal machines unrestricted
   - **development/** - Complete dev environment
   - **pentest/** - Security testing tools (Kali)
   - **server/** - Minimal server configuration
   - Hosts import profiles to get complete configurations

1. **overlays/** - Package customizations

   - Custom package versions or patches
   - Applied globally to nixpkgs

1. **secrets/** - Encrypted secrets (sops-nix)

   - **work/** - Work-related secrets
   - **personal/** - Personal secrets
   - Decrypted at runtime, never committed unencrypted

### Multi-Host Scenario

This configuration supports 6 distinct hosts across 4 platform types:

#### Platform Types

1. **nix-darwin** (macOS with system management)

   - work-macbook, home-macmini, darwin-dev
   - Full system + user configuration

1. **NixOS** (Linux with full NixOS)

   - nixos-dev
   - Complete declarative system

1. **Nix-on-Linux** (Non-NixOS Linux with Nix)

   - kali-pentest
   - Home Manager only, preserves native distro

1. **Nix-on-Droid** (Android with Nix)

   - pixel-phone
   - Terminal environment only, no root required

#### Host Configurations

1. **work-macbook** - Work MacBook Pro (nix-darwin)

   - Platform: macOS (nix-darwin)
   - App restrictions (kitty only, no ghostty/aerospace/borders)
   - Imports `profiles/work-restricted`
   - Secrets from `secrets/work/`

1. **home-macmini** - Home Mac Mini (nix-darwin)

   - Platform: macOS (nix-darwin)
   - Unrestricted (ghostty, aerospace, borders allowed)
   - Imports `profiles/personal` + `profiles/development`
   - Secrets from `secrets/personal/`

1. **nixos-dev** - NixOS development VM (full NixOS)

   - Platform: NixOS (full system config)
   - Linux development and experimentation
   - Imports `profiles/development`
   - Can run on work or home laptop

1. **kali-pentest** - Kali Linux VM (Nix-on-Linux)

   - Platform: Kali Linux (Home Manager only)
   - **Home Manager ONLY** - no NixOS modules
   - Preserves Kali's security tools and package management
   - Nix provides declarative user environment (shell, git, editors)
   - Imports `profiles/pentest` (Home Manager modules only)
   - Best of both: Kali's curated security packages + Nix's declarative dotfiles

1. **pixel-phone** - GrapheneOS Pixel (Nix-on-Droid)

   - Platform: Android (Nix-on-Droid)
   - **Nix-on-Droid config ONLY** - no system modules
   - Preserves GrapheneOS security and Android app ecosystem
   - Nix provides declarative terminal environment (shell, CLI tools, editors)
   - Imports `profiles/mobile` (Nix-on-Droid compatible modules only)
   - No root required, works within Android security model
   - Install via F-Droid app
   - Best of both: GrapheneOS privacy/security + Nix's declarative terminal config

1. **darwin-dev** - Darwin development VM (nix-darwin)

   - Platform: macOS (nix-darwin)
   - Unrestricted macOS development
   - Imports `profiles/personal` + `profiles/development`
   - Portable across work and home laptops

### Modern Tooling

**justfile** - Command runner:

```just
install-darwin HOST:
    darwin-rebuild switch --flake .#{{HOST}}

install-nixos HOST:
    sudo nixos-rebuild switch --flake .#{{HOST}}

update:
    nix flake update

check:
    nix flake check
```

**.envrc** - direnv integration:

```bash
use flake
```

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations found. This section is intentionally left empty.**

______________________________________________________________________

## Planning Artifacts Generated

### Phase 0: Research

**Status**: SKIPPED - No NEEDS CLARIFICATION markers in Technical Context

### Phase 1: Design & Contracts

**Status**: COMPLETED

1. **data-model.md**: ✅ Created

   - Defines 12 core entities (Flake, HostConfiguration, UserConfiguration, Module, etc.)
   - Entity relationships and validation rules
   - Migration mapping from dotfiles to Nix entities

1. **contracts/**: ✅ Created

   - flake-schema.md: Root flake.nix structure and requirements
   - module-schema.md: Standard module template and conventions
   - home-manager-schema.md: User configuration schema

1. **quickstart.md**: ✅ Created

   - Installation instructions (macOS and NixOS)
   - Daily operations (updates, configuration changes, package management)
   - Rollback procedures
   - Secrets management
   - Troubleshooting guide

1. **Agent Context**: ✅ Updated

   - CLAUDE.md created with Nix, Shell, and Configuration Management context

### Final Constitution Check

**Status**: ✅ PASSED - All constitutional requirements met (Constitution v1.3.0)

**Constitution Amendment**: v1.2.0 → v1.3.0 (MINOR)

- Simplified to pure Blueprint pattern (removed all custom organizational concepts)
- Structure now FIXED: hosts/, modules/, home/, profiles/, overlays/, secrets/
- Removed deprecated directories: users/, common/, devshells/, docs/, .github/
- Multi-host scenario documented: 5 hosts (work-macbook, home-macmini, nixos-dev, kali-pentest, darwin-dev)
- Profile-based restrictions: work-restricted, personal, development, pentest, server
- No conflicting views between constitution and implementation plan

______________________________________________________________________

## Next Steps

1. Run `/speckit.tasks` to generate detailed task breakdown
1. Begin implementation following task order
1. Reference quickstart.md for operational procedures
1. Use contracts/ for configuration schemas during development

______________________________________________________________________

## Implementation Readiness

✅ **READY FOR IMPLEMENTATION**

- All planning artifacts generated
- Constitution compliance verified
- Technical context fully specified
- Data model documented
- Configuration contracts defined
- Quickstart guide available
