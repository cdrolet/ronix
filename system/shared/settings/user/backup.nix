# Shared Settings: Restic Backup (Backblaze B2)
#
# Purpose: Declarative encrypted backup via Restic targeting a B2 S3-compatible bucket
# Platform: Cross-platform (macOS, Linux)
#
# This module:
# 1. Writes ~/.config/restic/env at activation (credentials from secrets.age)
# 2. Installs ~/.local/bin/nix-backup wrapper script (paths/retention baked in)
# 3. Sources env file in bash/zsh so interactive `restic` commands work
# 4. Runs `restic init` automatically on first backup
#
# Activation: Runs after ["writeBoundary"]
# Scheduling: Handled by platform-specific modules (darwin/backup.nix, wayland/backup.nix)
#
# Default backup paths:
#   ~/Documents  ~/Pictures  ~/Videos  ~/Music  ~/project
#   ~/.config/agenix  ~/.gnupg  ~/.ssh  ~/.local/share
#
# Default excludes:
#   ~/.local/share/nix-config  ~/.local/share/Trash
#   **/node_modules  **/.git  **/*.tmp
{
  config,
  lib,
  pkgs,
  ...
}: let
  backupCfg = config.user.backup or null;
  hasBackup = backupCfg != null;
in
  lib.mkIf hasBackup (let
    repo = backupCfg.repository;
    retain = backupCfg.retain;
    home = config.home.homeDirectory;
    name = config.user.name;

    # Restic repository URL (S3-compatible B2 endpoint)
    repoUrl = "s3:https://${repo.endpoint}/${repo.bucket}";

    # Extra paths joined as shell arguments (baked in at eval time)
    extraPaths = lib.concatMapStringsSep " " (p: ''"${p}"'') backupCfg.paths;

    # Extra exclude flags (baked in at eval time)
    extraExcludes = lib.concatMapStringsSep " " (p: "--exclude '${p}'") backupCfg.exclude;

    # The backup script — installed at ~/.local/bin/nix-backup
    backupScript = pkgs.writeShellScript "nix-backup" ''
      set -euo pipefail

      ENV_FILE="${home}/.config/restic/env"

      if [ ! -f "$ENV_FILE" ]; then
        echo "Error: restic credentials not found at $ENV_FILE"
        echo "Run 'just install' to regenerate credentials from secrets."
        exit 1
      fi

      # shellcheck source=/dev/null
      source "$ENV_FILE"

      # Initialize repository on first run
      if ! ${pkgs.restic}/bin/restic snapshots &>/dev/null; then
        echo "==> Initializing restic repository..."
        ${pkgs.restic}/bin/restic init
        echo "✓ Repository initialized"
        echo ""
      fi

      echo "==> Running backup to ${repoUrl}..."
      ${pkgs.restic}/bin/restic backup \
        "${home}/Documents" \
        "${home}/Pictures" \
        "${home}/Videos" \
        "${home}/Music" \
        "${home}/project" \
        "${home}/.config/agenix" \
        "${home}/.gnupg" \
        "${home}/.ssh" \
        "${home}/.local/share" \
        ${extraPaths} \
        --exclude "${home}/.local/share/nix-config" \
        --exclude "${home}/.local/share/Trash" \
        --exclude '**/node_modules' \
        --exclude '**/.git' \
        --exclude '**/*.tmp' \
        ${extraExcludes} \
        --verbose

      echo ""
      echo "==> Pruning old snapshots..."
      ${pkgs.restic}/bin/restic forget \
        --keep-daily ${toString retain.daily} \
        --keep-weekly ${toString retain.weekly} \
        --keep-monthly ${toString retain.monthly} \
        --prune

      echo ""
      echo "✓ Backup complete"
    '';
  in {
    home.packages = [pkgs.restic pkgs.rage pkgs.jq];

    # Install backup script
    home.file.".local/bin/nix-backup" = {
      source = backupScript;
      executable = true;
    };

    # Write ~/.config/restic/env from secrets.age at activation
    # Uses a single decryption pass to assemble all credentials into the env file
    home.activation.deployBackupCredentials = lib.hm.dag.entryAfter ["writeBoundary"] ''
      SECRETS_FILE="${home}/.config/nix-config/users/${name}/secrets.age"
      AGE_KEY="${home}/.config/agenix/key.txt"
      ENV_DIR="${home}/.config/restic"
      ENV_FILE="$ENV_DIR/env"

      if [ ! -f "$SECRETS_FILE" ]; then
        echo "Warning: backup secrets file not found at $SECRETS_FILE — skipping env file"
      elif [ ! -f "$AGE_KEY" ]; then
        echo "Warning: age private key not found at $AGE_KEY — skipping env file"
      else
        DECRYPTED=$(${pkgs.rage}/bin/rage -d -i "$AGE_KEY" "$SECRETS_FILE" 2>/dev/null)
        PASSWORD=$(echo "$DECRYPTED" | ${pkgs.jq}/bin/jq -r 'getpath(["backup","repository","password"])')
        KEY_ID=$(echo "$DECRYPTED"   | ${pkgs.jq}/bin/jq -r 'getpath(["backup","repository","keyId"])')
        APP_KEY=$(echo "$DECRYPTED"  | ${pkgs.jq}/bin/jq -r 'getpath(["backup","repository","applicationKey"])')

        install -d -m 700 "$ENV_DIR"
        cat > "$ENV_FILE" <<EOF
export RESTIC_REPOSITORY="${repoUrl}"
export RESTIC_PASSWORD="$PASSWORD"
export AWS_ACCESS_KEY_ID="$KEY_ID"
export AWS_SECRET_ACCESS_KEY="$APP_KEY"
EOF
        chmod 600 "$ENV_FILE"
        echo "Backup credentials written to ~/.config/restic/env"
      fi
    '';

    # Source env file in shells for interactive restic use
    programs.bash.bashrcExtra = lib.mkAfter ''
      [ -f "${home}/.config/restic/env" ] && source "${home}/.config/restic/env"
    '';
    programs.zsh.initContent = lib.mkAfter ''
      [ -f "${home}/.config/restic/env" ] && source "${home}/.config/restic/env"
    '';
  })
