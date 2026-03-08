# First Boot Home Manager Setup
#
# Purpose: Automatically run home-manager on first login after fresh NixOS install
# This creates a systemd service that runs once and disables itself
#
# The service:
#   1. Checks for a marker file indicating fresh install
#   2. Clones the nix-config repository (and private config repo if URL on line 4)
#   3. Runs home-manager activation (age key must already exist)
#   4. Removes the marker file
#
# Marker file format (4 lines):
#   Line 1: USER_NAME
#   Line 2: HOST_NAME
#   Line 3: FRAMEWORK_REPO_URL
#   Line 4: PRIVATE_REPO_URL (optional, Feature 047)
#
# Systemd Ordering (Feature 040):
# - before = ["display-manager.service"] blocks GDM from starting until activation completes
# - This ensures password, dconf settings, and desktop files exist before first login
# - Result: Everything works on first login (password, theme, apps)
#
# Feature 047: If line 4 contains a URL, the private config repo is cloned to
# $HOME/.config/nix-private and --override-input is passed to nix build.
# The age private key must be installed during system installation
# (install-remote.sh prompts for it and copies it to the new system)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Create the first-boot setup script
  environment.etc."nix-config-first-boot.sh" = {
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      set -e
      set -x  # Enable verbose logging

      # Set XDG_RUNTIME_DIR if not set (required for home-manager)
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      # dconf requires a dbus session to persist settings. Without this,
      # home-manager dconf writes silently fail and the theme/settings
      # don't apply until the next login.
      if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
        eval "$(${pkgs.dbus}/bin/dbus-launch --sh-syntax)"
        STARTED_DBUS=1
      fi

      MARKER_FILE="$HOME/.nix-config-first-boot"
      CONFIG_DIR="$HOME/.config/nix-config"
      PRIVATE_CONFIG_DIR="$HOME/.config/nix-private"

      # Only run if marker file exists
      if [[ ! -f "$MARKER_FILE" ]]; then
        echo "==> Marker file not found, exiting"
        exit 0
      fi

      echo "==> First boot detected, setting up user environment..."
      echo "==> This is a one-time process that will take 2-5 minutes."

      # Read user, host, repo URL, and optional private repo URL from marker file
      USER_NAME=$(${pkgs.coreutils}/bin/head -n1 "$MARKER_FILE")
      HOST_NAME=$(${pkgs.coreutils}/bin/head -n2 "$MARKER_FILE" | ${pkgs.coreutils}/bin/tail -n1)
      REPO_URL=$(${pkgs.coreutils}/bin/head -n3 "$MARKER_FILE" | ${pkgs.coreutils}/bin/tail -n1)
      PRIVATE_REPO_URL=$(${pkgs.coreutils}/bin/head -n4 "$MARKER_FILE" | ${pkgs.coreutils}/bin/tail -n1)
      # Validate private repo URL is present (mandatory — Feature 047)
      if [ "$PRIVATE_REPO_URL" = "$REPO_URL" ] || [ -z "$PRIVATE_REPO_URL" ]; then
        echo "ERROR: Marker file missing private repo URL (line 4)"
        exit 1
      fi

      echo "User: $USER_NAME"
      echo "Host: $HOST_NAME"
      echo "Repo: $REPO_URL"
      echo "Private repo: $PRIVATE_REPO_URL"

      # Clone framework repository if not exists
      if [[ ! -d "$CONFIG_DIR" ]]; then
        echo "==> [1/5] Cloning nix-config repository..."
        ${pkgs.git}/bin/git clone "$REPO_URL" "$CONFIG_DIR" || {
          echo "ERROR: Failed to clone repository"
          exit 1
        }
      fi

      # Clone private config repo (mandatory — Feature 047)
      if [[ ! -d "$PRIVATE_CONFIG_DIR" ]]; then
        echo "==> [2/5] Cloning private config repository..."
        ${pkgs.git}/bin/git clone "$PRIVATE_REPO_URL" "$PRIVATE_CONFIG_DIR" || {
          echo "ERROR: Failed to clone private config repo"
          exit 1
        }
      fi

      # Build override arg (always set — private config is mandatory)
      PRIVATE_OVERRIDE="--override-input user-host-config path:$PRIVATE_CONFIG_DIR"

      cd "$CONFIG_DIR" || {
        echo "ERROR: Failed to cd to $CONFIG_DIR"
        exit 1
      }

      # Create home-manager profile directory
      ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/state/nix/profiles"

      # Run home-manager switch (standalone mode)
      echo "==> [3/5] Building home-manager configuration..."
      export NIX_CONFIG="experimental-features = nix-command flakes"

      # Build the activation package (with private config override if present)
      ${pkgs.nix}/bin/nix build $PRIVATE_OVERRIDE \
        ".#homeConfigurations.\"$USER_NAME@$HOST_NAME\".activationPackage" -o result || {
        echo "ERROR: Failed to build home-manager activation package"
        exit 1
      }

      # Create the profile generation link
      ${pkgs.nix}/bin/nix-env --profile "$HOME/.local/state/nix/profiles/home-manager" --set ./result || {
        echo "ERROR: Failed to create profile link"
        exit 1
      }

      # Run activation (backup existing files that would conflict)
      echo "==> [4/5] Installing user applications..."
      HOME_MANAGER_BACKUP_EXT=bak ./result/activate || {
        echo "ERROR: Failed to run activation script"
        exit 1
      }

      # Set password from secrets (Feature 047: direct rage decryption)
      # home-manager also does this, but sudo may fail in a non-interactive service.
      AGENIX_KEY="$HOME/.config/agenix/key.txt"
      SECRETS_FILE="$PRIVATE_CONFIG_DIR/users/$USER_NAME/secrets.age"
      if [ -f "$AGENIX_KEY" ] && [ -f "$SECRETS_FILE" ]; then
        PASSWORD_HASH=$(${pkgs.rage}/bin/rage -d -i "$AGENIX_KEY" "$SECRETS_FILE" 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.security.password // empty')
        if [ -n "$PASSWORD_HASH" ]; then
          echo "==> Setting password from secrets..."
          echo "$USER_NAME:$PASSWORD_HASH" | /run/wrappers/bin/sudo ${pkgs.shadow}/bin/chpasswd -e \
            && echo "✓ Password set" \
            || echo "⚠ Password update failed (will retry on next login)"
        fi
      fi

      # Remove marker file to prevent running again
      ${pkgs.coreutils}/bin/rm -f "$MARKER_FILE"

      # Clean up private dbus session if we started one
      if [ "''${STARTED_DBUS:-}" = "1" ] && [ -n "''${DBUS_SESSION_BUS_PID:-}" ]; then
        kill "$DBUS_SESSION_BUS_PID" 2>/dev/null || true
      fi

      echo "==> [5/5] Activation complete!"
      echo "==> Setup complete! Starting login screen..."
    '';
  };

  # Ensure /run/user/<uid> exists at boot (logind creates it on login, but first-boot
  # service runs before any user session starts)
  systemd.tmpfiles.rules = [
    "d /run/user/1000 0700 ${config.user.name} users"
  ];

  # Systemd system service to run before user login
  # Runs after network is available but before GDM login screen
  # CRITICAL: before display-manager.service ensures password, dconf settings,
  # and desktop files all exist before the user can log in for the first time.
  # (before graphical.target alone is insufficient — GDM starts *to reach* the
  # target and can race ahead of units that are merely "before" the target)
  systemd.services.nix-config-first-boot = {
    description = "First boot home-manager setup";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    requires = ["network-online.target"];
    before = ["display-manager.service"]; # Block GDM until activation completes

    # Only run if marker file exists for the user
    unitConfig = {
      ConditionPathExists = "/home/${config.user.name}/.nix-config-first-boot";
    };

    serviceConfig = {
      Type = "oneshot";
      User = config.user.name;
      Group = "users";
      ExecStart = "/etc/nix-config-first-boot.sh";
      RemainAfterExit = true;
      StandardOutput = "journal";
      StandardError = "journal";
      # Set PATH and HOME for the user
      Environment = [
        "PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/run/wrappers/bin:${pkgs.git}/bin:${pkgs.nix}/bin:${pkgs.coreutils}/bin"
        "HOME=/home/${config.user.name}"
      ];
    };
  };
}
