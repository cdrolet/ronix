# treefmt-nix configuration
# Multi-language formatter configuration for the repository
#
# Usage: nix fmt (formats all files)
# Check: nix flake check (includes formatting check)
#
# Supported file types:
# - Nix (.nix) - alejandra
# - Markdown (.md) - mdformat
# - Shell (.sh) - shfmt
# - JSON (.json) - prettier
# - YAML (.yaml, .yml) - prettier
# - TOML (.toml) - taplo
{...}: {
  # Root marker for treefmt to find project boundary
  projectRootFile = "flake.nix";

  # Nix formatter - alejandra (opinionated, fast)
  programs.alejandra = {
    enable = true;
    excludes = [
      "specs/*" # Design documents with example/pseudo-code
    ];
  };

  # Markdown formatter
  programs.mdformat.enable = true;

  # Shell script formatter
  programs.shfmt = {
    enable = true;
    indent_size = 2;
  };

  # JSON/YAML formatter
  programs.prettier = {
    enable = true;
    includes = [
      "*.json"
      "*.yaml"
      "*.yml"
    ];
    excludes = [
      "flake.lock" # Auto-generated, don't format
    ];
  };

  # TOML formatter
  programs.taplo.enable = true;
}
