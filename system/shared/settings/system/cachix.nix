# Cachix Binary Cache Integration (System Level)
#
# Provides system-wide read-only access to default.cachix.org for all users.
#
# Feature: 034-cachix-integration
# Architecture:
#   - System-wide (this file): Read-only cache access (hardcoded token, safe)
#   - Per-user (home/cachix.nix): Optional write access (encrypted secrets, Stage 2)
#   - Platform: Cross-platform (darwin, nixos)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # System-wide binary cache configuration (read-only for all users)
  nix.settings = {
    # Add default.cachix.org as a substituter with high priority
    substituters = [
      "https://default.cachix.org?priority=10" # Higher priority than cache.nixos.org (40)
      "https://cache.nixos.org?priority=40"
    ];

    # Trusted public keys for signature verification
    trusted-public-keys = [
      "default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # System-wide read-only authentication
  # Read-only token is safe to hardcode (limited scope, no write access)
  environment.etc."nix/cachix-netrc".text = ''
    machine default.cachix.org
      login cachix
      password eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c
  '';

  # Configure Nix to use the system netrc file for cache authentication
  nix.settings.netrc-file = "/etc/nix/cachix-netrc";

  # NOTE: Per-user write access is configured in system/shared/settings/home/cachix.nix
  # It runs in Stage 2 (standalone home-manager) and creates user-level ~/.config/nix/netrc
}
