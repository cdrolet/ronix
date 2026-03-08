# Nix Type Schema: User Configuration with Applications Field
#
# Feature: 020-app-array-config
# Purpose: Define type contract for user.applications field
# Usage: Reference for implementation in user/shared/lib/home-manager.nix
{lib}: {
  # New option to be added to user/shared/lib/home-manager.nix
  options.user.applications = lib.mkOption {
    type = lib.types.nullOr (lib.types.listOf lib.types.str);
    default = null;
    description = ''
      List of application names to automatically discover and import.

      Applications are resolved from the platform application registry:
      - platform/shared/app/**/*.nix (cross-platform applications)
      - platform/{platform}/app/**/*.nix (platform-specific applications)

      The discovery system automatically handles:
      - Application name validation against registry
      - Platform-specific application availability
      - Helpful error messages for typos or missing apps
      - Graceful degradation for unavailable platform-specific apps

      When null (default), no automatic application imports occur.
      Users can still import applications explicitly using the discovery
      system's mkApplicationsModule function (backward compatible).

      Examples:
        # Minimal configuration (just git)
        applications = [ "git" ];

        # Full development environment
        applications = [
          # Development tools
          "git"
          "python"
          "nodejs"

          # Shell environment
          "zsh"
          "starship"
          "bat"

          # Editors
          "helix"
          "vscode"

          # Platform-specific (gracefully skipped if unavailable)
          "aerospace"  # Darwin only
        ];

        # No applications (explicit)
        applications = [];

        # Use old pattern (explicit discovery)
        applications = null;  # or omit the field entirely
    '';
    example = ["git" "zsh" "helix" "aerospace"];
  };

  # Implementation contract: conditional imports when applications != null
  # This is the implementation pattern, not an option definition
  config = lib.mkIf (config.user.applications != null) {
    imports = let
      discovery = import ../../platform/shared/lib/discovery.nix {inherit lib;};
    in [
      (discovery.mkApplicationsModule {
        inherit lib;
        applications = config.user.applications;
      })
    ];
  };
}
# Type Contract Specification
# ===========================
#
# Field: user.applications
# Type: null | [String]
# Default: null
# Required: No (optional)
#
# Type Constraints:
# - If null: No validation, no imports
# - If []: No imports (valid empty list)
# - If [String, ...]: Each element must be string type
#
# Validation (by discovery system):
# - Application name exists in registry
# - Application available on current platform (graceful skip for user configs)
# - Helpful error messages with suggestions
#
# Error Scenarios:
# 1. Type mismatch (caught by Nix type system):
#    applications = "git"
#    → ERROR: value is a string while a list was expected
#
# 2. Non-string element (caught by Nix type system):
#    applications = [ "git" 42 ]
#    → ERROR: value is an integer while a string was expected
#
# 3. Unknown application (caught by discovery system):
#    applications = [ "gti" ]
#    → ERROR: Application 'gti' not found in any platform
#              Did you mean one of these?
#                - git (in shared, darwin, nixos)
#
# 4. Platform-specific unavailable (handled gracefully):
#    applications = [ "aerospace" ]  # on NixOS
#    → No error, gracefully skipped (user config behavior)
#
# Success Scenarios:
# 1. Null or omitted:
#    applications = null  # or don't specify field
#    → No imports, backward compatible
#
# 2. Empty list:
#    applications = []
#    → No imports, explicit choice
#
# 3. Valid applications:
#    applications = [ "git" "zsh" "helix" ]
#    → Discovery resolves and imports all three
#
# 4. Mixed availability:
#    applications = [ "git" "zsh" "aerospace" ]  # on darwin
#    → All three imported
#    applications = [ "git" "zsh" "aerospace" ]  # on nixos
#    → git and zsh imported, aerospace gracefully skipped

