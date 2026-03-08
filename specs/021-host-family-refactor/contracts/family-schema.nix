# Family Structure Schema
# Feature: 021-host-family-refactor
# This file documents the expected structure of cross-platform families
# Families are cross-platform reusable configuration bundles in: platform/shared/family/{name}/
# They can be referenced by multiple hosts across different platforms
# Purpose: Share configs across platform boundaries (e.g., "linux" for nixos/kali, "gnome" for desktop environments)
# NOT for deployment contexts (work, home, gaming) - hosts are specific enough for that
# DIRECTORY STRUCTURE:
/**
* platform/shared/family/{name}/
* ├── app/
* │   ├── default.nix         # Optional: Auto-imported when family referenced
* │   ├── {appname}.nix       # Individual application modules
* │   └── {category}/
* │       └── {appname}.nix   # Categorized applications
* └── settings/
*     ├── default.nix         # Optional: Auto-imported when family referenced
*     └── {setting}.nix       # Individual setting modules
*/
# COMPONENT DESCRIPTIONS:
## app/ directory (Optional)
# Contains family-specific application modules
# Applications here are tier 2 in hierarchical search (platform → families → shared)
## app/default.nix (Optional)
# Auto-installed when host references this family
# Should import common applications for this family
# Example (linux family):
{
  imports = [
    ./htop.nix
    ./tmux.nix
    ./curl.nix
  ];
}
## settings/ directory (Optional)
# Contains family-specific system settings
# Settings here are tier 2 in hierarchical search (platform → families → shared)
## settings/default.nix (Optional)
# Auto-installed when host references this family
# Should import common settings for this family
# Example (gnome family):
{
  imports = [
    ./gtk-theme.nix
    ./gnome-extensions.nix
  ];
}
# VALIDATION RULES:
/**
* 1. Family name MUST be valid directory name (alphanumeric, dash, underscore)
* 2. app/default.nix if exists MUST be valid Nix module
* 3. settings/default.nix if exists MUST be valid Nix module
* 4. Individual modules MUST be <200 lines (constitutional requirement)
* 5. Individual modules MUST have header documentation
* 6. Families MUST be for cross-platform sharing, not deployment contexts
*/
# EXAMPLE FAMILIES:
## Example 1: Linux Family (shared by nixos, kali, ubuntu)
/**
* platform/shared/family/linux/
* ├── app/
* │   ├── default.nix         # Common Linux tools
* │   ├── htop.nix
* │   ├── tmux.nix
* │   └── curl.nix
* └── settings/
*     ├── default.nix         # Common Linux settings
*     └── systemd.nix
*/
## Example 2: GNOME Desktop Family
/**
* platform/shared/family/gnome/
* ├── app/
* │   ├── default.nix         # GNOME apps
* │   ├── nautilus.nix
* │   └── gnome-terminal.nix
* └── settings/
*     ├── default.nix         # GNOME settings
*     ├── gtk-theme.nix
*     └── gnome-extensions.nix
*/
## Example 3: Server Family (headless configs)
/**
* platform/shared/family/server/
* ├── app/
* │   ├── default.nix         # Server tools
* │   └── monitoring.nix
* └── settings/
*     ├── default.nix         # Server settings
*     └── ssh-hardening.nix
*/
# AUTO-INSTALLATION BEHAVIOR:
/**
* When a host references families in array:
* 1. For each family in order:
*    a. Platform lib checks if family/{name}/app/default.nix exists
*    b. If exists: auto-import (added to imports before module evaluation)
*    c. Platform lib checks if family/{name}/settings/default.nix exists
*    d. If exists: auto-import (added to imports before module evaluation)
* 2. Individual apps/settings available for hierarchical discovery
* 3. Discovery searches families in array order (first match wins)
*/
# TYPICAL USAGE PATTERNS:
/**
* DARWIN HOST (no families - macOS doesn't share cross-platform):
* {
*   name = "home-macmini-m4";
*   family = [];
*   applications = ["*"];
*   settings = ["default"];
* }
*/
/**
* NIXOS HOST (single family):
* {
*   name = "nixos-server";
*   family = ["linux"];              # References linux family
*   applications = ["*"];
*   settings = ["default"];
* }
*
* RESULT:
* - linux/app/default.nix auto-imported (htop, tmux, curl)
* - linux/settings/default.nix auto-imported (systemd)
* - Additional apps resolved via: platform/nixos/app → family/linux/app → shared/app
*/
/**
* NIXOS DESKTOP HOST (multiple families composed):
* {
*   name = "nixos-workstation";
*   family = ["linux", "gnome"];     # Compose linux + gnome
*   applications = ["git", "firefox"];
*   settings = ["default"];
* }
*
* RESULT:
* - linux/app/default.nix auto-imported
* - linux/settings/default.nix auto-imported
* - gnome/app/default.nix auto-imported
* - gnome/settings/default.nix auto-imported
* - git resolved via: platform/nixos → linux family → gnome family → shared
* - firefox resolved via: platform/nixos → linux family → gnome family → shared
*/
# INVALID EXAMPLES:
## ❌ Family name with spaces:
/**
* platform/shared/family/linux family/  # ERROR: Invalid directory name
*/
## ❌ Using family for deployment context (wrong purpose):
/**
* platform/shared/family/work/  # WRONG: Use host specificity instead
* platform/shared/family/home/  # WRONG: Families are for cross-platform, not deployment
* platform/shared/family/gaming/  # WRONG: Hosts are specific enough for this
*/
## ❌ Module exceeds 200 lines:
/**
* platform/shared/family/linux/app/tooling.nix
* # 250 lines of configuration
* # ERROR: Module exceeds constitutional limit
*/
# MIGRATION FROM OLD STRUCTURE:
/**
* OLD: platform/darwin/profiles/work/default.nix (had imports)
* NEW:
*   1. Host config: platform/darwin/host/work/default.nix (pure data)
*   2. Cross-platform config: platform/shared/family/* (if spans multiple platforms)
*
* Decision criteria:
* - Is it specific to deployment? → Keep in host config (work, home)
* - Is it shared across platforms? → Move to family (linux, gnome)
* - Is it macOS only? → Keep in platform/darwin, no family needed
*/

