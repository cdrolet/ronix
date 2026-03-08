# Contract: User Cachix Configuration
#
# This contract defines the user-facing API for configuring Cachix write access.
# All users automatically benefit from system-wide read-only access to default.cachix.org.
# This configuration is OPTIONAL - only needed for users who want write access (push builds).
#
# Feature: 034-cachix-integration

{ config, lib, ... }:

{
  options.user.cachix = {
    # Write authentication token (optional - secret placeholder)
    authToken = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Write authentication token for pushing builds to Cachix cache.

        OPTIONAL - Only configure if you want to push builds to the cache.
        Without this, you still get read-only access (system default).

        MUST use the "<secret>" placeholder pattern.
        Actual token stored in user/{name}/secrets.age (encrypted).

        Token obtained from: https://app.cachix.org/personal-auth-tokens
        Required scope: "cache" (read-write)

        Usage after configuring:
          just build-and-push username hostname  # Build and push in one command

        If undefined: User has read-only access (system default, no push ability)
        If defined: User can push builds via "just build-and-push"
      '';
      example = "<secret>";
    };

    # Cache name (optional, defaults to "default")
    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = ''
        Name of the Cachix cache to push to.

        Default: "default" (default.cachix.org)
        Override to push to a different cache (requires matching authToken).

        Format: alphanumeric + hyphens, 3-50 characters
        Example: "my-org-cache", "team-cache-123"
      '';
      example = "default";
    };
  };

  # Validation rules
  config = lib.mkIf (config.user ? cachix && config.user.cachix.authToken != null) {
    assertions = [
      {
        assertion = config.user.cachix.authToken == "<secret>";
        message = ''
          user.cachix.authToken must use the "<secret>" placeholder.
          Store the actual token using: just secrets-set ${config.user.name} cachix.authToken "your-token"
        '';
      }
      {
        assertion = let
          name = config.user.cachix.cacheName;
          valid = builtins.match "^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$" name != null;
        in valid;
        message = ''
          user.cachix.cacheName must be alphanumeric + hyphens, 3-50 characters.
          Examples: "default", "my-cache", "org-cache-123"
        '';
      }
    ];
  };
}

# ============================================================================
# Usage Examples
# ============================================================================

# Example 1: Read-only access (no configuration needed)
# -----------------------------------------------------
# Just don't configure user.cachix at all!
#
# user = {
#   name = "username";
#   applications = ["*"];
#   # No cachix config - automatically gets read-only access to default.cachix.org
# };
#
# Benefits:
#   ✓ Downloads from default.cachix.org (fast builds)
#   ✗ Cannot push builds to cache

# Example 2: Write access to default cache
# ------------------------------------------
# user = {
#   name = "username";
#   applications = ["*"];
#
#   cachix = {
#     authToken = "<secret>";  # Write token
#     # cacheName defaults to "default"
#   };
# };
#
# Setup:
#   just secrets-set username cachix.authToken "eyJhbGc..."
#   just install username hostname
#
# Usage:
#   just build-and-push username hostname  # Builds and pushes to default.cachix.org
#
# Benefits:
#   ✓ Downloads from default.cachix.org
#   ✓ Can push builds to cache

# Example 3: Write access to custom cache
# -----------------------------------------
# user = {
#   name = "username";
#   applications = ["*"];
#
#   cachix = {
#     authToken = "<secret>";
#     cacheName = "my-org-cache";  # Override to different cache
#   };
# };
#
# Setup:
#   just secrets-set username cachix.authToken "write-token-for-my-org-cache"
#   just install username hostname
#
# Usage:
#   just build-and-push username hostname  # Builds and pushes to my-org-cache.cachix.org
#
# Benefits:
#   ✓ Downloads from default.cachix.org (read-only, system default)
#   ✓ Downloads from my-org-cache.cachix.org (write token)
#   ✓ Can push builds to my-org-cache

# Example 4: Secret storage format
# ----------------------------------
# File: user/username/secrets.age (encrypted JSON)
#
# Decrypted content:
# {
#   "email": "user@example.com",
#   "cachix": {
#     "authToken": "eyJhbGciOiJIUzI1NiJ9..."
#   }
# }
#
# Set with:
#   just secrets-set username cachix.authToken "eyJhbGc..."
