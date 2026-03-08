# Contract: System vs User Level Separation

**ID**: 004\
**Feature**: 028-gnome-family-system-integration\
**Status**: Required

## Behavior

Family **settings** MUST be imported at system level, while family **apps** MUST be imported at user level (home-manager).

## Contract Specification

### GIVEN

A host with GNOME family:

```nix
{
  name = "nixos-workstation";
  family = ["gnome"];
}
```

GNOME family has:

```
system/shared/family/gnome/
├── settings/
│   ├── desktop/gnome-core.nix    # System-level GNOME installation
│   └── wayland.nix                # System-level Wayland config
└── app/
    └── utility/gnome-tweaks.nix   # User-level optional tool
```

### WHEN

Platform lib builds system configuration

### THEN

1. **Family settings imported at SYSTEM level**:

   ```nix
   nixpkgs.lib.nixosSystem {
     modules = [
       # System level (before home-manager)
       .../system/shared/family/gnome/settings/default.nix
       
       # Home Manager comes after
       inputs.home-manager.nixosModules.home-manager
       {
         home-manager.users.${user} = {
           # User level
         };
       }
     ];
   }
   ```

1. **Family apps imported at USER level**:

   ```nix
   nixpkgs.lib.nixosSystem {
     modules = [
       # ...
       inputs.home-manager.nixosModules.home-manager
       {
         home-manager.users.${user} = {
           imports = [
             # User-selected apps
             .../system/shared/family/gnome/app/utility/gnome-tweaks.nix
           ];
         };
       }
     ];
   }
   ```

1. **Settings use system options**:

   ```nix
   # gnome/settings/desktop/gnome-core.nix (system-level)
   {
     services.xserver.desktopManager.gnome.enable = true;
     # NixOS system option (not home-manager)
   }
   ```

1. **Apps use home-manager options**:

   ```nix
   # gnome/app/utility/gnome-tweaks.nix (user-level)
   {
     home.packages = [ pkgs.gnome-tweaks ];
     # home-manager option (not NixOS)
   }
   ```

## Validation Tests

### Test 1: Settings Imported at System Level

```nix
# Evaluate system configuration (not home-manager)
nix eval .#nixosConfigurations.nixos-workstation.config.services.xserver.desktopManager.gnome.enable
```

**Expected**: `true` (GNOME enabled at system level)

### Test 2: Apps Imported at User Level

```nix
# Evaluate home-manager configuration
nix eval .#nixosConfigurations.nixos-workstation.config.home-manager.users.username.home.packages \
  | jq 'map(select(.name | contains("gnome-tweaks")))'
```

**Expected**: gnome-tweaks found in user packages (not system packages)

### Test 3: System Settings Available to All Users

```nix
# System with multiple users
{
  family = ["gnome"];
}

home-manager.users = {
  user1 = { };
  user2 = { };
};
```

**Expected**: Both users have access to GNOME desktop (system-wide)

### Test 4: User Apps Isolated Per User

```nix
# User 1 with gnome-tweaks
home-manager.users.user1 = {
  imports = [ .../gnome-tweaks.nix ];
};

# User 2 without gnome-tweaks
home-manager.users.user2 = {
  imports = [ ];
};
```

**Expected**:

- User 1 has gnome-tweaks
- User 2 does NOT have gnome-tweaks
- Per-user isolation

## Error Conditions

### Error 1: System Options in User-Level Module

**Condition**: App module tries to set system option

```nix
# gnome/app/utility/gnome-tweaks.nix (user-level)
{
  # ❌ WRONG: System option in user module
  services.xserver.desktopManager.gnome.enable = true;
}
```

**Expected Behavior**:

- Nix evaluation error (services.\* not available in home-manager)
- Or: Option silently ignored (home-manager doesn't have services.\*)

**Resolution**: Move to settings module

### Error 2: User Options in System-Level Module

**Condition**: Settings module tries to set user option

```nix
# gnome/settings/desktop/gnome-core.nix (system-level)
{
  # ❌ WRONG: User option in system module
  home.packages = [ pkgs.gnome-shell ];
}
```

**Expected Behavior**:

- Nix evaluation error (home.\* not available at system level)
- Error: "home is not defined"

**Resolution**: Move to app module or use system-level package installation

## Implementation Notes

### Platform Lib Pattern (NixOS)

```nix
# system/nixos/lib/nixos.nix
mkNixosConfig = { user, host, system ? "x86_64-linux" }: let
  # Load host data
  hostData = import ../host/${host} {};
  hostFamily = hostData.family or [];
  
  # Family settings defaults
  familySettingsDefaults =
    if hostFamily != []
    then discovery.autoInstallFamilyDefaults hostFamily repoRoot
    else [];
  
  # User data
  userData = import ../../../user/${user} {};
  resolvedUserApps = /* ... resolve apps ... */;
  userAppPaths = discovery.resolveApplications {
    apps = resolvedUserApps;
    families = hostFamily;
    # ...
  };
in
  nixpkgs.lib.nixosSystem {
    modules = [
      # SYSTEM LEVEL: Family settings
    ] ++ familySettingsDefaults ++ [
      
      # HOME MANAGER: User apps
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.users.${user} = {
          imports = [
            # User config
            ../../../user/${user}
          ] ++ userAppPaths;  # User-selected apps
        };
      }
    ];
  };
```

### Platform Lib Pattern (Darwin)

**Note**: Darwin is different - no system-level settings

```nix
# system/darwin/lib/darwin.nix
# Darwin imports BOTH family settings and apps in home-manager
# Because nix-darwin doesn't have true system-level config

nix-darwin.lib.darwinSystem {
  modules = [
    # ...
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager.users.${user} = {
        imports = [
          # User config
        ] ++ familyDefaults  # Both settings AND apps
          ++ userAppPaths;
      };
    }
  ];
}
```

**Why Different?**

- NixOS: True system vs user separation
- Darwin: Everything in home-manager (macOS limitation)

### Module Authoring Guidelines

**For Settings Modules** (`family/*/settings/*.nix`):

✅ **DO**:

- Use NixOS system options (`services.*`, `environment.*`, `systemd.*`)
- Configure system-wide services
- Install packages at system level (`environment.systemPackages`)
- Apply to all users

❌ **DON'T**:

- Use home-manager options (`home.*`, `programs.*`, `dconf.*`)
- Reference user-specific paths (`~/.config`)
- Try to configure per-user settings

**For App Modules** (`family/*/app/*.nix`):

✅ **DO**:

- Use home-manager options (`home.*`, `programs.*`, `dconf.*`)
- Install user packages (`home.packages`)
- Configure per-user settings
- Reference user paths (`~/.config`, `$HOME`)

❌ **DON'T**:

- Use NixOS system options (`services.*`)
- Try to configure system-wide services
- Assume system-level access

## Acceptance Criteria

- [ ] Family settings imported at system level (before home-manager)
- [ ] Family apps imported at user level (in home-manager)
- [ ] Settings use NixOS system options only
- [ ] Apps use home-manager options only
- [ ] System settings available to all users
- [ ] User apps isolated per user
- [ ] Clear separation between system and user configuration

## Design Rationale

**Why Separate System and User?**

1. **Security**: System services run as root, user apps as user
1. **Isolation**: Users can't interfere with each other
1. **Multi-User**: System desktop shared, apps per-user
1. **Rollbacks**: System rollback vs user rollback separate

**Why Settings at System Level?**

1. **Desktop Environment**: Needs system-wide installation
1. **Display Manager**: GDM runs before user login (system service)
1. **Wayland**: Display server is system-level
1. **All Users**: GNOME available to all users on system

**Why Apps at User Level?**

1. **User Choice**: Each user picks their tools
1. **Isolation**: User 1's apps don't affect User 2
1. **Preferences**: Per-user dconf settings
1. **Profiles**: Users can have different app sets

## Related Contracts

- 001: Family App Discovery
- 002: Family Settings Independence
- 005: Hierarchical App Resolution
