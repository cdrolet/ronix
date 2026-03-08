# Colima - Container runtime for macOS/Linux
#
# Purpose: Lightweight container runtime with minimal setup
# Platform: Cross-platform (macOS, Linux)
# Website: https://github.com/abiosoft/colima
#
# Features:
#   - Docker container runtime (alternative to Docker Desktop)
#   - Kubernetes support
#   - Containerd and Docker runtime options
#   - Lima VM-based (lightweight)
#   - Volume mounts support
#   - Port forwarding
#   - Rosetta 2 emulation on Apple Silicon
#
# Why Colima:
#   - Free alternative to Docker Desktop
#   - Lightweight and fast
#   - Native Apple Silicon support
#   - Minimal resource usage
#   - Compatible with Docker CLI
#
# Installation: Via nixpkgs (cross-platform)
#
# Usage:
#   colima start              # Start container runtime
#   colima stop               # Stop runtime
#   colima status             # Check status
#   colima ssh                # SSH into VM
#
# Then use docker CLI as normal:
#   docker run hello-world
#   docker-compose up
#
# Sources:
#   - https://github.com/abiosoft/colima
#   - https://medevel.com/colima/
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.colima];

  # Shell aliases
  home.shellAliases = {
    colima-start = "colima start";
    colima-stop = "colima stop";
    colima-status = "colima status";
  };
}
