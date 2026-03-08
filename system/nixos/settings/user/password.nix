# User Password Activation (Home Manager)
#
# Purpose: Update user password from secrets during home-manager activation
# This runs in standalone home-manager mode (Feature 036)
# Feature 047: Uses direct rage decryption (no agenix)
#
# Requires:
# - user.security.password = "<secret>" in user config
# - password field in secrets.age (runtime, not committed to git)
# - sudo access to chpasswd (configured in NixOS system/nixos/settings/user.nix)
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};
  securityCfg = config.user.security;
  password = if securityCfg != null then securityCfg.password else null;
  isPasswordSecret = password != null && secrets.isSecret password;
in {
  # Feature 039: No context guard needed - file only imported in user/ context
  home.activation.setPasswordFromSecrets = lib.mkIf isPasswordSecret (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Update user password from secrets (Feature 047: direct rage decryption)
      ${secrets.mkFindSecretsSnippet config.user.name}
      _key="$HOME/.config/agenix/key.txt"

      if [ -z "$_secrets_file" ]; then
        echo "⚠ Warning: No secrets.age found — initial password is 'changeme'"
        echo "  Add your key at: $_key, then run: just install"
      elif [ ! -f "$_key" ]; then
        echo "⚠ Warning: No private key at $_key — password not updated"
      else
        PASSWORD_HASH=$(${pkgs.rage}/bin/rage -d -i "$_key" "$_secrets_file" 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.security.password // empty')

        if [ -n "$PASSWORD_HASH" ]; then
          echo "Updating password from secrets for ${config.user.name}..."

          # NixOS setuid wrapper path — Nix store binaries lack setuid, so NixOS
          # places wrapped binaries in /run/wrappers/bin (NOPASSWD for chpasswd
          # is configured in system/nixos/settings/system/user.nix)
          echo "${config.user.name}:$PASSWORD_HASH" | /run/wrappers/bin/sudo ${pkgs.shadow}/bin/chpasswd -e

          if [ $? -eq 0 ]; then
            echo "✓ Password updated successfully"

            # Reset GNOME Keyring — it's encrypted with the login password, so
            # a password change breaks it. Deleting forces recreation on next login.
            KEYRING_DIR="$HOME/.local/share/gnome-keyring/keyrings"
            if [ -d "$KEYRING_DIR" ]; then
              rm -rf "$KEYRING_DIR"
              echo "✓ Keyring reset (will be recreated on next login)"
            fi
          else
            echo "⚠ Warning: Failed to update password. Run 'sudo passwd ${config.user.name}' manually."
          fi
        else
          echo "⚠ Warning: 'security.password' not found in secrets file"
        fi
      fi
    ''
  );
}
