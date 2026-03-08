# Spec-Kit - AI-assisted specification tool
#
# Purpose: Create and maintain specification files with AI assistance
# Platform: Cross-platform (installed via uv tool)
# Repository: https://github.com/github/spec-kit
#
# Features:
#   - AI-assisted specification generation
#   - Specification validation and maintenance
#   - Integration with development workflows
#   - CLI tool: specify-cli
#
# Installation: Via uv tool (persistent installation from git)
# Command: uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
#
# Requirements:
#   - uv (Python package manager) must be in user.workspace.applications
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Install uv and python3 as dependencies (python3 needed on NixOS — uv can't
  # use its downloaded CPython because it's dynamically linked for generic Linux)
  home.packages = [pkgs.uv pkgs.python3];

  # Installation via uv tool (activation script)
  home.activation.installSpecKit = (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Install spec-kit using uv tool (full Nix store path — uv not in PATH during activation)
      # UV_PYTHON forces uv to use Nix-provided Python instead of downloading its own
      # (downloaded CPython is dynamically linked for generic Linux, which fails on NixOS)
      export UV_PYTHON="${pkgs.python3}/bin/python3"
      # Extend PATH so uv can find git (not in activation PATH)
      export PATH="${pkgs.git}/bin:$PATH"
      if [ -x "${pkgs.uv}/bin/uv" ]; then
        echo "Installing spec-kit via uv tool..."

        # Check if already installed
        if ${pkgs.uv}/bin/uv tool list 2>/dev/null | grep -q "specify-cli"; then
          echo "spec-kit (specify-cli) is already installed"
        else
          if ${pkgs.uv}/bin/uv tool install specify-cli --from git+https://github.com/github/spec-kit.git; then
            echo "spec-kit installed successfully"
          else
            echo "Warning: Failed to install spec-kit"
          fi
        fi
      else
        echo "Warning: uv not found, skipping spec-kit installation"
      fi
    ''
  );

  # Add uv tool bin to PATH so installed tools (specify-cli) are found
  home.sessionVariables.PATH = "$HOME/.local/bin:$PATH";

  # Shell aliases
  home.shellAliases = {
    spec = "specify-cli";
  };
}
