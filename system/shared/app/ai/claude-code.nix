# Claude Code - AI-powered coding assistant
# Official CLI interface for Claude with code editing capabilities
#
# Feature 035: claude-apps-integration
#
# Authentication:
#   - Claude Pro subscribers: Use OAuth authentication (browser-based)
#   - API users: Set ANTHROPIC_API_KEY (will incur API charges)
#
# Configuration:
#   - Config location: ~/.claude/settings.json
#   - First run: Interactive OAuth setup or API key entry
#   - Persistence: All user data persists across Nix rebuilds
#
# Stable Symlink:
#   - Symlink created at ~/.local/bin/claude
#   - Prevents permission re-prompting after Nix updates (macOS TCC)
#   - Provides stable PATH entry across all platforms
#
# Dependencies:
#   - claude-code-nix overlay (Feature 035)
#   - pkgs.claude-code provided by overlay
{
  config,
  pkgs,
  lib,
  inputs ? {},
  ...
}: let
  # API key conflict detection (Claude Pro users should NOT use API keys)
  hasApiKey = builtins.getEnv "ANTHROPIC_API_KEY" != "";

  # ============================================================================
  # Font Configuration (Feature 030)
  # ============================================================================
  monoConfig = ((config.user.style or {}).fonts or {}).defaults.monospace or {};
  monoFamilies = monoConfig.families or [];
  monoSize = monoConfig.size or 12;
  hasMonoFont = monoFamilies != [];

  # ============================================================================
  # Claude Code Settings
  # ============================================================================
  claudeSettings = {
    # Editor appearance
    "editor.fontSize" = monoSize;
    "editor.fontFamily" = lib.mkIf hasMonoFont (lib.concatStringsSep ", " monoFamilies);
    "editor.fontLigatures" = true;

    # Editor behavior
    "editor.tabSize" = 2;
    "editor.insertSpaces" = true;

    # Telemetry
    "telemetry.telemetryLevel" = "off";
  };
in {
  # ============================================================================
  # Overlay Declaration (App-Centric)
  # ============================================================================
  # Apps declare their required overlays here
  # System modules extract and apply these automatically
  nixpkgs.overlays = lib.optionals (inputs ? claude-code-nix) [
    inputs.claude-code-nix.overlays.default
  ];

  # Warning: Prevent Claude Pro users from accidentally using API billing
  warnings = lib.optional hasApiKey ''
    WARNING: ANTHROPIC_API_KEY environment variable detected.

    Claude Pro subscribers should NOT use API keys for Claude Code.
    Using an API key will result in API usage charges instead of using
    your included Pro subscription.

    To use your Claude Pro subscription:
      1. Remove or unset ANTHROPIC_API_KEY
      2. Run 'claude' and select "Claude account with subscription"
      3. Complete OAuth login in browser

    If you intentionally want to use API billing, you can ignore this warning.
  '';

  # ============================================================================
  # Installation
  # ============================================================================
  home.packages = [
    pkgs.claude-code
  ];

  # ============================================================================
  # Configuration File Generation
  # ============================================================================
  home.file.".claude/settings.json" = {
    text = builtins.toJSON claudeSettings;
  };

  # ============================================================================
  # Shell Aliases
  # ============================================================================
  home.shellAliases = {
    cc = "claude";
    claude-version = "claude --version";
  };

  # ============================================================================
  # Stable Symlink (All Platforms)
  # ============================================================================
  # Create stable symlink at ~/.local/bin/claude
  # - macOS: Prevents TCC permission re-prompting after Nix updates
  # - All platforms: Stable PATH entry independent of Nix store paths
  home.activation.createClaudeSymlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Create ~/.local/bin if it doesn't exist
    $DRY_RUN_CMD mkdir -p "$HOME/.local/bin"

    # Create stable symlink to claude binary
    $DRY_RUN_CMD ln -sf "${pkgs.claude-code}/bin/claude" "$HOME/.local/bin/claude"

    $VERBOSE_ECHO "Created stable Claude Code symlink at ~/.local/bin/claude"
  '';

  # Add ~/.local/bin to PATH for stable symlink access
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Configuration persistence notice (Feature 035 - US3)
  # Claude Code manages its own configuration in ~/.claude/
  # This is intentionally NOT managed by Nix to preserve:
  #   - OAuth credentials
  #   - Workspace data
  #   - Conversation history
  #   - User preferences
  #
  # All data in ~/.claude/ persists across Nix rebuilds.
}
