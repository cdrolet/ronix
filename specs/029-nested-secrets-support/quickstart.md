# Quickstart: Nested Secrets Support

**Feature**: 029-nested-secrets-support

## Overview

Store and manage multiple secrets in organized, nested structures. Perfect for SSH keys, API tokens, and credentials that need logical grouping.

## Quick Example

### 1. Define Nested Secrets in User Config

```nix
# user/cdrokar/default.nix
{ ... }:
{
  user = {
    name = "cdrokar";
    email = "<secret>";
    fullName = "<secret>";
    
    # SSH keys (nested)
    sshKeys = {
      personal = "<secret>";
      work = "<secret>";
      github = "<secret>";
    };
    
    # API tokens (nested)
    tokens = {
      github = "<secret>";
      openai = "<secret>";
    };
  };
}
```

### 2. Set Secrets via CLI

```bash
# Set nested SSH keys
just secrets-set cdrokar sshKeys.personal "$(cat ~/.ssh/id_ed25519_personal)"
just secrets-set cdrokar sshKeys.work "$(cat ~/.ssh/id_ed25519_work)"
just secrets-set cdrokar sshKeys.github "$(cat ~/.ssh/id_ed25519_github)"

# Set nested API tokens
just secrets-set cdrokar tokens.github "ghp_xxxx"
just secrets-set cdrokar tokens.openai "sk-xxxx"

# Flat secrets still work
just secrets-set cdrokar email "me@example.com"
```

### 3. Use in App Modules

```nix
# system/shared/app/dev/ssh.nix
{ config, pkgs, lib, ... }:
let
  secrets = import ../../../../user/shared/lib/secrets.nix { inherit lib pkgs; };
in {
  programs.ssh.enable = true;

  # Deploy SSH keys at activation
  home.activation.applySSHSecrets = secrets.mkActivationScript {
    inherit config pkgs lib;
    name = "ssh";
    fields = {
      # Nested paths - dots converted to underscores for shell vars
      "sshKeys.personal" = ''
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
      '';
      "sshKeys.work" = ''
        echo "$SSHKEYS_WORK" > ~/.ssh/id_ed25519_work
        chmod 600 ~/.ssh/id_ed25519_work
      '';
      "sshKeys.github" = ''
        echo "$SSHKEYS_GITHUB" > ~/.ssh/id_ed25519_github
        chmod 600 ~/.ssh/id_ed25519_github
      '';
    };
  };
}
```

### 4. JSON Structure in secrets.age

When you set nested secrets, the JSON structure mirrors the hierarchy:

```json
{
  "email": "me@example.com",
  "fullName": "My Name",
  "sshKeys": {
    "personal": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
    "work": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
    "github": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
  },
  "tokens": {
    "github": "ghp_xxxx",
    "openai": "sk-xxxx"
  }
}
```

## Common Use Cases

### Multiple SSH Keys

```nix
# User config
user.sshKeys = {
  personal = "<secret>";
  work = "<secret>";
  deploy = "<secret>";
};

# App activation
fields = {
  "sshKeys.personal" = ''echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_ed25519'';
  "sshKeys.work" = ''echo "$SSHKEYS_WORK" > ~/.ssh/id_ed25519_work'';
  "sshKeys.deploy" = ''echo "$SSHKEYS_DEPLOY" > ~/.ssh/id_deploy'';
};
```

### Cloud Credentials

```nix
# User config
user.credentials = {
  aws = {
    accessKeyId = "<secret>";
    secretAccessKey = "<secret>";
  };
  gcp = {
    serviceAccount = "<secret>";
  };
};

# App activation
fields = {
  "credentials.aws.accessKeyId" = ''
    aws configure set aws_access_key_id "$CREDENTIALS_AWS_ACCESSKEYID"
  '';
  "credentials.aws.secretAccessKey" = ''
    aws configure set aws_secret_access_key "$CREDENTIALS_AWS_SECRETACCESSKEY"
  '';
};
```

### Application Tokens

```nix
# User config
user.tokens = {
  github = "<secret>";
  openai = "<secret>";
  anthropic = "<secret>";
};

# App activation
fields = {
  "tokens.github" = ''gh auth login --with-token <<< "$TOKENS_GITHUB"'';
  "tokens.openai" = ''echo "export OPENAI_API_KEY=$TOKENS_OPENAI" >> ~/.zshrc.local'';
};
```

## Shell Variable Naming

Nested paths are converted to shell variables:

| Nested Path | Shell Variable |
|-------------|----------------|
| `email` | `$EMAIL` |
| `sshKeys.personal` | `$SSHKEYS_PERSONAL` |
| `tokens.github` | `$TOKENS_GITHUB` |
| `credentials.aws.accessKeyId` | `$CREDENTIALS_AWS_ACCESSKEYID` |

**Rule**: Replace dots with underscores, convert to uppercase.

## Backward Compatibility

Existing flat secrets continue to work unchanged:

```nix
# Still works exactly as before
user.email = "<secret>";

fields = {
  email = ''git config --global user.email "$EMAIL"'';
};
```

## Commands Reference

```bash
# Set nested secret
just secrets-set <user> <path> <value>
just secrets-set cdrokar sshKeys.personal "key-content"

# List all secrets (shows nested structure)
just secrets-list

# Edit secrets interactively
just secrets-edit <user>
```

## Troubleshooting

### Secret Not Found

```
Warning: Field 'sshKeys.personal' not found in secrets
```

**Fix**: Ensure the secret exists: `just secrets-set cdrokar sshKeys.personal "value"`

### Invalid Path

```
Error: Invalid nested path 'sshKeys..personal'
```

**Fix**: Remove double dots from path

### Depth Limit

Recommended maximum: 4 levels deep (e.g., `credentials.aws.keys.primary`)
