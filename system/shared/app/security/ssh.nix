# SSH Client Configuration
#
# Purpose: SSH client with support for multiple keys via nested secrets
# Dependencies: secrets.nix helper library
# Platform: Cross-platform (macOS, Linux)
#
# Feature 029: Demonstrates nested secrets usage for SSH key management
#
# User config example:
#   user = {
#     security = {
#       sshKeys = {
#         personal = "<secret>";
#         work = "<secret>";
#       };
#     };
#   };
#
# Secrets.age structure:
#   {
#     "sshKeys": {
#       "personal": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
#       "work": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
#     }
#   }
{
  config,
  pkgs,
  lib,
  ...
}: let
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};
in {
  # SSH client configuration
  programs.ssh = {
    enable = lib.mkDefault true;

    # Disable default configuration to avoid deprecation warning
    enableDefaultConfig = false;

    # Default host configuration (replaces enableDefaultConfig = true)
    matchBlocks."*" = {
      extraOptions = {
        AddKeysToAgent = "yes";
        IdentitiesOnly = "yes";
      };
    };
  };

  # Deploy SSH keys from nested secrets at activation time
  # Only runs if user has security.sshKeys.personal = "<secret>" in their config
  home.activation.applySSHSecrets = secrets.mkActivationScript {
    inherit config pkgs lib;
    name = "ssh";
    fields = {
      # Primary SSH key (personal)
      "security.sshKeys.personal" = ''
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        echo "$SECURITY_SSHKEYS_PERSONAL" > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
        ${pkgs.openssh}/bin/ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub 2>/dev/null || true
        chmod 644 ~/.ssh/id_ed25519.pub 2>/dev/null || true
      '';

      # Feature 030: Deploy key for private font repositories
      "security.sshKeys.fonts" = ''
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        echo "$SECURITY_SSHKEYS_FONTS" > ~/.ssh/id_fonts
        chmod 600 ~/.ssh/id_fonts
        ${pkgs.openssh}/bin/ssh-keygen -y -f ~/.ssh/id_fonts > ~/.ssh/id_fonts.pub 2>/dev/null || true
        chmod 644 ~/.ssh/id_fonts.pub 2>/dev/null || true
      '';
    };
  };
}
