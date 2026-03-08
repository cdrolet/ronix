# Docker - Container platform
#
# Purpose: Build, run, and manage containers
# Platform: Cross-platform
# Website: https://www.docker.com/
#
# Features:
#   - Industry-standard container runtime
#   - Docker Compose support
#   - Container image building
#   - Registry integration
#
# Note: Docker requires system-level daemon installation
#   - macOS: Install Docker Desktop via Homebrew cask
#   - Linux: Docker daemon configured at system level
#
# This module provides the Docker CLI tools
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    docker
    docker-compose
  ];

  # Shell aliases
  home.shellAliases = {
    dps = "docker ps";
    dimg = "docker images";
    dlog = "docker logs";
    dexec = "docker exec -it";
  };
}
