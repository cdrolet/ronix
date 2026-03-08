# Proton VPN - Secure VPN service
#
# Purpose: Privacy-focused VPN with Swiss security
# Platform: Cross-platform (macOS, Linux)
# Website: https://protonvpn.com/
#
# Features:
#   - No-logs VPN policy
#   - Swiss privacy laws
#   - Free tier available
#   - Kill switch and DNS leak protection
#
# Installation:
#   - macOS: Via Homebrew cask
#   - Linux: pkgs.protonvpn-gui + pkgs.proton-vpn-cli (nixpkgs)
#
# Auto-login (Linux only):
#   Set in user config:
#     user.email = "you@proton.me";           # used as login username
#     security.protonPassword = "<secret>";   # from secrets.age
#
#   The activation script calls `proton-vpn-cli login` automatically.
#   The GUI shares the same credential store, so a CLI login also authenticates the GUI.
#
#   Note: if the CLI cannot accept the password non-interactively, it will
#         print a fallback: proton-vpn-cli login --username <email>
{
  config,
  pkgs,
  lib,
  configContext ? "home-manager",
  ...
}: let
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};

  username = config.user.email or "";
  passwordValue = (config.user.security or {}).protonPassword or null;
  passwordIsSecret = secrets.isSecret passwordValue;

  # Login command — username is always user.email (plain string, Nix-interpolated)
  loginCmd = ''
    USERNAME="${username}"
    if [ -z "$USERNAME" ]; then
      echo "Proton VPN: set user.email to enable auto-login" >&2
    elif ${pkgs.proton-vpn-cli}/bin/proton-vpn-cli status &>/dev/null 2>&1; then
      echo "Proton VPN: already authenticated" >&2
    else
      echo "Proton VPN: logging in as $USERNAME..." >&2
      printf '%s\n' "$SECURITY_PROTONPASSWORD" | \
        ${pkgs.proton-vpn-cli}/bin/proton-vpn-cli login \
          --username "$USERNAME" 2>/dev/null \
        && echo "Proton VPN: login successful" >&2 \
        || echo "Proton VPN: auto-login failed — run: proton-vpn-cli login --username $USERNAME" >&2
    fi
  '';

  activationFields = lib.optionalAttrs passwordIsSecret {
    "security.protonPassword" = loginCmd;
  };
in
  lib.mkMerge [
    (lib.optionalAttrs (configContext == "darwin-system") {
      homebrew.casks = ["protonvpn"];
    })

    (lib.optionalAttrs (configContext == "home-manager") {
      home.packages = lib.mkIf pkgs.stdenv.isLinux [
        pkgs.protonvpn-gui
        pkgs.proton-vpn-cli
      ];

      home.activation.protonVpnLogin =
        lib.mkIf (activationFields != {} && pkgs.stdenv.isLinux)
        (secrets.mkActivationScript {
          inherit config pkgs lib;
          name = "proton-vpn";
          fields = activationFields;
        });
    })
  ]
