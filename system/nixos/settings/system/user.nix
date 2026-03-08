# User Settings (System-Level)
#
# Purpose: Create system user account on NixOS
# Feature 039: System-level only - password setting moved to settings/user/password.nix
#
# Two-phase approach:
#   1. System level (this file): Create user with temporary password
#   2. Home-manager (settings/user/password.nix): Update password from agenix secrets
{
  config,
  lib,
  pkgs,
  ...
}: let
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};
  securityCfg = config.user.security;
  password = if securityCfg != null then securityCfg.password else null;
  isPasswordSecret = password != null && secrets.isSecret password;
in {
  # System-level: Create the user account
  users.users.${config.user.name} =
    {
      isNormalUser = true;
      description = config.user.fullName or config.user.name;
      extraGroups = ["wheel" "networkmanager" "video" "audio"];
      shell = pkgs.zsh;

      # Use hashed password if provided directly (not a secret)
      # Otherwise use temporary password that will be updated by home-manager
    }
    // lib.optionalAttrs (!isPasswordSecret && password != null) {
      hashedPassword = password;
    }
    // lib.optionalAttrs (password == null || isPasswordSecret) {
      initialPassword = "changeme";
    };

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Allow wheel group to use sudo
  security.sudo.wheelNeedsPassword = lib.mkDefault true;

  # Allow wheel group to run chpasswd without password (for home-manager activation)
  # This enables system/shared/settings/user/password.nix to update passwords
  # SETENV is needed so sudo doesn't strip environment in non-interactive contexts
  security.sudo.extraRules = [
    {
      groups = ["wheel"];
      commands = [
        {
          command = "${pkgs.shadow}/bin/chpasswd";
          options = ["NOPASSWD" "SETENV"];
        }
      ];
    }
  ];

  # Allow sudo without a TTY (needed for first-boot systemd service)
  security.sudo.extraConfig = ''
    Defaults !requiretty
  '';
}
