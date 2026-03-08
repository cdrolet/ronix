# Claude Code Integration - Quickstart Guide

## What You'll Get

This guide helps you install **Claude Code**, an AI-powered development assistant, into your nix-config environment.

**Features**:

- 🤖 AI-powered code assistance via Claude
- 💻 Command-line interface for development tasks
- 🔐 Secure browser-based OAuth authentication
- 🍎 macOS TCC permission persistence across updates
- 🐧 Cross-platform support (macOS + NixOS)
- 💰 **Included in Claude Pro subscription** (no additional fees!)

______________________________________________________________________

## Prerequisites

### Claude Pro Subscription

**Required**: Active Claude Pro subscription

- **What**: $20/month subscription to Claude.ai
- **Includes**: Claude Code CLI access (no additional fees)
- **Usage**: Shares the same usage limits as web/desktop Claude
- **Sign up**: https://www.anthropic.com/claude/pricing

**Important**: Do NOT use an API key with Claude Pro - it will cause unwanted API charges!

______________________________________________________________________

## Installation

### Step 1: Add Claude Code to Your Applications

Edit your user configuration file:

```bash
# Open your user config
vim user/<your-username>/default.nix
```

Add `"claude-code"` to your applications list:

```nix
{ ... }:
{
  user = {
    name = "<your-username>";
    email = "you@example.com";
    
    # Add claude-code to your applications
    applications = [
      "git"
      "zsh"
      "helix"
      "claude-code"  # ← Add this line
    ];
    
    # NO API KEY NEEDED - OAuth handles authentication!
  };
}
```

**That's it for configuration!** No secrets, no API keys required.

### Step 2: Build and Install

```bash
# Build your configuration
just build <your-username> <your-hostname>

# Install (applies changes)
just install <your-username> <your-hostname>
```

**Example**:

```bash
just build alice macbook
just install alice macbook
```

______________________________________________________________________

## First-Time Authentication

### Authenticate with Your Claude Pro Account

Run `claude` for the first time:

```bash
claude
```

You'll see a prompt:

```
Select login method:
❯ 1. Claude account with subscription
  2. Anthropic Console account (API usage billing)
```

**Select option 1** (Claude account with subscription)

**What happens next**:

1. Your browser automatically opens
1. You're redirected to Claude.ai login
1. Log in with your Claude Pro credentials
1. Click "Authorize" to grant Claude Code access
1. Browser shows "Authentication successful!"
1. Return to your terminal - you're authenticated!

**That's it!** Credentials are securely stored in `~/.claude/` and persist between sessions.

______________________________________________________________________

## macOS-Specific Setup (TCC Permissions)

If you're on macOS, you need to grant permissions to the stable symlink to avoid re-prompting after Nix updates.

### Grant Accessibility Permission

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
1. Click the **lock icon** (bottom left) and authenticate
1. Click the **'+'** button
1. Press **Cmd+Shift+G** to open "Go to folder"
1. Enter: `/Users/<your-username>/.local/bin`
1. Select the **`claude`** file and click **Open**
1. Ensure the checkbox next to `claude` is **enabled**

**Why this path?**

- The symlink at `~/.local/bin/claude` never changes
- It always points to the current Nix store version
- macOS remembers permissions for this stable path
- After Nix updates, permissions persist automatically

______________________________________________________________________

## Verification

### Test Claude Code Installation

```bash
# Check version
claude --version

# Test connection (should work without prompting for auth again)
claude chat "Hello, Claude! Can you introduce yourself?"

# Expected output:
# Hello! I'm Claude, an AI assistant created by Anthropic...
```

### Check Authentication Status

```bash
# Inside claude interactive mode
claude
/status

# Should show:
# Authenticated: Yes
# Account: your-email@example.com
# Subscription: Claude Pro
```

______________________________________________________________________

## Usage Examples

### Interactive Chat

```bash
# Start a conversation
claude chat "How do I implement a binary search in Python?"

# Or enter interactive mode
claude
# Then type your questions
```

### Code Review

```bash
# Review a file
claude code review src/main.py

# Review with specific focus
claude code review --focus security auth.py
```

### Code Generation

```bash
# Generate code from description
claude generate "Create a function that validates email addresses using regex"
```

### Git Integration

```bash
# Generate commit message from staged changes
claude commit

# Review PR changes
claude pr review
```

### Common Commands

```bash
claude chat "question"          # Ask a question
claude code review file.py      # Review code
claude code explain file.py     # Explain code
claude /help                    # Show help
claude /status                  # Check auth status
claude /login                   # Re-authenticate
claude /logout                  # Log out
```

______________________________________________________________________

## Troubleshooting

### "Not authenticated" Error

**Symptom**:

```
Error: Not authenticated. Please run 'claude /login' to authenticate.
```

**Solution**:

1. Re-run authentication:

   ```bash
   claude /login
   ```

1. Select option 1 (Claude account with subscription)

1. Complete OAuth flow in browser

______________________________________________________________________

### API Charges Warning Appears

**Symptom**:
During `just install`, you see:

```
WARNING: ANTHROPIC_API_KEY environment variable detected. Claude Pro users 
should NOT use API keys - this will result in API charges...
```

**Cause**:
You have `ANTHROPIC_API_KEY` set in your shell configuration, which will cause Claude Code to use API billing instead of your subscription.

**Solution**:

1. Find where it's set:

   ```bash
   grep -r "ANTHROPIC_API_KEY" ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile
   ```

1. Remove or comment out the line:

   ```bash
   # export ANTHROPIC_API_KEY="..."  # ← Delete or comment this
   ```

1. Reload your shell:

   ```bash
   source ~/.zshrc  # or ~/.bashrc, etc.
   ```

1. Rebuild:

   ```bash
   just install <your-username> <your-hostname>
   ```

______________________________________________________________________

### Permission Prompts After Nix Updates (macOS)

**Symptom**:
After running `just install`, macOS prompts for permissions again.

**Cause**:
You granted permissions to the Nix store path instead of the stable symlink.

**Solution**:

1. Remove the Nix store path from Accessibility permissions:

   - System Settings → Privacy & Security → Accessibility
   - Find entries like `/nix/store/...-claude-code/bin/claude`
   - Click '-' to remove them

1. Add the stable symlink (see "macOS-Specific Setup" above):

   - Add `/Users/<your-username>/.local/bin/claude`

1. Test:

   ```bash
   just install <your-username> <your-hostname>
   claude chat "Test"
   ```

   Should NOT prompt for permissions again.

______________________________________________________________________

### `claude` Command Not Found

**Symptom**:

```bash
claude chat "test"
# -bash: claude: command not found
```

**Solution**:

1. **Check if package is installed**:

   ```bash
   ls -l ~/.nix-profile/bin/claude
   ```

1. **Check if symlink exists (macOS)**:

   ```bash
   ls -l ~/.local/bin/claude
   ```

1. **Verify PATH includes the directory**:

   ```bash
   echo $PATH | grep -o ".local/bin"
   ```

1. **Reload shell configuration**:

   ```bash
   source ~/.zshrc  # or ~/.bashrc
   # or restart your terminal
   ```

1. **If still missing, rebuild**:

   ```bash
   just install <your-username> <your-hostname>
   ```

______________________________________________________________________

### Slow Response Times

**Symptom**:
Claude commands take a long time to respond.

**Possible Causes**:

1. Network latency to Anthropic API
1. Usage limits reached (shared with web/desktop Claude)
1. Large context/prompt

**Solutions**:

1. **Check Claude Pro usage**:

   - Visit https://claude.ai/
   - Check if you're near usage limits
   - Usage resets daily/monthly (depending on plan)

1. **Check API status**:

   - Visit https://status.anthropic.com/

1. **Reduce context size**:

   ```bash
   # Use shorter prompts
   claude chat "Brief summary of X"

   # Instead of:
   claude chat "Please provide an extremely detailed explanation..."
   ```

______________________________________________________________________

### Browser Doesn't Open for OAuth

**Symptom**:
When running `claude /login`, browser doesn't open automatically.

**Solution**:

1. **Manual OAuth URL**:
   Claude Code should display a URL. Copy and paste it into your browser manually.

1. **Check default browser**:

   ```bash
   # macOS
   open https://example.com  # Should open in default browser

   # Linux
   xdg-open https://example.com
   ```

1. **Set BROWSER environment variable**:

   ```bash
   export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox"
   claude /login
   ```

______________________________________________________________________

## Advanced Usage

### Re-authenticate / Switch Accounts

```bash
# Log out
claude /logout

# Log in again (prompts for account selection)
claude /login
```

### Check Authentication Details

```bash
# In interactive mode
claude
/status

# Shows:
# - Authentication status
# - Account email
# - Subscription type
```

### Shell Integration

Add aliases to your shell config for common workflows:

```nix
# In your user config (optional)
home.shellAliases = {
  ai = "claude chat";
  review = "claude code review";
  explain = "claude code explain";
};
```

Then:

```bash
ai "How do I optimize this SQL query?"
review myfile.py
explain complex-function.js
```

______________________________________________________________________

## Updating Claude Code

Claude Code is automatically updated when you update your Nix inputs:

```bash
# Update all inputs (including claude-code-nix)
just update

# Rebuild with new version
just install <your-username> <your-hostname>
```

**Check for updates manually**:

```bash
# See current version
nix flake metadata github:sadjow/claude-code-nix

# Update only claude-code-nix input
just update-input claude-code-nix
```

**After update**: No need to re-authenticate - credentials persist.

______________________________________________________________________

## Uninstalling

### Remove from Configuration

1. Edit `user/<your-username>/default.nix`:

   ```nix
   applications = [
     "git"
     "zsh"
     # Remove "claude-code" from this list
   ];
   ```

1. Rebuild:

   ```bash
   just install <your-username> <your-hostname>
   ```

### Remove Authentication Credentials

```bash
# Remove stored credentials
rm -rf ~/.claude/

# No need to revoke - credentials will become invalid
```

### Revoke OAuth Access (Optional)

1. Visit https://claude.ai/
1. Go to Settings → Connected Apps
1. Find "Claude Code" and click "Revoke"

______________________________________________________________________

## Getting Help

### Documentation

- **Claude Code Docs**: https://docs.anthropic.com/claude/docs
- **Claude Pro**: https://www.anthropic.com/claude/pricing
- **Anthropic Support**: https://support.anthropic.com/

### nix-config Repository

- **Issues**: Report bugs in the nix-config GitHub repository
- **CLAUDE.md**: General repository documentation
- **Feature Spec**: `specs/035-claude-apps-integration/spec.md`

### Community Support

- **Anthropic Discord**: https://discord.gg/anthropic
- **NixOS Discourse**: https://discourse.nixos.org/

______________________________________________________________________

## Security Best Practices

### Authentication Management

✅ **DO**:

- Use browser OAuth (option 1 during first run)
- Keep your Claude Pro account secure
- Log out when using shared machines (`claude /logout`)

❌ **DON'T**:

- Set `ANTHROPIC_API_KEY` environment variable (causes API charges)
- Share your `~/.claude/` directory
- Use API keys if you have Claude Pro

### TCC Permissions (macOS)

✅ **DO**:

- Grant permissions to stable symlink (`~/.local/bin/claude`)
- Review permissions regularly in System Settings

❌ **DON'T**:

- Grant permissions to Nix store paths
- Grant more permissions than needed

### Usage Monitoring

✅ **DO**:

- Monitor usage at https://claude.ai/
- Be aware of daily/monthly limits
- Share usage limits with web/desktop Claude

❌ **DON'T**:

- Assume unlimited usage (Pro has limits)
- Spam API with unnecessary requests

______________________________________________________________________

## FAQ

### Q: Do I need an API key?

**A:** No! Claude Pro subscribers use browser OAuth authentication. Do NOT set an API key - it will cause unwanted charges.

### Q: How much does it cost?

**A:** If you have Claude Pro ($20/month), Claude Code is **included** at no additional cost. Shares usage limits with web/desktop Claude.

### Q: What if I don't have Claude Pro?

**A:** You can use Anthropic API with pay-per-use billing (option 2 during login). However, this integration is optimized for Claude Pro users.

### Q: Will I be charged API fees?

**A:** Not if you:

- Have Claude Pro subscription
- Select option 1 during authentication
- Don't have `ANTHROPIC_API_KEY` environment variable set

### Q: Does this work on Linux?

**A:** Yes! Claude Code works on both macOS (Darwin) and NixOS/Linux. The OAuth authentication is the same across platforms.

### Q: Can multiple users on the same machine use Claude Code?

**A:** Yes! Each user authenticates independently with their own Claude Pro account. Credentials are stored per-user in `~/.claude/`.

### Q: What happens after Nix updates?

**A:** On macOS, if you granted permissions to the stable symlink (`~/.local/bin/claude`), permissions persist automatically. On Linux, no special permissions needed.

______________________________________________________________________

## Next Steps

Now that Claude Code is installed:

1. **Explore commands**:

   ```bash
   claude --help
   claude chat --help
   claude code --help
   ```

1. **Integrate with your editor**:

   - Check if your editor has Claude Code plugins
   - Configure editor to use `claude` command

1. **Set up shell aliases** (see "Advanced Usage" above)

1. **Monitor usage**:

   - Visit https://claude.ai/ → Usage

1. **Give feedback**:

   - Report bugs or feature requests in the nix-config repository

______________________________________________________________________

## Changelog

- **2026-01-01**: Updated quickstart for Claude Pro OAuth authentication (removed API key approach)
- **2026-01-01**: Initial quickstart created for Feature 035
