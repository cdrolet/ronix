# Contract: System Cachix Configuration
#
# This contract defines the system-level Cachix configuration API.
# Provides read-only access to default.cachix.org for all users automatically.
#
# Feature: 034-cachix-integration

{ config, lib, pkgs, ... }:

{
  # System-wide Cachix configuration (read-only default)
  options.nix.settings = {
    # Binary cache substituters
    substituters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "https://cache.nixos.org"
      ];
      description = ''
        List of binary cache URLs to query for pre-built packages.

        Order matters: caches are queried left-to-right (first match wins).
        Use priority parameter for explicit ordering: ?priority=10

        Default configuration includes:
          - https://default.cachix.org?priority=10  (read-only, all users)
          - https://cache.nixos.org?priority=40     (official cache)

        Format: https://{cache}.cachix.org or custom URL
      '';
      example = [
        "https://default.cachix.org?priority=10"
        "https://cache.nixos.org?priority=40"
        "https://nix-community.cachix.org?priority=20"
      ];
    };

    # Trusted public keys for signature verification
    trusted-public-keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
      description = ''
        Public keys for verifying package signatures from caches.

        REQUIRED for each cache in substituters list.
        Prevents cache poisoning attacks.

        Default configuration includes:
          - default.cachix.org public key (for read-only access)
          - cache.nixos.org public key (official cache)

        Format: {cache-name}.cachix.org-1:{base64-key}

        Get public key from: https://{cache}.cachix.org/api/v1/cache
      '';
      example = [
        "default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    # Trusted users allowed to add substituters
    trusted-users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "@admin" "@wheel" ];
      description = ''
        Users/groups allowed to add binary caches dynamically.

        Format:
          - User: "username"
          - Group: "@groupname"

        Security consideration: Trusted users can add any cache,
        potentially compromising package integrity.
      '';
      example = [ "root" "@admin" "@wheel" ];
    };
  };

  # System-level netrc for read-only authentication (optional approach)
  # Alternative: Use environment variables or hard-coded in module
  options.environment.etc."nix/netrc" = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = ''
      System-wide netrc file for Nix cache authentication.

      Used for read-only authentication to default.cachix.org.
      Hardcoded read-only token is safe (limited scope, no write access).

      Location: /etc/nix/netrc
      Permissions: 644 (world-readable, contains read-only token)

      Format:
        machine default.cachix.org
          login cachix
          password <read-only-token>
    '';
    example = {
      text = ''
        machine default.cachix.org
          login cachix
          password eyJhbGciOiJIUzI1NiJ9...
      '';
    };
  };
}

# ============================================================================
# Implementation Notes
# ============================================================================

# The actual implementation in system/shared/settings/cachix.nix will:
#
# 1. Configure system-wide read-only access:
#    nix.settings = {
#      substituters = [
#        "https://default.cachix.org?priority=10"
#        "https://cache.nixos.org?priority=40"
#      ];
#
#      trusted-public-keys = [
#        "default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs="
#        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
#      ];
#    };
#
# 2. Provide read-only authentication (pick one approach):
#
#    Option A - System netrc file (simpler):
#      environment.etc."nix/netrc".text = ''
#        machine default.cachix.org
#          login cachix
#          password eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c
#      '';
#      nix.settings.netrc-file = "/etc/nix/netrc";
#
#    Option B - Environment variable:
#      nix.extraOptions = ''
#        !include ${pkgs.writeText "cachix-env" ''
#          export CACHIX_AUTH_TOKEN="eyJhbGc..."
#        ''}
#      '';
#
# 3. Per-user write access (home-manager activation script):
#    Users with user.cachix.authToken = "<secret>" get:
#      - User-level netrc: ~/.config/nix/netrc
#      - Generated at activation time from secrets.age
#      - Enables: just push-cache

# ============================================================================
# Usage Examples
# ============================================================================

# Example: Standard host configuration
# -------------------------------------
# system/darwin/host/home-macmini-m4/default.nix
# {
#   name = "home-macmini-m4";
#   family = [];
#   applications = ["*"];
#   settings = ["default"];
#   # Cachix read-only access is automatic - no configuration needed
# }

# ============================================================================
# Cache Details (Reference)
# ============================================================================

# Cache Name: default
# URL: https://default.cachix.org
# Public Key: default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=
# Read-Only Token (safe to hardcode): eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c
# Read-Write Token (per-user secret): eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI0ODhkNjViNy1hMTE2LTQzNDYtYTMwNS1kYTAyZmFlN2FhZWIiLCJzY29wZXMiOiJjYWNoZSJ9.uAtsEJmBmRmt1mZErn5wo2mNWGJ7ognHSUAWstxAHHg
# Priority: 10 (higher than cache.nixos.org at 40)
