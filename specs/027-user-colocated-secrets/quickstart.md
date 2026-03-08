# Quickstart: User Colocated Secrets

**Feature**: 027-user-colocated-secrets

This guide shows how to set up and use encrypted secrets in your user configuration.

______________________________________________________________________

## First-Time Setup (Once Per Repository)

Initialize the shared encryption key:

```bash
just secrets-init
```

This creates:

- `public.age` - Shared public key (commit this)
- `~/.config/agenix/key.txt` - Private key (keep secret, distribute to machines)

______________________________________________________________________

## Adding Secrets (One Command)

The easiest way to add a secret - one command updates both your config and secrets file:

```bash
# Add email as a secret
just secrets-set yourname email "me@example.com"

# Add nested secrets (e.g., tokens.github)
just secrets-set yourname tokens.github "ghp_xxxxxxxxxxxx"

# Add git signing key
just secrets-set yourname git.signingKey "ABCD1234..."
```

**What this does automatically**:

1. Adds `email = "<secret>";` to your `user/yourname/default.nix`
1. Adds `"email": "me@example.com"` to your `user/yourname/secrets.age`

That's it! One command, both files updated.

______________________________________________________________________

## Manual Editing (Interactive Mode)

For bulk editing or complex changes, open the secrets file in your editor:

```bash
just secrets-edit yourname
```

This opens your secrets file for manual editing. Add your secrets as JSON:

```json
{
  "email": "yourname@example.com",
  "fullName": "Your Name",
  "tokens": {
    "github": "ghp_your_token_here",
    "openai": "sk-your-key-here"
  },
  "git": {
    "signingKey": "YOUR_SIGNING_KEY"
  }
}
```

Save and exit. The file is automatically encrypted.

**Note**: When using interactive mode, you must also manually add the `"<secret>"` placeholders to your `default.nix`.

______________________________________________________________________

## Understanding the Placeholder

In your user config (`user/yourname/default.nix`), `"<secret>"` marks values that come from the encrypted secrets file:

```nix
{ ... }:
{
  user = {
    name = "yourname";
    email = "<secret>";           # Comes from secrets.age
    fullName = "<secret>";        # Comes from secrets.age
    timezone = "America/Toronto"; # Plain text (not secret)
    
    tokens.github = "<secret>";   # Nested secret
    git.signingKey = "<secret>";  # Nested secret
  };
}
```

______________________________________________________________________

## Common Tasks

### Add a New Secret

```bash
just secrets-set yourname fieldname "secret-value"
```

### Edit Existing Secrets

```bash
# One specific field
just secrets-set yourname email "new@example.com"

# Or open editor for multiple changes
just secrets-edit yourname
```

### List All Secret Files

```bash
just secrets-list
```

Output:

```
User secrets:
  cdrokar: user/cdrokar/secrets.age (exists)
  cdrolet: user/cdrolet/secrets.age (exists)
  cdronix: user/cdronix/secrets.age (not created)
```

### Show Public Key

```bash
just secrets-show-pubkey
```

______________________________________________________________________

## Setting Up a New Machine

1. Copy the private key from an existing machine:

   ```bash
   # On existing machine
   cat ~/.config/agenix/key.txt

   # On new machine
   mkdir -p ~/.config/agenix
   # Paste the key into ~/.config/agenix/key.txt
   chmod 600 ~/.config/agenix/key.txt
   ```

1. Clone the repository and rebuild:

   ```bash
   git clone <repo-url>
   cd nix-config
   just install yourname your-host
   ```

______________________________________________________________________

## File Structure

After setup, your user directory looks like:

```
user/
  yourname/
    default.nix     # Configuration with "<secret>" placeholders
    secrets.age     # Encrypted secrets (auto-created)
```

The shared key lives at repository root:

```
nix-config/
  public.age        # Shared public key (committed)
  user/
    ...
```

______________________________________________________________________

## JSON Field Mapping

Your Nix config paths map directly to JSON keys:

| Nix Config | JSON Path |
|------------|-----------|
| `user.email = "<secret>"` | `{ "email": "..." }` |
| `user.tokens.github = "<secret>"` | `{ "tokens": { "github": "..." } }` |
| `user.git.signingKey = "<secret>"` | `{ "git": { "signingKey": "..." } }` |

______________________________________________________________________

## Command Reference

| Command | Description |
|---------|-------------|
| `just secrets-init` | Initialize shared keypair (once per repo) |
| `just secrets-set <user> <field> <value>` | Set a secret value (one command) |
| `just secrets-edit <user>` | Open editor for manual secrets editing |
| `just secrets-list` | List all user secret files |
| `just secrets-show-pubkey` | Display the shared public key |

______________________________________________________________________

## Troubleshooting

### "public.age not found"

Run `just secrets-init` to create the shared keypair.

### "Failed to decrypt"

The private key doesn't match the public key. Ensure `~/.config/agenix/key.txt` is correct:

- It should match the key that generated `public.age`
- Copy it from a machine where secrets work

### "Secret field not found"

Your secrets JSON is missing the field. Add it with:

```bash
just secrets-set yourname fieldname "value"
```

### "user/X/ directory not found"

Create the user directory first:

```bash
mkdir -p user/yourname
# Create default.nix with your user config
```

______________________________________________________________________

## Security Notes

- **Never commit** `~/.config/agenix/key.txt`
- **Do commit** `public.age` and `user/*/secrets.age`
- All users share the same keypair (appropriate for personal/family repos)
- Distribute the private key via secure channel (not email, not chat)
- If private key is compromised, generate new keypair and re-encrypt all secrets
