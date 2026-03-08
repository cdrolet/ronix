# Quickstart: Repository Restructure - User/System Split

**Feature**: 010-repo-restructure\
**Date**: 2025-10-31\
**Audience**: Developers implementing or using the new structure

## Prerequisites

- Nix 2.19+ installed with flakes enabled
- nix-darwin (macOS) or NixOS
- Git repository cloned locally
- Basic understanding of Nix modules and flakes

## Quick Start (After Migration)

### Install a System Configuration

```bash
# List available users
just list-users

# List available profiles for your platform
just list-profiles

# Install configuration
just install <user> <profile>

# Example: Install cdrokar's home profile on macOS
just install cdrokar home
```

### Directory Navigation

```
nix-config/
├── user/              # User configurations
│   └── cdrokar/       # Your user directory
│       └── default.nix
├── system/            # System configurations
│   ├── shared/        # Cross-platform
│   │   └── app/       # Universal apps
│   ├── darwin/        # macOS-specific
│   │   └── app/       # macOS apps
│   └── nixos/         # NixOS-specific
└── secrets/           # Encrypted secrets (agenix)
```

## Common Tasks

### Adding an Application

#### 1. Create app module

```bash
# For cross-platform app
touch system/shared/app/dev/my-app.nix

# For macOS-specific app
touch system/darwin/app/my-mac-app.nix
```

#### 2. Write app configuration

```nix
# system/shared/app/dev/my-app.nix
{ config, lib, pkgs, ... }:

{
  # Dependencies (if any)
  imports = [
    ../tools/some-dependency.nix
  ];
  
  # Install package
  home.packages = [ pkgs.my-app ];
  
  # Configure program
  programs.my-app = {
    enable = true;
    settings = {
      # ... configuration
    };
  };
  
  # Shell aliases (namespaced!)
  programs.zsh.shellAliases = {
    ma = "my-app";
    mas = "my-app --some-flag";
  };
}
```

#### 3. Import in user config

```nix
# user/cdrokar/default.nix
{
  imports = [
    ../shared/lib/home.nix
    ../../system/shared/app/dev/my-app.nix  # Add this line
    # ... other apps
  ];
  
  user = {
    name = "cdrokar";
    email = "cdrokar@example.com";
    fullName = "Charles Drokar";
  };
}
```

#### 4. Rebuild

```bash
just install cdrokar home
```

### Adding a New User

#### 1. Create user directory

```bash
mkdir -p user/newuser
touch user/newuser/default.nix
```

#### 2. Write user configuration

```nix
# user/newuser/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ../shared/lib/home.nix  # Required!
    ../../system/shared/app/shell/zsh.nix
    ../../system/shared/app/editor/helix.nix
    # ... select your apps
  ];
  
  user = {
    name = "newuser";
    email = "newuser@example.com";
    fullName = "New User";
  };
}
```

#### 3. Add to flake.nix

```nix
# flake.nix
{
  validUsers = [ "cdrokar" "cdrolet" "cdrixus" "newuser" ];  # Add here
  
  darwinConfigurations = {
    newuser-home = mkDarwinConfig "newuser" "home";  # Add config
  };
}
```

#### 4. Install

```bash
just install newuser home
```

### Creating a New Profile

#### 1. Create profile directory

```bash
mkdir -p system/darwin/profiles/custom
touch system/darwin/profiles/custom/default.nix
```

#### 2. Write profile configuration

```nix
# system/darwin/profiles/custom/default.nix
{ config, lib, pkgs, ... }:

{
  _profileType = "complete";  # Required metadata
  
  imports = [
    ../../settings/default.nix  # Platform settings
    ../../../shared/app/shell/zsh.nix
    ../../../shared/app/editor/helix.nix
    ../../app/aerospace.nix
    # ... explicit app list
  ];
  
  # Profile-specific overrides
  system.defaults.dock = {
    autohide = true;
    show-recents = false;
  };
}
```

#### 3. Add to flake.nix

```nix
# flake.nix
{
  validProfiles = {
    darwin = [ "home" "work" "custom" ];  # Add here
  };
  
  darwinConfigurations = {
    cdrokar-custom = mkDarwinConfig "cdrokar" "custom";  # Add config
  };
}
```

#### 4. Install

```bash
just install cdrokar custom
```

### Adding a Secret

#### 1. Generate age key (if not done)

```bash
# User key
age-keygen -o ~/.age-key.txt

# Note the public key (age1...)
```

#### 2. Add key to secrets.nix

```nix
# secrets/secrets.nix
let
  cdrokar = "age1...your-public-key...";
  # ... other keys
in
{
  "users/cdrokar/api-token.age".publicKeys = [ cdrokar ];
}
```

#### 3. Encrypt secret

```bash
# Create temporary plaintext file
echo "my-secret-token" > /tmp/token.txt

# Encrypt with agenix
agenix -e secrets/users/cdrokar/api-token.age
# (paste content from /tmp/token.txt, save, exit)

# Delete plaintext
rm /tmp/token.txt
```

#### 4. Reference in app module

```nix
# system/shared/app/some-app.nix
{
  age.secrets.api-token = {
    file = ../../../secrets/users/cdrokar/api-token.age;
    owner = "cdrokar";
  };
  
  programs.some-app = {
    tokenFile = config.age.secrets.api-token.path;
  };
}
```

## Development Workflow

### Before Making Changes

```bash
# Create feature branch
git checkout -b feature/my-change

# Validate current state
just check
```

### After Making Changes

```bash
# Format Nix files
just format

# Check syntax and build
just check

# Test build (doesn't install)
just build <user> <profile>

# Install if build succeeds
just install <user> <profile>

# Commit changes
git add .
git commit -m "feat: add my-app to user config"
```

### Troubleshooting

#### Circular Dependency Error

```
error: infinite recursion encountered
```

**Solution**: Check imports in your app modules. You likely have A → B → A.

```nix
# Bad: app-a.nix imports app-b.nix AND app-b.nix imports app-a.nix

# Good: Split into base + enhanced
# app-base.nix (no imports)
# app-enhanced.nix (imports app-base.nix + other deps)
```

#### Invalid User/Profile Error

```
Error: Invalid user 'typo'
Valid users: cdrokar, cdrolet, cdrixus
```

**Solution**: Fix typo or add user to `validUsers` in flake.nix

#### Platform Incompatibility Error

```
error: cannot evaluate darwin-specific module on linux
```

**Solution**: Don't import darwin apps in NixOS/Linux users. Use platform checks if needed:

```nix
imports = lib.optionals pkgs.stdenv.isDarwin [
  ../../system/darwin/app/aerospace.nix
];
```

## File Organization Patterns

### App Module Template

```nix
# system/{platform}/app/{category}/{name}.nix
{ config, lib, pkgs, ... }:

let
  # Import helpers if needed
  fileAssoc = import ../../lib/file-associations.nix { inherit pkgs lib; };
in
{
  # DEPENDENCIES: Declare at top
  imports = [
    # ../other/dependency.nix
  ];
  
  # PACKAGE: Install the application
  home.packages = [ pkgs.package-name ];
  
  # CONFIGURATION: Program settings
  programs.package-name = {
    enable = true;
    # ... settings
  };
  
  # ALIASES: Namespaced shell aliases
  programs.zsh.shellAliases = {
    pn = "package-name";
    pns = "package-name --some-flag";
  };
  
  # FILE ASSOCIATIONS: Use helper
  home.activation.packageFileAssoc = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${fileAssoc.mkFileAssociation {
      extension = ".ext";
      appId = "com.example.Package";
    }}
  '';
}
```

### Profile Template

```nix
# system/{platform}/profiles/{context}/default.nix
{ config, lib, pkgs, ... }:

{
  # METADATA: Required for validation
  _profileType = "complete";  # or "base" or "mixin"
  
  # IMPORTS: Settings + apps
  imports = [
    ../../settings/default.nix
    ../../../shared/app/category/app.nix
    # ... explicit list
  ];
  
  # OVERRIDES: Profile-specific settings
  system.defaults = {
    # ... platform-specific settings
  };
}
```

### User Template

```nix
# user/{username}/default.nix
{ config, lib, pkgs, ... }:

{
  # BOOTSTRAP: Required!
  imports = [
    ../shared/lib/home.nix
    
    # APPS: Select your applications
    ../../system/shared/app/shell/zsh.nix
    ../../system/shared/app/editor/helix.nix
    # ... more apps
  ];
  
  # USER INFO: Required fields
  user = {
    name = "username";
    email = "user@example.com";
    fullName = "Full Name";
  };
  
  # OVERRIDES: User-specific settings
  programs.git.signing = {
    key = "ABC123";
  };
}
```

## Next Steps

1. **Read the spec**: [spec.md](./spec.md) for full requirements
1. **Review research**: [research.md](./research.md) for implementation decisions
1. **Check contracts**: [contracts/](./contracts/) for API specs
1. **See data model**: [data-model.md](./data-model.md) for entity relationships
1. **Follow tasks**: [tasks.md](./tasks.md) for implementation checklist (after `/speckit.tasks`)

## Getting Help

- **Nix errors**: Check `nix flake check` output
- **Build logs**: Look in `/nix/var/log/nix/drvs/`
- **Circular deps**: Use `nix-instantiate --show-trace` for full stacktrace
- **Constitution**: See `.specify/memory/constitution.md` for principles
- **Migration**: See spec.md Migration Strategy section (Phase 0-5)
