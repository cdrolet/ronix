# User Configuration Contract

## Overview

This document defines the user-facing configuration API for Claude Code and Claude Desktop integration for Claude Pro subscribers.

______________________________________________________________________

## User Configuration Fields

### Required Fields (Minimal)

```nix
{
  user = {
    # Standard user fields
    name = "username";           # string (required)
    email = "user@example.com";  # string or "<secret>"
    
    # Applications (add claude-code to list)
    applications = [ "claude-code" ];  # list of strings
  };
}
```

**That's it!** No API keys, no secrets, no additional configuration needed for Claude Pro users.

### Optional Fields

```nix
{
  user = {
    # ... required fields ...
    
    # Optional: Explicit claude configuration (future enhancements)
    claude = {
      workspace = "default";     # string (default: "default")
      model = "claude-3-opus";   # string (default: latest)
    };
  };
}
```

______________________________________________________________________

## Field Specifications

### `user.applications`

**Type**: `list of string`\
**Required**: Yes (to install claude-code)\
**Valid Values**: Any application name from `system/shared/app/`\
**Example**:

```nix
applications = [ "git" "zsh" "claude-code" ];
```

**Behavior**:

- Adding `"claude-code"` triggers installation of Claude Code package
- Discovery system automatically finds and imports `system/shared/app/ai/claude-code.nix`
- Package installed via Home Manager
- No authentication configuration needed (handled by OAuth on first run)

______________________________________________________________________

### ~~`user.tokens.anthropic`~~ (NOT REQUIRED)

**⚠️ IMPORTANT**: Claude Pro users should **NOT** configure API keys.

**Why**:

- Claude Pro subscription includes Claude Code
- Authentication via browser OAuth (one-time)
- No API key needed
- Setting `ANTHROPIC_API_KEY` will cause **unwanted API charges**

**What happens if you set it**:

- Build-time warning: "ANTHROPIC_API_KEY detected. Claude Pro users should NOT use API keys..."
- Claude Code will use API billing instead of subscription
- You'll be charged for API usage separately

**If you accidentally have it set**:

```bash
# Remove from shell configs
grep -r "ANTHROPIC_API_KEY" ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile

# Comment out or delete any lines setting ANTHROPIC_API_KEY
```

______________________________________________________________________

### `user.claude.workspace` (Optional)

**Type**: `string`\
**Required**: No\
**Default**: `"default"`\
**Valid Values**: Any string (workspace name)\
**Example**:

```nix
claude = {
  workspace = "personal";
};
```

**Behavior**:

- Configures Claude Code workspace selection
- Not implemented in initial version (future enhancement)

______________________________________________________________________

### `user.claude.model` (Optional)

**Type**: `string`\
**Required**: No\
**Default**: Latest available model\
**Valid Values**: `"claude-3-opus"`, `"claude-3-sonnet"`, `"claude-3-haiku"`, `"claude-3.5-sonnet"`\
**Example**:

```nix
claude = {
  model = "claude-3.5-sonnet";
};
```

**Behavior**:

- Sets default model for Claude Code
- Not implemented in initial version (future enhancement)

______________________________________________________________________

## Configuration Examples

### Minimal Configuration (Recommended)

```nix
# user/alice/default.nix
{ ... }:
{
  user = {
    name = "alice";
    email = "alice@example.com";
    applications = [ "claude-code" ];
  };
}
```

**Setup**:

```bash
just install alice macbook

# First run authentication
claude
# Select "1. Claude account with subscription"
# Browser opens for OAuth login
# Done!
```

### With Multiple Apps

```nix
# user/bob/default.nix
{ ... }:
{
  user = {
    name = "bob";
    email = "bob@example.com";
    
    # Multiple applications including claude-code
    applications = [
      "git"
      "zsh"
      "helix"
      "claude-code"
      "obsidian"
    ];
  };
}
```

**Setup**:

```bash
just install bob workstation

# First run authentication
claude
```

______________________________________________________________________

## Validation Rules

### Build-Time Validation

1. **Application Name Validation**:

   - `"claude-code"` must match file `system/shared/app/ai/claude-code.nix`
   - Discovery system validates file exists
   - Typos result in build error: "Application 'claude-cod' not found"

1. **API Key Conflict Detection**:

   - Check if `ANTHROPIC_API_KEY` environment variable is set
   - If found, display warning during build
   - Does NOT block build (warning only)

### Runtime Validation

1. **OAuth Authentication**:

   - First run of `claude` prompts for authentication method
   - User selects "1. Claude account with subscription"
   - Browser opens for OAuth flow
   - Credentials stored in `~/.claude/`

1. **macOS Symlink Validation** (darwin only):

   - Activation script creates `~/.local/bin/` directory
   - Symlink created pointing to current nix store path
   - If symlink creation fails, displays warning (package still usable via store path)

______________________________________________________________________

## Error Handling

### API Key Conflict Detected

**Scenario**: User has `ANTHROPIC_API_KEY` set in environment

**Build Behavior**:

- ✅ Build succeeds
- ⚠️ Warning displayed: "ANTHROPIC_API_KEY detected. Claude Pro users should NOT use API keys - this will result in API charges..."

**Runtime Behavior**:

- Claude Code will use API billing instead of subscription
- User charged for API usage

**Fix**:

```bash
# Find where it's set
grep -r "ANTHROPIC_API_KEY" ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile

# Remove or comment out
# export ANTHROPIC_API_KEY="..."  # ← Delete this line

# Reload shell
source ~/.zshrc  # or your shell config
```

### Authentication Required

**Scenario**: User runs `claude` for the first time

**Runtime Behavior**:

- Claude Code prompts for authentication method
- User selects option 1 (Claude account with subscription)
- Browser opens for OAuth login
- User logs in with Claude Pro credentials
- Authentication complete

**No fix needed** - this is expected behavior

### Authentication Failed

**Scenario**: OAuth login fails or credentials expired

**Runtime Behavior**:

- Claude Code displays authentication error
- Commands fail with "Not authenticated"

**Fix**:

```bash
# Re-authenticate
claude /login

# Or manually trigger authentication
claude
# Select option 1 again
```

### macOS TCC Permission Denied

**Scenario**: User hasn't granted Accessibility permissions (macOS only)

**Build Behavior**:

- ✅ Build succeeds
- ℹ️ Symlink created successfully

**Runtime Behavior**:

- `claude` may fail to access certain system features
- macOS prompts for permission on first access

**Fix**:

1. Open System Settings → Privacy & Security → Accessibility
1. Click '+' and add: `/Users/username/.local/bin/claude`
1. Re-run `claude` command

______________________________________________________________________

## Backward Compatibility

### Existing Users (Before Feature 035)

**No impact**:

- Users without `claude-code` in applications: No changes
- No automatic installation
- Opt-in only

### Future Changes

**If additional authentication methods are added**:

- OAuth (Claude Pro) remains the default and recommended method
- API key method available for non-Pro users
- Configuration clearly separates Pro vs API usage

______________________________________________________________________

## Platform-Specific Behavior

### Darwin (macOS)

**Additional Steps**:

1. Stable symlink created at `~/.local/bin/claude`
1. `~/.local/bin` added to `$PATH`
1. User must grant TCC permissions to symlink (one-time)

**Authentication**:

- Same OAuth flow as other platforms
- Credentials stored in `~/.claude/`

### NixOS/Linux

**Additional Steps**:

1. No symlink needed (no TCC)
1. Binary available at `/nix/store/xxx-claude-code/bin/claude`

**Authentication**:

- Same OAuth flow as other platforms
- Credentials stored in `~/.claude/`

**Desktop Integration**:

- If claude-desktop added: `.desktop` file created
- Appears in application launcher

______________________________________________________________________

## Testing Contract Compliance

### Test Case 1: Minimal Valid Configuration

**Input**:

```nix
{
  user = {
    name = "test";
    applications = ["claude-code"];
  };
}
```

**Expected Output**:

- ✅ Build succeeds
- ✅ Package installed
- ✅ No warnings (if ANTHROPIC_API_KEY not set)
- ✅ Activation script runs
- ℹ️ First run prompts for OAuth

### Test Case 2: API Key Conflict

**Input**:

```bash
export ANTHROPIC_API_KEY="sk-ant-xxx"
```

```nix
{
  user = {
    name = "test";
    applications = ["claude-code"];
  };
}
```

**Expected Output**:

- ✅ Build succeeds
- ⚠️ Warning: "ANTHROPIC_API_KEY detected..."
- ✅ Package installed
- ⚠️ Runtime will use API billing (not subscription)

### Test Case 3: Invalid Application Name

**Input**:

```nix
{
  user = {
    name = "test";
    applications = ["claude-cod"];  # Typo
  };
}
```

**Expected Output**:

- ❌ Build fails
- ❌ Error: "Application 'claude-cod' not found"

### Test Case 4: OAuth Authentication Flow

**Input**:

```bash
just install test macbook
claude chat "Hello"
```

**Expected Output**:

- ✅ Build/install succeeds
- ℹ️ Prompt: "Select login method:"
- ✅ Browser opens after selecting option 1
- ✅ After OAuth: command executes successfully
- ✅ Subsequent runs: no authentication prompt

______________________________________________________________________

## Summary

| Field | Type | Required | Default | Validation |
|-------|------|----------|---------|------------|
| `applications` | list string | Yes | `[]` | App exists in discovery |
| ~~`tokens.anthropic`~~ | ~~string~~ | **NO** | none | **Not used for Pro users** |
| `claude.workspace` | string | No | `"default"` | Any string (future) |
| `claude.model` | string | No | Latest | Valid model name (future) |

**Key Principles**:

1. **Minimal configuration**: Just add to applications array
1. **OAuth authentication**: Browser-based, managed by Claude Code
1. **No secret management**: No API keys, no agenix integration needed
1. **Warn about conflicts**: Prevent accidental API charges
1. **Platform-aware**: Automatic platform-specific adaptations (symlinks, etc.)
1. **Backward compatible**: Opt-in only, no changes to existing users

______________________________________________________________________

## Migration from API Key Approach

If you previously configured API keys (before this revision):

**Old approach** (no longer needed):

```nix
{
  user = {
    applications = ["claude-code"];
    tokens.anthropic = "<secret>";  # ← Remove this
  };
}
```

**New approach** (Claude Pro):

```nix
{
  user = {
    applications = ["claude-code"];  # ← Just this
  };
}
```

**Migration steps**:

1. Remove `tokens.anthropic` from user config
1. Remove `ANTHROPIC_API_KEY` from shell configs
1. Rebuild: `just install username hostname`
1. First run: `claude` and select option 1 (OAuth)
1. Done!
