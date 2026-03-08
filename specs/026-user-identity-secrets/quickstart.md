# Quickstart: User Identity Secrets

**Feature**: 026-user-identity-secrets
**Date**: 2025-12-21

## Overview

Use `"<secret>"` as a placeholder for any user config field. The system automatically looks for the encrypted value in the corresponding secret file.

## The Pattern

```nix
# user/cdrokar/default.nix
user = {
  name = "cdrokar";
  email = "<secret>";           # ← Auto-resolved from secrets/user/cdrokar/default.age
  fullName = "<secret>";        # ← Same file, field "fullName"
  tokens.github = "<secret>";   # ← Nested: field "tokens.github"
  timezone = "America/Toronto"; # ← Plain text, no secret needed
};
```

That's it. No paths to configure, no imports, no schema changes.

## Setup (One-Time)

### Step 1: Generate Age Key

```bash
just secrets-init
```

This creates `~/.config/agenix/key.txt` and displays your public key.

### Step 2: Register Your Public Key

Copy the public key from Step 1 and edit `secrets/secrets.nix`:

```nix
let
  cdrokar = "age1abc123...";  # Your public key from Step 1
in {
  "user/cdrokar/default.age".publicKeys = [ cdrokar ];
}
```

To view your public key again:

```bash
just secrets-show-pubkey
```

### Step 3: Create Your Secret File

```bash
just secrets-edit cdrokar
```

Enter JSON when editor opens:

```json
{
  "email": "cdrokar@pm.me",
  "fullName": "Charles Drokar"
}
```

Save and close.

### Step 4: Update Your Config

```nix
# user/cdrokar/default.nix
user = {
  name = "cdrokar";
  email = "<secret>";      # Was: "cdrokar@pm.me"
  fullName = "<secret>";   # Was: "Charles Drokar"
  # ... rest unchanged
};
```

### Step 5: Rebuild

```bash
just install cdrokar home-macmini-m4
```

Done!

## Adding New Secrets

### Add a Field

Just use `"<secret>"` for any field - no schema changes needed:

```nix
# user/cdrokar/default.nix
user = {
  # ...existing fields...
  tokens.github = "<secret>";     # NEW - just add it
  tokens.openai = "<secret>";     # NEW - just add it
  git.signingKey = "<secret>";    # NEW - just add it
};
```

### Update the Secret File

```bash
just secrets-edit cdrokar
```

Add the new fields to the JSON:

```json
{
  "email": "cdrokar@pm.me",
  "fullName": "Charles Drokar",
  "tokens": {
    "github": "ghp_xxxx",
    "openai": "sk-xxxx"
  },
  "git": {
    "signingKey": "ABC123..."
  }
}
```

Rebuild and you're done.

## Path Mirroring

The system automatically derives secret paths:

| User Config | Secret File |
|-------------|-------------|
| `user/cdrokar/default.nix` | `secrets/user/cdrokar/default.age` |
| `user/cdrolet/default.nix` | `secrets/user/cdrolet/default.age` |
| `user/cdrixus/default.nix` | `secrets/user/cdrixus/default.age` |

No configuration needed - it just works.

## New Users

When you create a new user:

```bash
mkdir -p user/newuser
# Create user/newuser/default.nix with your config
```

The system automatically expects secrets at:

```
secrets/user/newuser/default.age
```

If you use `"<secret>"` but the file doesn't exist, you'll get a clear error telling you what to create.

## Mixing Plain Text and Secrets

You can use both in the same file:

```nix
user = {
  name = "cdrokar";              # Plain text (always)
  email = "<secret>";            # Secret
  fullName = "<secret>";         # Secret
  timezone = "America/Toronto";  # Plain text
  locale = "en_CA.UTF-8";        # Plain text
  tokens.github = "<secret>";    # Secret
};
```

## Apps Access Secrets Transparently

Apps just reference `config.user.*`:

```nix
# system/shared/app/dev/git.nix
programs.git = {
  userName = config.user.fullName;
  userEmail = config.user.email;
};
```

The app doesn't know or care if the value is plain text or a secret.

## Troubleshooting

### "Secret file not found"

```
Error: Secret file not found: secrets/user/cdrokar/default.age
```

Create it:

```bash
agenix -e secrets/user/cdrokar/default.age
```

### "Field not found in secret"

```
Error: Field 'tokens.github' not found in secrets/user/cdrokar/default.age
```

Edit your secret file and add the missing field:

```bash
agenix -e secrets/user/cdrokar/default.age
```

### "Failed to decrypt"

Your private key doesn't match the public key in secrets.nix.

Check:

```bash
# Your actual public key
age-keygen -y ~/.config/agenix/key.txt

# What's in secrets.nix
grep cdrokar secrets/secrets.nix
```

They should match.

## Multiple Machines

If you deploy to multiple machines, add all your public keys:

```nix
# secrets/secrets.nix
let
  cdrokar_laptop = "age1...";
  cdrokar_desktop = "age1...";
in {
  "user/cdrokar/default.age".publicKeys = [ 
    cdrokar_laptop 
    cdrokar_desktop 
  ];
}
```

Re-encrypt after adding keys:

```bash
just secrets-rekey
```

## Available Commands

| Command | Description |
|---------|-------------|
| `just secrets-init` | Generate age key (one-time per machine) |
| `just secrets-show-pubkey` | Display public key for secrets.nix |
| `just secrets-edit <user>` | Edit user's secret file (auto-rekeys after) |
| `just secrets-rekey` | Re-encrypt all secrets (manual, if needed) |
| `just secrets-list` | List all secret files and status |

## Summary

1. Use `"<secret>"` for any field
1. Create `secrets/user/{username}/default.age` with JSON values
1. Field names in JSON must match your Nix attribute paths
1. Apps reference `config.user.*` - they don't need to know about secrets
