# Data Model: Dotfiles to Nix Configuration Migration

**Feature**: 001-dotfiles-migration\
**Created**: 2025-10-21\
**Purpose**: Define the logical entities, attributes, relationships, and validation rules for the Nix configuration system

______________________________________________________________________

## Overview

This data model describes the configuration entities that make up the declarative Nix-based system configuration. Unlike traditional application data models with databases, this represents the structure of Nix expressions, Home Manager modules, and configuration files.

______________________________________________________________________

## Core Entities

### 1. Flake

**Description**: The root configuration entity that defines all inputs (dependencies) and outputs (system configurations).

**Attributes**:

- description (string): Human-readable description
- inputs (set of Input): External dependencies
- outputs (set of Output): System configurations
- nixConfig (optional set): Nix daemon overrides

**Relationships**:

- Has many Input
- Has many Output (darwinConfigurations, nixosConfigurations)

**Validation**: Must have at least one output, all inputs pinned in flake.lock

**Location**: flake.nix

### 2. HostConfiguration

**Description**: Complete system configuration for a specific machine.

**Attributes**:

- hostname (string): Unique identifier
- system (string): Target architecture (x86_64-darwin, x86_64-linux, etc.)
- platform (enum): "darwin" OR "nixos"
- modules (list): Nix modules to include
- stateVersion (string): Compatibility version

**Relationships**:

- Belongs to Flake
- Has one HardwareConfiguration
- Has one UserConfiguration
- Uses many Module

**Location**: hosts/<hostname>/default.nix

### 3. UserConfiguration

**Description**: User account and environment via Home Manager.

**Attributes**:

- username (string): System username
- homeDirectory (string): Home path
- stateVersion (string): Home Manager version
- packages (list of Package): User packages
- programs (set of ProgramConfiguration): Program configs

**Location**: common/users/<username>/default.nix

### 4. Module

**Description**: Self-contained, reusable configuration unit.

**Attributes**:

- name (string): Module identifier
- category (enum): "core" OR "optional"
- platform (optional enum): "darwin" OR "linux" OR "all"
- options (set): Module options with types
- config (set): Configuration when enabled

**Categories**:

- Core: nix.nix, fonts.nix, shell.nix
- Optional: darwin/aerospace.nix, development/node.nix, etc.

**Location**: modules/core/ or modules/optional/

### 5. ProgramConfiguration

**Description**: Declarative configuration for a specific program.

**Attributes**:

- program (string): Program name (git, zsh, helix)
- enable (boolean): Whether to configure
- settings (set): Program-specific settings
- extraConfig (optional string): Additional config

**Examples**: Git (userName, userEmail), Zsh (plugins, aliases), Starship (settings)

**Location**: common/users/<username>/programs/<program>.nix

### 6. ShellConfiguration

**Description**: Modular shell config preserving dotfiles structure.

**Attributes**:

- shell (enum): "zsh" OR "bash" OR "fish"
- modules (ordered list): Numbered modules (10-90)
- aliases, functions, variables (sets)

**Zsh Modules**: 10.environment, 40.completion, 50.tools, 55.directory, 60.syntax, 62.history, 64.editor, 66.suggestions, 80.os

**Location**: common/users/<username>/programs/zsh/

### 7. Package

**Description**: Software package to install.

**Attributes**:

- pname (string): Package name
- source (enum): "nixpkgs" OR "nixpkgs-unstable"
- platform (optional): "darwin" OR "linux" OR "all"
- category: "cli-tool" OR "gui-app" OR "development"

**Examples**: zoxide, ripgrep, aerospace (darwin only), nodejs

### 8. Secret

**Description**: Encrypted sensitive data via sops-nix.

**Attributes**:

- name (string): Secret identifier
- path (string): Path in secrets.yaml
- owner, mode: File permissions

**Encryption**: Uses age, stored in secrets/secrets.yaml

### 9. Generation

**Description**: Versioned snapshot for rollback.

**Attributes**:

- number (integer): Sequential generation number
- timestamp (datetime): Creation time
- isCurrent (boolean): Active generation

______________________________________________________________________

## Entity Relationships

```
Flake
├── HostConfiguration
│   ├── HardwareConfiguration
│   ├── UserConfiguration
│   │   ├── ShellConfiguration
│   │   ├── ProgramConfiguration (many)
│   │   └── Package (many)
│   └── Module (many)
└── Secret (referenced by modules)
```

______________________________________________________________________

## Migration Mapping

| Dotfiles | Nix Entity | Location |
|----------|------------|----------|
| .zshrc + modules/ | ShellConfiguration | common/users/*/programs/zsh/ |
| .config/starship.toml | ProgramConfiguration | common/users/*/programs/starship.nix |
| .gitconfig | ProgramConfiguration | common/users/*/programs/git.nix |
| Brewfile | Package sets | common/users/*/packages.nix |
| Secrets | Secret (sops-nix) | secrets/secrets.yaml |

______________________________________________________________________

## Summary

12 core entities compose the Nix configuration:

1. Flake, 2. Input, 3. HostConfiguration, 4. HardwareConfiguration, 5. UserConfiguration,
1. Module, 7. ProgramConfiguration, 8. ShellConfiguration, 9. Package, 10. PackageSet,
1. Secret, 12. Generation

The model ensures declarative, reproducible, cross-platform configuration.
