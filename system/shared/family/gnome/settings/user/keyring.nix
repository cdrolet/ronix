# GNOME Keyring Settings
#
# GNOME keyring integration for SSH authentication
# Allows GNOME keyring to manage SSH keys
{
  config,
  lib,
  pkgs,
  ...
}: {
  # GNOME-specific environment variables
  home.sessionVariables = {
    # Use GNOME keyring for SSH
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/keyring/ssh";
  };
}
