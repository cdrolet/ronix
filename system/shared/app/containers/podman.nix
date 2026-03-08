# Podman - Daemonless container engine
#
# Purpose: Container management without requiring a daemon
# Platform: Cross-platform
# Website: https://podman.io/
#
# Features:
#   - Docker-compatible CLI
#   - Runs containers without root/daemon
#   - OCI-compliant
#   - Pod support (like Kubernetes pods)
#
# Installation: Via nixpkgs
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.podman];

  # Shell aliases for Docker compatibility
  home.shellAliases = {
    # Docker-compatible aliases
    podman-docker = "podman";
  };
}
