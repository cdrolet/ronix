# Nested Secrets Support

**Feature**: 029-nested-secrets-support\
**Status**: Active\
**Since**: 2025-12-26\
**Depends on**: 027-user-colocated-secrets

## Overview

Extends the colocated secrets system (Feature 027) to support nested JSON paths for organizing multiple SSH keys, API tokens, and credentials hierarchically. Users can define secrets like `config.user.sshKeys.personal = "<secret>"` and have them resolved from nested JSON structures at activation time.

## Quick Start

### 1. Store Nested Secrets

```bash
# SSH keys (nested under sshKeys)
just secrets-set cdrokar sshKeys.personal "-----BEGIN OPENSSH PRIVATE KEY-----..."
just secrets-set cdrokar sshKeys.work "-----BEGIN OPENSSH PRIVATE KEY-----..."

# API tokens (nested under tokens)
just secrets-set cdrokar tokens.github "ghp_xxxxxxxxxxxx"
just secrets-set cdrokar tokens.gitlab "glpat-xxxxxxxxxxxx"

# Flat secrets still work
just secrets-set cdrokar email "me@example.com"
```

### 2. Reference in User Config

```nix
# user/cdrokar/default.nix
{ ... }:
{
  user = {
    name = "cdrokar";
    email = "<secret>";  # Flat path
    
    # Nested paths
    sshKeys = {
      personal = "<secret>";
      work = "<secret>";
    };
    
    tokens = {
      github = "<secret>";
      gitlab = "<secret>";
    };
  };
}
```

### 3. Use in App Modules

```nix
# In an app module
let
  secrets = import ../../../../user/shared/lib/secrets.nix { inherit lib pkgs; };
in {
  home.activation.applyMySecrets = secrets.mkActivationScript {
    inherit config pkgs lib;
    name = "myapp";
    fields = {
      # Shell code receives SSHKEYS_PERSONAL variable
      "sshKeys.personal" = ''
        echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_personal
      '';
      
      # Shell code receives TOKENS_GITHUB variable
      "tokens.github" = ''
        gh auth login --with-token <<< "$TOKENS_GITHUB"
      '';
    };
  };
}
```

## JSON Structure

Secrets are stored as nested JSON in `user/{name}/secrets.age`:

```json
{
  "email": "me@example.com",
  "sshKeys": {
    "personal": "-----BEGIN OPENSSH PRIVATE KEY-----...",
    "work": "-----BEGIN OPENSSH PRIVATE KEY-----..."
  },
  "tokens": {
    "github": "ghp_xxxxxxxxxxxx",
    "gitlab": "glpat-xxxxxxxxxxxx"
  }
}
```

## CLI Commands

### Set a Nested Secret

```bash
# Syntax: just secrets-set <user> <dotted.path> <value>
just secrets-set cdrokar sshKeys.personal "$(cat ~/.ssh/id_ed25519)"
just secrets-set cdrokar tokens.github "ghp_xxxxxxxxxxxx"
```

### List All Secrets

```bash
just secrets-list
```

Output shows nested paths:

```
Secrets status for all users:

  cdrokar:
    - email
    - sshKeys.personal
    - sshKeys.work
    - tokens.github
    - tokens.gitlab

  cdrolet:
    (no secrets file)
```

### Edit Secrets Interactively

```bash
just secrets-edit cdrokar
```

Opens decrypted JSON in your editor for manual editing.

## Helper Library

The `user/shared/lib/secrets.nix` provides these functions:

### `secrets.placeholder`

The `"<secret>"` string constant. Use this as single source of truth.

```nix
user.email = secrets.placeholder;
```

### `secrets.isSecret value`

Check if a value is the secret placeholder.

```nix
if secrets.isSecret config.user.email then "secret" else "plain"
```

### `secrets.stringToPath fieldPath`

Convert dotted path to Nix attribute list.

```nix
secrets.stringToPath "sshKeys.personal"
# Returns: ["sshKeys" "personal"]
```

### `secrets.fieldToVarName fieldPath`

Convert dotted path to shell variable name.

```nix
secrets.fieldToVarName "sshKeys.personal"
# Returns: "SSHKEYS_PERSONAL"
```

### `secrets.getNestedConfigValue config fieldPath`

Get nested value from config.user using dotted path.

```nix
secrets.getNestedConfigValue config "sshKeys.personal"
# Returns: "<secret>" or the actual value
```

### `secrets.mkJqExtract pkgs jsonPath`

Generate jq command to extract nested value.

```nix
secrets.mkJqExtract pkgs "sshKeys.personal"
# Returns: "${pkgs.jq}/bin/jq -r 'getpath(\"sshKeys.personal\" | split(\".\")) // empty'"
```

### `secrets.mkActivationScript { ... }`

Generate a Home Manager activation script for resolving secrets.

```nix
secrets.mkActivationScript {
  inherit config pkgs lib;
  name = "ssh";  # Unique name for the activation
  fields = {
    # Each key is a dotted path matching config.user structure
    # Value is shell code that receives the secret in a variable
    "sshKeys.personal" = ''
      # $SSHKEYS_PERSONAL contains the decrypted secret
      echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_personal
      chmod 600 ~/.ssh/id_personal
    '';
  };
}
```

## SSH Module Example

The `system/shared/app/dev/ssh.nix` module demonstrates nested secrets:

```nix
{ config, pkgs, lib, ... }:
let
  secrets = import ../../../../user/shared/lib/secrets.nix { inherit lib pkgs; };
in {
  programs.ssh = {
    enable = lib.mkDefault true;
    extraConfig = lib.mkDefault ''
      AddKeysToAgent yes
      IdentitiesOnly yes
    '';
  };

  home.activation.applySSHSecrets = secrets.mkActivationScript {
    inherit config pkgs lib;
    name = "ssh";
    fields = {
      "sshKeys.personal" = ''
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
        ${pkgs.openssh}/bin/ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub 2>/dev/null || true
      '';
    };
  };
}
```

## How It Works

### Detection Flow

1. App module declares fields with dotted paths: `"sshKeys.personal"`
1. `mkActivationScript` converts to Nix path: `["sshKeys" "personal"]`
1. Uses `lib.attrByPath` to check if `config.user.sshKeys.personal == "<secret>"`
1. If secret, generates extraction and application code

### Extraction Flow

1. Read encrypted secrets file via agenix: `config.age.secrets.user-${name}-secrets.path`
1. Use jq with `getpath()` for nested extraction: `jq -r 'getpath("sshKeys.personal" | split("."))'`
1. Store in shell variable: `SSHKEYS_PERSONAL="..."`
1. Execute user-provided shell code with variable in scope

### Variable Naming

Dotted paths are converted to uppercase underscored names:

| Field Path | Shell Variable |
|------------|----------------|
| `email` | `EMAIL` |
| `sshKeys.personal` | `SSHKEYS_PERSONAL` |
| `tokens.github` | `TOKENS_GITHUB` |
| `api.stripe.secret` | `API_STRIPE_SECRET` |

## Backward Compatibility

Flat secrets (depth=1) work exactly as before. The nested path system treats them as paths with a single segment:

```nix
# These are equivalent internally:
"email"           # Flat path
"email"           # Single-segment nested path

# Both extract with:
jq -r 'getpath("email" | split("."))'  # Returns .email
```

## Best Practices

### Organize by Category

```nix
user = {
  # Identity
  email = "<secret>";
  
  # SSH keys by purpose
  sshKeys = {
    personal = "<secret>";
    work = "<secret>";
    github = "<secret>";
  };
  
  # API tokens by service
  tokens = {
    github = "<secret>";
    npm = "<secret>";
    docker = "<secret>";
  };
};
```

### Use Consistent Naming

```nix
# Good: consistent camelCase
sshKeys.personal
tokens.github

# Avoid: mixed styles
ssh_keys.Personal
Tokens.GitHub
```

### Keep Secrets Minimal

Only mark truly sensitive values as secrets:

```nix
user = {
  name = "cdrokar";           # Plain text (not sensitive)
  email = "<secret>";         # Secret (might be sensitive)
  timezone = "America/Toronto"; # Plain text
  
  sshKeys.personal = "<secret>"; # Secret (definitely sensitive)
};
```

## Troubleshooting

### Secret Not Being Applied

**Check 1**: Verify the dotted path matches between config and fields:

```nix
# Config
user.sshKeys.personal = "<secret>";

# Must match exactly in fields
fields = { "sshKeys.personal" = "..."; };
```

**Check 2**: Ensure secret exists in JSON:

```bash
just secrets-edit cdrokar
# Look for: "sshKeys": { "personal": "..." }
```

### Variable Not Available in Shell

Shell variables use uppercase underscored names:

```nix
# Field: sshKeys.personal
# Variable: SSHKEYS_PERSONAL (not $sshKeys_personal)
fields = {
  "sshKeys.personal" = ''
    echo "$SSHKEYS_PERSONAL"  # Correct
  '';
};
```

### Empty Secret Value

Check that the jq extraction works:

```bash
age -d -i ~/.config/agenix/key.txt user/cdrokar/secrets.age | \
  jq -r 'getpath("sshKeys.personal" | split("."))'
```

## See Also

- [Feature 027: User Colocated Secrets](../../specs/027-user-colocated-secrets/spec.md) - Base secrets system
- [secrets.nix](../../user/shared/lib/secrets.nix) - Helper library source
- [ssh.nix](../../system/shared/app/dev/ssh.nix) - SSH module example
