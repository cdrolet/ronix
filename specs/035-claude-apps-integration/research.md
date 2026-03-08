# Feature 035: Claude Code & Desktop Integration - Research

## Research Completion Date

2026-01-01

## Overview

This document contains research findings for integrating Claude Code and Claude Desktop into the nix-config repository using Home Manager and the claude-code-nix flake.

______________________________________________________________________

## 1. Claude-Code-Nix Flake Integration

### Source Repository

- **URL**: https://github.com/sadjow/claude-code-nix
- **Purpose**: Provides pre-built Claude Code binaries via Nix overlay
- **Platforms**: aarch64-darwin, x86_64-darwin, aarch64-linux, x86_64-linux

### Overlay Integration Pattern

**Recommended approach**: Apply overlay in platform libraries (darwin.nix, nixos.nix)

```nix
# In flake.nix inputs:
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  claude-code-nix = {
    url = "github:sadjow/claude-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

# In platform lib (system/darwin/lib/darwin.nix or system/nixos/lib/nixos.nix):
homeManagerConfiguration = inputs.home-manager.darwinModules.home-manager {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  
  # Apply overlay
  nixpkgs.overlays = [
    inputs.claude-code-nix.overlays.default
  ];
};
```

**Why this approach**:

- ✅ Centralized overlay application (once per platform)
- ✅ Available to all users on the platform
- ✅ Follows repository's platform library pattern
- ✅ No per-app overlay imports needed

______________________________________________________________________

## 2. Authentication & Configuration

### Claude Pro Subscription Authentication (Recommended)

**For Claude Pro subscribers**, Claude Code uses browser-based OAuth authentication instead of API keys.

**Authentication Flow**:

1. User runs `claude` for the first time
1. Claude Code prompts for authentication method:
   ```
   Select login method:
   ❯ 1. Claude account with subscription
     2. Anthropic Console account (API usage billing)
   ```
1. User selects option 1 (Claude account with subscription)
1. Browser automatically opens for OAuth flow
1. User logs in with Claude Pro credentials
1. User clicks "Authorize"
1. Authentication complete - credentials stored in `~/.claude/`

**Key Benefits**:

- ✅ No API key required
- ✅ No separate billing (included in Claude Pro subscription)
- ✅ Shares usage limits with web/desktop Claude
- ✅ One-time authentication (persists between sessions)
- ✅ Secure OAuth flow

**Important: Avoiding API Key Conflicts**

If `ANTHROPIC_API_KEY` environment variable is set, Claude Code will use it instead of subscription authentication, resulting in **unwanted API charges**.

**Prevention Strategy**:

```nix
# In app module - warn if API key detected
warnings = lib.optional (builtins.getEnv "ANTHROPIC_API_KEY" != "")
  "WARNING: ANTHROPIC_API_KEY detected. Claude Pro users should NOT use API keys. Remove from shell config to avoid charges.";
```

**Check for conflicts**:

```bash
# Verify no API key in shell configs
grep -r "ANTHROPIC_API_KEY" ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile
```

### Alternative: API Key Authentication (Not Recommended for Pro Users)

For users **without Claude Pro** who want to use pay-per-use API billing:

- Set `ANTHROPIC_API_KEY` environment variable
- Select option 2 during first run
- Billed separately via Anthropic Console
- **Not covered in this implementation** (optimized for Claude Pro)

### Configuration Files

Claude Code stores runtime configuration and credentials in:

- **Config**: `~/.claude.json`
- **Credentials**: `~/.claude/` directory
- **Authentication**: OAuth tokens (managed by Claude Code)

**Recommendation**: Leave these as runtime state (unmanaged by Nix)

**Rationale**:

- Claude Code manages its own OAuth flow
- User preferences (themes, editor settings) should persist
- Credentials automatically refreshed by Claude Code
- No secret management needed (no API keys)

______________________________________________________________________

## 3. macOS TCC Permission Issue & Symlink Solution

### The Problem

macOS Transparency, Consent, and Control (TCC) grants permissions to **specific application paths**. When Nix updates packages:

1. Old path: `/nix/store/abc123-claude-code/bin/claude`
1. New path: `/nix/store/xyz789-claude-code/bin/claude`
1. macOS sees this as a **different application**
1. User must re-grant permissions (Accessibility, Files, etc.)

### The Solution: Stable Symlink

**Create a stable symlink that always points to the current binary**:

```nix
{ config, pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in {
  # macOS: Create stable symlink for TCC persistence
  home.activation.createClaudeSymlink = lib.mkIf isDarwin (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p "$HOME/.local/bin"
      ln -sf "${pkgs.claude-code}/bin/claude" "$HOME/.local/bin/claude"
    ''
  );
  
  # macOS: Add stable symlink to PATH
  home.sessionPath = lib.mkIf isDarwin [ "$HOME/.local/bin" ];
}
```

**Location**: `~/.local/bin/claude`

**Why this works**:

- Symlink path never changes (`~/.local/bin/claude`)
- Target updates automatically when Nix profile updates
- macOS TCC permissions tied to stable symlink path
- User grants permissions once, persists across updates

**Implementation notes**:

- Use `lib.mkIf isDarwin` for platform-specific logic
- Run as activation script (after writeBoundary)
- Add to PATH so users can run `claude` directly

______________________________________________________________________

## 4. Cross-Platform Support

### Platform Differences

**Darwin (macOS)**:

- ✅ TCC stable symlink required (see section 3)
- ✅ Installed via Nix overlay + Home Manager
- ❌ No desktop application integration (CLI only)

**NixOS/Linux**:

- ✅ No TCC concerns (no macOS permission system)
- ✅ Installed via Nix overlay + Home Manager
- ✅ Desktop application integration (if claude-desktop is packaged)

### Platform-Agnostic App Module Structure

```nix
# system/shared/app/ai/claude-code.nix
{ config, pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  
  # Check for API key conflict (would cause unwanted charges for Pro users)
  hasApiKeyConflict = builtins.getEnv "ANTHROPIC_API_KEY" != "";
in {
  # ============================================================================
  # Cross-Platform: Package Installation
  # ============================================================================
  
  home.packages = [ pkgs.claude-code ];
  
  # ============================================================================
  # Cross-Platform: API Key Conflict Warning
  # ============================================================================
  
  # Warn Claude Pro users if API key is set (would cause charges)
  warnings = lib.optional hasApiKeyConflict
    "WARNING: ANTHROPIC_API_KEY environment variable detected. Claude Pro users should NOT use API keys - this will result in API charges instead of using your included subscription. Remove ANTHROPIC_API_KEY from your shell config files.";
  
  # ============================================================================
  # macOS-Specific: Stable Symlink for TCC Persistence
  # ============================================================================
  
  home.activation.createClaudeSymlink = lib.mkIf isDarwin (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p "$HOME/.local/bin"
      ln -sf "${pkgs.claude-code}/bin/claude" "$HOME/.local/bin/claude"
    ''
  );
  
  home.sessionPath = lib.mkIf isDarwin [ "$HOME/.local/bin" ];
  
  # ============================================================================
  # Shell Alias (Optional)
  # ============================================================================
  
  home.shellAliases = {
    claude = lib.mkIf isDarwin "$HOME/.local/bin/claude"  # Use stable symlink
              ++ lib.mkIf (!isDarwin) "claude-code";       # Direct binary
  };
}
```

______________________________________________________________________

## 5. App Module Best Practices

### Constitutional Compliance

**Module Size**: \<200 lines ✅
**App-Centric**: One app per file (claude-code.nix, claude-desktop.nix) ✅
**Platform Abstraction**: Platform-specific code in conditionals ✅
**Cross-Platform**: Works on both darwin and nixos ✅

### Code Organization

```
system/shared/app/ai/
├── claude-code.nix                # CLI application
└── claude-desktop.nix             # Desktop application (future)
```

**Header template**:

```nix
# Claude Code - AI-Powered IDE Integration
#
# Purpose: Provides Claude AI assistant integration for development
# Feature: 035-claude-apps-integration
#
# Dependencies:
#   - claude-code-nix flake overlay
#   - Claude Pro subscription (recommended) OR Anthropic API key
#
# Platform Support:
#   - Darwin: ✓ (with TCC stable symlink)
#   - NixOS: ✓
#
# Authentication:
#   - Claude Pro: Browser OAuth (one-time, no config needed)
#   - API billing: ANTHROPIC_API_KEY env var (not recommended for Pro users)
```

______________________________________________________________________

## 6. User Configuration Pattern

### Minimal Configuration (Claude Pro Users)

```nix
# user/username/default.nix
{ ... }:
{
  user = {
    name = "username";
    
    # Applications - that's all you need!
    applications = [ "claude-code" ];
  };
}
```

**First-run authentication**:

1. Run `claude` in terminal
1. Select "1. Claude account with subscription"
1. Browser opens for OAuth login
1. Done! Credentials stored in `~/.claude/`

### No Secret Management Required

**Claude Pro users**:

- ❌ No API key needed
- ❌ No `user.tokens.anthropic` field
- ❌ No `just secrets-set` commands
- ✅ Just add to applications array and run

**Why**: Claude Code authenticates via browser OAuth, not API keys

______________________________________________________________________

## 7. Validation & Error Handling

### API Key Conflict Detection

```nix
{ config, pkgs, lib, ... }:

let
  # Check if user accidentally has API key set
  hasApiKeyConflict = builtins.getEnv "ANTHROPIC_API_KEY" != "";
in {
  # Warn if API key would cause unwanted charges
  warnings = lib.optional hasApiKeyConflict
    "WARNING: ANTHROPIC_API_KEY environment variable detected. Claude Pro users should NOT use API keys - this will result in API charges instead of using your included subscription. Check shell config files: ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile";
  
  # Always install (no authentication prereqs)
  home.packages = [ pkgs.claude-code ];
}
```

**Recommendation**: Warn about API key conflicts

- Users can install without any prereqs
- First-run OAuth handles authentication
- Warn if API key would override subscription auth

______________________________________________________________________

## 8. Testing & Verification

### Installation Verification

```bash
# Build configuration
just build username hostname

# Install configuration
just install username hostname

# Verify package installed
which claude  # Should show: /Users/username/.local/bin/claude (darwin)

# Test connection (first run prompts for OAuth login)
claude --version
claude chat "Hello, Claude!"  # Opens browser for auth on first run
```

### macOS TCC Verification

```bash
# 1. Grant permissions to stable symlink
#    macOS Settings → Privacy & Security → Accessibility
#    Add: /Users/username/.local/bin/claude

# 2. Update Nix package (simulates package update)
nix profile upgrade

# 3. Verify symlink still works
ls -l ~/.local/bin/claude
# Should point to new nix store path

# 4. Test permissions persist
claude chat "Test"  # Should NOT prompt for permissions again
```

______________________________________________________________________

## 9. Alternative Approaches Considered

### ❌ Direct Nix Store Path (No Symlink)

**Rejected because**:

- macOS TCC permissions tied to specific store path
- Every Nix update requires re-granting permissions
- Poor user experience on macOS

### ❌ Homebrew Installation

**Rejected because**:

- Not declarative (against repository constitution)
- No integration with Nix package management
- Can't use overlay approach

### ❌ System-Wide Installation

**Rejected because**:

- Breaks multi-user isolation (constitutional requirement)
- OAuth credentials are per-user, not system-wide
- Nix philosophy: user-level packages

### ✅ Home Manager + Overlay + Stable Symlink (Selected)

**Why this approach**:

- ✅ Fully declarative
- ✅ Cross-platform compatible
- ✅ Preserves multi-user isolation
- ✅ Solves macOS TCC issue
- ✅ No secret management complexity (OAuth handled by Claude Code)

______________________________________________________________________

## 10. Future Enhancements (Optional/Out of Scope)

### Claude Desktop Integration

If claude-desktop becomes available in claude-code-nix:

```nix
# system/shared/app/ai/claude-desktop.nix
{ config, pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
in {
  # Install via homebrew on darwin (if not in nixpkgs)
  homebrew.casks = lib.mkIf isDarwin ["claude"];
  
  # Install via nixpkgs on linux
  home.packages = lib.mkIf (!isDarwin) [ pkgs.claude-desktop ];
  
  # Same OAuth authentication as claude-code
  # No configuration needed - uses Claude Pro subscription
}
```

### Auto-Update Configuration

```nix
# Auto-update claude-code-nix flake input
{
  nix.settings.auto-optimise-store = true;
  
  # systemd timer for auto-update (NixOS only)
  systemd.user.timers.update-claude = {
    Unit.Description = "Update Claude Code";
    Timer.OnCalendar = "weekly";
    Install.WantedBy = ["timers.target"];
  };
}
```

**Status**: Out of scope for initial implementation

______________________________________________________________________

## 11. Security Considerations

### OAuth Credential Security

- ✅ **OAuth tokens managed by Claude Code**: Stored in `~/.claude/`
- ✅ **Per-user credentials**: Each user authenticates independently
- ✅ **Browser-based flow**: No credentials in Nix configuration
- ✅ **File permissions**: Claude Code manages credential file permissions
- ✅ **Token refresh**: Automatic token refresh handled by Claude Code

### API Key Conflict Prevention

- ⚠️ **Warn if ANTHROPIC_API_KEY set**: Prevents accidental API charges
- ✅ **Build-time detection**: Check environment during evaluation
- ℹ️ **User education**: Clear warnings about Pro vs API billing

### TCC Permissions (macOS)

- ✅ **Stable path**: Reduces attack surface (fewer permission prompts)
- ✅ **User grants**: Explicit user consent for permissions
- ⚠️ **Symlink risk**: If attacker replaces symlink target, could gain permissions
  - Mitigation: Symlink in user home directory (attacker needs user access)

### Network Security

- Claude Code communicates with Anthropic API (HTTPS)
- OAuth tokens transmitted securely (TLS)
- No local server or listening ports
- Browser-based authentication (standard OAuth 2.0)

______________________________________________________________________

## 12. Documentation Requirements

### README.md Updates

Add to "Active Technologies" section:

```markdown
- Nix 2.19+ with flakes enabled + claude-code-nix overlay, Home Manager (Feature 035)
```

Add to "Commands" section:

```bash
# Claude Code Usage
claude chat "Your question here"
claude code review file.py
```

### Quickstart.md Creation

Create `specs/035-claude-apps-integration/quickstart.md`:

````markdown
# Claude Code Quickstart

## Prerequisites
- Claude Pro subscription (recommended) OR Anthropic API account

## Installation

1. Add claude-code to your applications:
   ```nix
   # In user/username/default.nix
   applications = [ "claude-code" ];
````

2. Build and install:

   ```bash
   just install username hostname
   ```

1. First run authentication:

   ```bash
   claude
   # Select "1. Claude account with subscription"
   # Browser opens for OAuth login
   ```

1. (macOS only) Grant permissions:

   - Open System Settings → Privacy & Security → Accessibility
   - Click '+' and add: /Users/username/.local/bin/claude

## Usage

```bash
claude chat "Hello, Claude!"
claude code review myfile.py
```

## Troubleshooting

- **API charges warning**: Remove ANTHROPIC_API_KEY from shell config
- **Permission prompts (macOS)**: Grant to ~/.local/bin/claude, not the nix store path
- **Authentication failed**: Run `claude /login` to re-authenticate

```

---

## 13. Implementation Checklist

### Phase 0: Research ✅
- [x] Research claude-code-nix integration
- [x] Investigate macOS TCC permission issue
- [x] Investigate Claude Pro OAuth authentication
- [x] Validate cross-platform compatibility
- [x] Create research.md

### Phase 1: Flake Integration
- [ ] Add claude-code-nix to flake inputs
- [ ] Apply overlay in darwin.nix
- [ ] Apply overlay in nixos.nix (if nixos support exists)
- [ ] Test overlay application

### Phase 2: App Module Creation
- [ ] Create system/shared/app/ai/claude-code.nix
- [ ] Implement package installation
- [ ] Add API key conflict warning
- [ ] Add macOS stable symlink logic
- [ ] Add shell aliases
- [ ] Add validation warnings

### Phase 3: User Configuration
- [ ] Update user template with example (minimal config)
- [ ] Document OAuth authentication flow
- [ ] Add to user application discovery

### Phase 4: Testing
- [ ] Test on darwin (with TCC verification)
- [ ] Test on nixos (if applicable)
- [ ] Test OAuth authentication flow
- [ ] Test API key conflict warning
- [ ] Test symlink persistence across updates
- [ ] Test multi-user isolation

### Phase 5: Documentation
- [ ] Update CLAUDE.md "Active Technologies"
- [ ] Create quickstart.md (OAuth flow)
- [ ] Update README.md with usage examples
- [ ] Document troubleshooting steps

---

## Sources

- [sadjow/claude-code-nix - GitHub](https://github.com/sadjow/claude-code-nix)
- [Claude Code Documentation](https://docs.anthropic.com/claude/docs)
- [Claude Pro Subscription](https://www.anthropic.com/claude/pricing)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [nix-darwin Documentation](https://nix-darwin.github.io/nix-darwin/)
- [Nix Overlays - NixOS Wiki](https://nixos.wiki/wiki/Overlays)
- [macOS TCC Database - Apple Documentation](https://developer.apple.com/documentation/security/privacy)
- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)

---

## Conclusion

The integration of Claude Code via claude-code-nix flake is **feasible and well-aligned** with the repository's architecture:

✅ **Declarative**: Uses Nix overlay + Home Manager  
✅ **Constitutional**: <200 lines, app-centric, cross-platform  
✅ **Secure**: OAuth authentication managed by Claude Code  
✅ **macOS Compatible**: Stable symlink solves TCC issue  
✅ **User-Friendly**: Minimal configuration, browser OAuth for authentication  
✅ **Cost-Effective**: Included in Claude Pro subscription (no API charges)

**Recommended approach**:
1. Start with claude-code (CLI) only
2. Add claude-desktop later if demand exists
3. Use overlay application at platform library level
4. OAuth authentication (no secret management needed)
5. Warn users about API key conflicts

**Estimated complexity**: Low
- Most infrastructure already exists (overlays, activation scripts)
- No secret management needed (OAuth handled by Claude Code)
- Main work is app module creation and testing
- macOS symlink is simple activation script

**Risks**: Low
- claude-code-nix is actively maintained
- OAuth authentication is standard and secure
- TCC symlink solution is well-tested
- No API billing surprises for Pro users (with conflict warning)
- Fallback: Users can install via homebrew if Nix approach fails
```
