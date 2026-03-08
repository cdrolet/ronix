# Proton Mail - Encrypted email desktop app
#
# Purpose: Native desktop client for Proton Mail
# Platform: Cross-platform (macOS, Linux)
# Website: https://proton.me/mail
#
# Features:
#   - End-to-end encrypted email
#   - Offline email access
#   - Integrated Proton Calendar
#   - Native desktop integration
#
# Requirements:
#   - Paid Proton subscription (not available for free users)
#   - Proton account email/password
#
# Installation:
#   - macOS: Via Homebrew cask
#   - Linux: pkgs.protonmail-desktop (nixpkgs)
{
  config,
  pkgs,
  lib,
  configContext ? "home-manager",
  system ? "",
  ...
}: let
  emailLib = import ../../lib/email.nix {inherit lib;};
  email = config.user.email or null;
  hasProtonEmail = email != null;
  protonEmailConfigured = emailLib.isProtonEmail email;
  isLinux = configContext != "darwin-system" && !(lib.hasSuffix "darwin" system);
  # protonmail-desktop only provides x86_64-linux binaries
  isLinuxX86 = isLinux && lib.hasPrefix "x86_64" system;
in
  lib.mkMerge [
    (lib.optionalAttrs (configContext == "darwin-system") {
      homebrew.casks = ["proton-mail"];
    })

    (lib.optionalAttrs isLinuxX86 {
      home.packages = [pkgs.protonmail-desktop];
    })

    {
      warnings =
        lib.optional (!hasProtonEmail) ''
          Proton Mail requires a Proton account.
          Configure user.email with your Proton email address.
        ''
        ++ lib.optional (!protonEmailConfigured && hasProtonEmail) ''
          Note: user.email is not a Proton address (@proton.me, @protonmail.com, or @pm.me).
          Proton Mail requires a paid Proton subscription.
        '';
    }
  ]
