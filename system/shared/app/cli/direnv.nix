{
  config,
  pkgs,
  lib,
  ...
}: {
  # direnv - Load environment variables based on directory
  # Automatically loads .envrc files when entering directories
  # Dependencies: None

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };
}
