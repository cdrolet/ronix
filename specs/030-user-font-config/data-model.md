# Data Model: User Font Configuration

**Feature**: 030-user-font-config
**Date**: 2025-12-26

## Entities

### FontConfiguration

User-declared font preferences in the user configuration.

```nix
fonts = {
  default = "berkeleymono-medium";
  packages = ["fira-code", "source-code-pro", "jetbrains-mono"];
  repositories = ["git@github.com:cdrolet/d-fonts.git"];
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| default | string | No | Default font for desktop (package name or private font name) |
| packages | list of string | No | Font package names from nixpkgs |
| repositories | list of string | No | SSH URLs to private font git repositories |

### DeployKey

SSH private key for accessing private font repositories.

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| sshKeys.fonts | string | User secrets | SSH private key content (via `<secret>` placeholder) |

**Deployed to**: `~/.ssh/id_fonts`

### FontPackageMapping

Maps package names to font family names for desktop configuration.

| Package Name | Font Family Name | Source |
|--------------|------------------|--------|
| fira-code | Fira Code | nixpkgs |
| jetbrains-mono | JetBrains Mono | nixpkgs |
| source-code-pro | Source Code Pro | nixpkgs |
| noto-fonts-mono | Noto Sans Mono | nixpkgs |
| berkeleymono-medium | Berkeley Mono | private repo |

### PrivateFontRepository

Git repository containing proprietary font files.

| Field | Type | Description |
|-------|------|-------------|
| url | string | SSH URL (git@github.com:user/repo.git) |
| localPath | string | Clone destination (~/.local/share/fonts/private/{repo-name}) |

## Directory Structure

### Linux Font Paths

```
~/.local/share/fonts/
├── nixpkgs/           # Symlinked from Nix store (automatic via home.packages)
└── private/           # Cloned from private repositories
    └── d-fonts/       # Repository name as subdirectory
        ├── font1.ttf
        └── font2.otf
```

### macOS Font Paths

```
~/Library/Fonts/
├── [nixpkgs fonts]    # Installed via home.packages
└── private/           # Cloned from private repositories
    └── d-fonts/
        ├── font1.ttf
        └── font2.otf
```

## State Transitions

### Private Font Repository States

```
[Not Configured] → sshKeys.fonts set → [Key Deployed]
                                              ↓
[Key Deployed] → activation runs → [Repository Cloned]
                                              ↓
[Repository Cloned] → subsequent activation → [Repository Updated (git pull)]
```

### Font Installation States

```
[Package Listed] → activation → [Package Installed via home.packages]
                                              ↓
[Package Installed] → font cache update → [Font Available to Applications]
```

## Validation Rules

1. **Package names**: Must exist in nixpkgs font packages (warning if not found)
1. **Repository URLs**: Must be valid SSH git URLs (git@host:user/repo.git format)
1. **Default font**: Must be in packages list OR in a private repository
1. **Deploy key**: Required only if repositories is non-empty

## Relationships

```
User Config
    │
    ├── fonts.default ──────────────────┐
    │                                   │
    ├── fonts.packages ─────────────────┼──→ Desktop Font Config (GNOME/macOS)
    │       │                           │
    │       └──→ home.packages          │
    │                                   │
    ├── fonts.repositories ─────────────┤
    │       │                           │
    │       └──→ Activation Script ─────┤
    │               │                   │
    │               └──→ Git Clone ─────┴──→ Font Files
    │                       │
    └── sshKeys.fonts ──────┘
            │
            └──→ ~/.ssh/id_fonts (Deploy Key)
```
