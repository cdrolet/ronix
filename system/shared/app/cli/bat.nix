{
  config,
  pkgs,
  lib,
  ...
}: let
  # Override batgrep to skip tests (tests have snapshot mismatches)
  batgrep-fixed = pkgs.bat-extras.batgrep.overrideAttrs (oldAttrs: {
    doCheck = false;
  });
in {
  # Bat - A cat(1) clone with syntax highlighting and Git integration
  # Enhanced version of cat with syntax highlighting, line numbers, and git diff support

  programs.bat = {
    enable = true;

    # Bat configuration
    config = {
      pager = "less -FR";
      style = "numbers,changes,header";
      italic-text = "always";
    };

    # Additional bat-extras tools (integrated with bat config)
    extraPackages = [
      pkgs.bat-extras.batdiff
      pkgs.bat-extras.batman
      batgrep-fixed
      pkgs.bat-extras.batwatch
    ];
  };

  # Shell aliases for bat
  home.shellAliases = {
    bathelp = "bat --help";
  };
}
