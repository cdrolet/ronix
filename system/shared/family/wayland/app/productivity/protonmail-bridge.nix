# Proton Mail Bridge - Local IMAP/SMTP server for Proton Mail
#
# Purpose: Run Proton Mail Bridge as a systemd user service so email clients
#          (Geary, Thunderbird, Evolution) can connect via local IMAP/SMTP.
# Platform: Linux (systemd user service)
# Website: https://proton.me/mail/bridge
#
# Requirements:
#   - Paid Proton subscription
#   - One-time interactive login (automated via XDG autostart on first login)
#
# First-login flow:
#   1. A terminal window opens automatically with protonmail-bridge --cli
#   2. User types "login" and enters Proton credentials + 2FA
#   3. After success, a marker file is created and the terminal won't reappear
#   4. The systemd service auto-starts on subsequent logins
#
# Email clients connect to: IMAP 127.0.0.1:1143, SMTP 127.0.0.1:1025
{
  config,
  pkgs,
  lib,
  ...
}: let
  emailLib = import ../../../../lib/email.nix {inherit lib;};
  email = config.user.email or null;
  hasEmail = email != null;
  isProtonEmail = emailLib.isProtonEmail email;

  markerFile = "$HOME/.config/protonmail/.bridge-setup-complete";

  # Inner script run inside the terminal
  bridgeSetupInner = pkgs.writeShellScript "protonmail-bridge-setup-inner" ''
    echo "========================================"
    echo "  Proton Mail Bridge - First-Time Setup"
    echo "========================================"
    echo ""

    # Stop the systemd service so CLI can acquire the lock
    echo "Stopping bridge service..."
    systemctl --user stop protonmail-bridge.service 2>/dev/null || true
    sleep 1

    echo "  1. Type: login"
    echo "  2. Enter your Proton email and password"
    echo "  3. Complete 2FA if prompted"
    echo "  4. Type: info  (to see your bridge password)"
    echo "  5. Type: exit"
    echo ""
    echo "  NOTE: After login, use 'info' to get the bridge password."
    echo "  You'll need it to configure your email client (Geary, Thunderbird, etc.)."
    echo "  Email client settings: IMAP 127.0.0.1:1143 / SMTP 127.0.0.1:1025"
    echo ""
    ${pkgs.protonmail-bridge}/bin/protonmail-bridge --cli

    # Restart the service after setup
    echo "Restarting bridge service..."
    systemctl --user start protonmail-bridge.service 2>/dev/null || true

    # Mark setup complete so the terminal doesn't reappear
    # If login failed, user can delete the marker and rebuild:
    #   rm ~/.config/protonmail/.bridge-setup-complete
    mkdir -p "$(dirname "${markerFile}")"
    touch "${markerFile}"
    echo ""
    echo "Setup complete! Bridge will auto-start on next login."
    echo "Press Enter to close..."
    read -r
  '';

  # Launch the user's configured terminal for interactive setup
  setupScript = pkgs.writeShellScript "protonmail-bridge-setup" ''
    # Skip if already configured
    if [ -f "${markerFile}" ]; then
      exit 0
    fi

    # Find a terminal: $TERMINAL env var > gsettings > notify fallback
    if [ -n "''${TERMINAL:-}" ] && command -v "$TERMINAL" >/dev/null 2>&1; then
      "$TERMINAL" -e ${bridgeSetupInner}
    elif command -v gsettings >/dev/null 2>&1; then
      TERM_EXEC=$(gsettings get org.gnome.desktop.default-applications.terminal exec 2>/dev/null | tr -d "'")
      TERM_ARG=$(gsettings get org.gnome.desktop.default-applications.terminal exec-arg 2>/dev/null | tr -d "'")
      if [ -n "$TERM_EXEC" ] && command -v "$TERM_EXEC" >/dev/null 2>&1; then
        "$TERM_EXEC" ''${TERM_ARG:+"$TERM_ARG"} ${bridgeSetupInner}
      else
        notify-send "Proton Mail Bridge" "Please run: protonmail-bridge --cli" 2>/dev/null || true
      fi
    else
      notify-send "Proton Mail Bridge" "Please run: protonmail-bridge --cli" 2>/dev/null || true
    fi
  '';
in {
  # Enable systemd user service (auto-starts after graphical session)
  services.protonmail-bridge = {
    enable = lib.mkDefault isProtonEmail;
    logLevel = lib.mkDefault "info";
  };

  # XDG autostart for first-login interactive setup
  xdg.configFile."autostart/protonmail-bridge-setup.desktop" = lib.mkIf isProtonEmail {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Proton Mail Bridge Setup
      Comment=First-time interactive setup for Proton Mail Bridge
      Exec=${setupScript}
      Hidden=false
      NoDisplay=true
      StartupNotify=false
    '';
  };

  # Warnings
  warnings =
    lib.optional (!hasEmail) ''
      Proton Mail Bridge: user.email not configured.
    ''
    ++ lib.optional (hasEmail && !isProtonEmail) ''
      Proton Mail Bridge: user.email is not a Proton address (@proton.me, @protonmail.com, or @pm.me).
    '';
}
