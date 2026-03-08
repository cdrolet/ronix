# Quick Start: Host/Family Architecture

**Feature**: 021-host-family-refactor\
**Audience**: Repository maintainers and contributors\
**Purpose**: Examples showing common use cases for the new host/family architecture

## Overview

This guide provides practical examples for:

1. Creating a new host configuration (pure data)
1. Creating cross-platform families (reusable bundles)
1. Referencing families from hosts
1. Composing multiple families
1. Migrating from old profile structure to new host structure

**Key Concept**: Families are for **cross-platform sharing** (linux, gnome, server), NOT deployment contexts (work, home, gaming). Hosts are specific enough for deployment contexts.

______________________________________________________________________

## Example 1: Creating a Darwin Host (No Families)

**Use Case**: macOS host doesn't need cross-platform families.

**File**: `platform/darwin/host/home-macmini-m4/default.nix`

```nix
{ ... }:

{
  name = "home-macmini-m4";
  
  # Empty array - Darwin configs typically don't share cross-platform
  family = [];
  
  # Import all available apps
  applications = ["*"];
  
  # Import all darwin-specific settings
  settings = ["default"];
}
```

**Result**:

- Host built with all darwin apps
- All darwin settings applied
- No cross-platform families needed
- Simple and standalone

______________________________________________________________________

## Example 2: Creating a Shared Family (Linux)

**Use Case**: Create reusable "linux" family shared by nixos, kali, ubuntu.

**Directory Structure**:

```text
platform/shared/family/linux/
├── app/
│   ├── default.nix
│   ├── htop.nix
│   ├── tmux.nix
│   └── curl.nix
└── settings/
    ├── default.nix
    └── systemd.nix
```

**File**: `platform/shared/family/linux/app/default.nix`

```nix
{ ... }:

{
  # Auto-imported when host references "linux" family
  imports = [
    ./htop.nix
    ./tmux.nix
    ./curl.nix
  ];
}
```

**File**: `platform/shared/family/linux/app/htop.nix`

```nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.htop ];
  
  programs.htop = {
    enable = true;
    settings = {
      tree_view = true;
    };
  };
}
```

**File**: `platform/shared/family/linux/settings/default.nix`

```nix
{ ... }:

{
  imports = [
    ./systemd.nix
  ];
}
```

______________________________________________________________________

## Example 3: NixOS Host Using Linux Family

**Use Case**: NixOS workstation shares common linux family configs.

**File**: `platform/nixos/host/workstation/default.nix`

```nix
{ ... }:

{
  name = "nixos-workstation";
  
  # Reference linux family (shared with kali, ubuntu)
  family = ["linux"];
  
  # Additional apps beyond family defaults
  applications = [
    "git"
    "helix"
    "firefox"
  ];
  
  # Import all nixos-specific settings
  settings = ["default"];
}
```

**What Happens**:

1. Platform lib loads host config (pure data)
1. Sees `family = ["linux"]`, checks `platform/shared/family/linux/`
1. Auto-imports `linux/app/default.nix` (htop, tmux, curl)
1. Auto-imports `linux/settings/default.nix` (systemd)
1. Resolves additional apps via hierarchy:
   - "git": platform/nixos/app/ → family/linux/app/ → platform/shared/app/
   - "helix": (same search)
   - "firefox": (same search)
1. Resolves settings via hierarchy:
   - "default" imports all from platform/nixos/settings/

**Result**: Host has linux family defaults + nixos-specific + host additions

______________________________________________________________________

## Example 4: Kali Host Sharing Linux Family

**Use Case**: Kali pentesting host reuses same linux family as nixos.

**File**: `platform/kali/host/pentesting/default.nix`

```nix
{ ... }:

{
  name = "kali-pentesting";
  
  # Same linux family as nixos workstation
  family = ["linux"];
  
  # Pentesting-specific apps
  applications = [
    "nmap"
    "wireshark"
    "metasploit"
  ];
  
  settings = ["default"];
}
```

**Result**: Both nixos and kali hosts share common linux family configs (htop, tmux, systemd settings)

______________________________________________________________________

## Example 5: Composing Multiple Families

**Use Case**: NixOS desktop needs both linux base AND gnome desktop families.

**First, create GNOME family**:

**Directory**: `platform/shared/family/gnome/`

```text
platform/shared/family/gnome/
├── app/
│   ├── default.nix
│   ├── nautilus.nix
│   └── gnome-terminal.nix
└── settings/
    ├── default.nix
    └── gtk-theme.nix
```

**File**: `platform/shared/family/gnome/app/default.nix`

```nix
{ ... }:

{
  imports = [
    ./nautilus.nix
    ./gnome-terminal.nix
  ];
}
```

**Then, create host composing both families**:

**File**: `platform/nixos/host/desktop/default.nix`

```nix
{ ... }:

{
  name = "nixos-desktop";
  
  # Compose linux + gnome families (in order)
  family = ["linux", "gnome"];
  
  applications = [
    "git"
    "firefox"
  ];
  
  settings = ["default"];
}
```

**What Happens**:

1. Auto-imports `linux/app/default.nix` (htop, tmux, curl)
1. Auto-imports `linux/settings/default.nix` (systemd)
1. Auto-imports `gnome/app/default.nix` (nautilus, gnome-terminal)
1. Auto-imports `gnome/settings/default.nix` (gtk-theme)
1. App resolution: platform/nixos → family/linux → family/gnome → shared
1. "git" searches: nixos/app → linux/app → gnome/app → shared/app (first match wins)

**Result**: Host has linux base + gnome desktop + nixos-specific + host additions

______________________________________________________________________

## Example 6: Migration from Old Profile to New Host

**Old Structure** (profiles directory):

```nix
# platform/darwin/profiles/work/default.nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../shared/lib/host.nix
    ../../settings/default.nix
  ];
  
  host = {
    name = "work-laptop";
    display = "Work Laptop";
    platform = "aarch64-darwin";
  };
}
```

**New Structure** (pure data host):

```nix
# platform/darwin/host/work/default.nix
{ ... }:

{
  name = "work-laptop";
  family = [];  # Darwin doesn't share cross-platform
  applications = ["*"];
  settings = ["default"];  # Replaces import ../../settings/default.nix
}
```

**Migration Steps**:

1. Create new host directory: `platform/darwin/host/work/`
1. Create pure data config (no imports)
1. Set `family = []` (darwin is standalone)
1. Use `settings = ["default"]` to replace settings import
1. Delete old profile directory after verification

______________________________________________________________________

## Example 7: Settings Special Cases

**Case 1: Using "default" keyword** (imports all platform settings)

```nix
{ ... }:

{
  name = "simple-host";
  family = [];
  settings = ["default"];  # Imports ALL from platform/darwin/settings/
}
```

**Case 2: Specific settings** (selective imports)

```nix
{ ... }:

{
  name = "specific-host";
  family = [];
  settings = [
    "dock"
    "keyboard"
    "displays"
  ];  # Only imports these three
}
```

**Case 3: Invalid wildcard** (ERROR)

```nix
{ ... }:

{
  name = "invalid-host";
  settings = ["*"];  # ❌ ERROR: Wildcard not allowed for settings
}
```

**Why?**: Settings require explicit selection. Use "default" for all, or list specific ones.

______________________________________________________________________

## Example 8: Hierarchical Resolution in Action

**Setup**:

```text
platform/darwin/app/editor/helix.nix          (tier 1 - darwin-specific)
platform/shared/family/linux/app/helix.nix    (tier 2 - linux family)
platform/shared/app/editor/helix.nix          (tier 3 - generic)
```

**Host Config**:

```nix
# platform/darwin/host/dev/default.nix
{ ... }:

{
  name = "dev-machine";
  family = [];
  applications = ["helix"];
}
```

**Resolution**:

1. Search `platform/darwin/app/` → **FOUND** (tier 1)
1. Stop searching (first match wins)
1. Use darwin-specific helix configuration

**Host Config 2** (Linux with family):

```nix
# platform/nixos/host/workstation/default.nix
{ ... }:

{
  name = "nixos-workstation";
  family = ["linux"];
  applications = ["helix"];
}
```

**Resolution**:

1. Search `platform/nixos/app/` → not found
1. Search `family/linux/app/` → **FOUND** (tier 2)
1. Stop searching (first match wins)
1. Use linux family helix configuration

______________________________________________________________________

## Example 9: Creating Family Without Defaults

**Use Case**: Family provides individual modules but no auto-installation.

**Directory Structure**:

```text
platform/shared/family/server/
├── app/
│   ├── nginx.nix           # No default.nix
│   └── monitoring.nix
└── settings/
    └── ssh-hardening.nix   # No default.nix
```

**Host explicitly selects**:

```nix
{ ... }:

{
  name = "web-server";
  family = ["linux", "server"];  # Server family referenced
  
  # Must explicitly list what to import (no defaults to auto-import)
  applications = [
    "nginx"       # Resolved from server family
    "monitoring"  # Resolved from server family
  ];
  
  settings = [
    "ssh-hardening"  # Resolved from server family
  ];
}
```

**Result**: Families don't require default.nix files. Hosts can selectively use individual modules.

______________________________________________________________________

## Common Patterns

### Pattern 1: Darwin Host (Typical)

```nix
{
  name = "darwin-host";
  family = [];              # No cross-platform sharing
  applications = ["*"];     # All apps
  settings = ["default"];   # All darwin settings
}
```

### Pattern 2: Linux Base

```nix
{
  name = "linux-server";
  family = ["linux"];       # Cross-platform linux family
  applications = ["*"];
  settings = ["default"];
}
```

### Pattern 3: Linux Desktop (Composed)

```nix
{
  name = "linux-desktop";
  family = ["linux", "gnome"];  # Compose families
  applications = ["*"];
  settings = ["default"];
}
```

### Pattern 4: Selective Configuration

```nix
{
  name = "minimal";
  family = [];
  applications = ["git", "helix"];  # Specific apps only
  settings = ["keyboard"];           # Specific setting only
}
```

______________________________________________________________________

## Troubleshooting

**Q: Family not found error?**

- A: Check `platform/shared/family/{name}/` exists
- Verify family name spelling in host config

**Q: App not resolved?**

- A: Check if app exists in any tier (platform, families, shared)
- Verify file naming matches request (e.g., "git" needs git.nix)

**Q: Settings wildcard error?**

- A: Don't use `settings = ["*"]`
- Use `settings = ["default"]` or list specific settings

**Q: Which family is used for app resolution?**

- A: First match wins. Order: platform → family1 → family2 → ... → shared

**Q: Should I use family for work/home contexts?**

- A: No! Families are for cross-platform (linux, gnome). Hosts are specific enough for deployment contexts.

______________________________________________________________________

## Summary

- **Hosts**: Pure data configs (no imports) in `platform/{platform}/host/{name}/`
- **Families**: Cross-platform reusable bundles in `platform/shared/family/{name}/`
- **Purpose**: Families share configs across platforms (nixos, kali), NOT deployment contexts
- **Composition**: Use array to compose multiple families: `family = ["linux", "gnome"]`
- **Resolution**: First match wins in hierarchy: platform → families → shared
- **Settings**: Use "default" or list specific, never "\*"
- **Darwin**: Typically `family = []` (no cross-platform sharing needed)
