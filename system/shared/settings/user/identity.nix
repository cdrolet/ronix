# User Identity - Session Environment Variables
#
# Purpose: Export user identity (EMAIL) as session environment variables
# Platform: Cross-platform (home-manager)
#
# Handles both plain text and "<secret>" values:
# - Plain text: set via home.sessionVariables (static, build-time)
# - Secret: resolved at activation time, written to environment.d
#
# Constitutional: <200 lines, uses lib.mkDefault
{
  config,
  pkgs,
  lib,
  ...
}: let
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};

  email = config.user.email or null;
  hasEmail = email != null;
  isSecretEmail = email == "<secret>";
in
  lib.mkMerge [
    # Plain text email: set as session variable directly
    (lib.mkIf (hasEmail && !isSecretEmail) {
      home.sessionVariables.EMAIL = lib.mkDefault email;
    })

    # Secret email: resolve at activation time
    (lib.mkIf (hasEmail && isSecretEmail) {
      home.activation.setEmailEnv = secrets.mkActivationScript {
        inherit config pkgs lib;
        name = "identity";
        fields = {
          email = ''
            mkdir -p "$HOME/.config/environment.d"
            echo "EMAIL=$EMAIL" > "$HOME/.config/environment.d/identity.conf"
          '';
        };
      };
    })
  ]
