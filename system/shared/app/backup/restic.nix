# restic - Fast, secure backup program
#
# Modern backup program that supports encryption, deduplication, and multiple backends
# Supports local, SFTP, S3, B2, Azure, Google Cloud, and many other storage backends
#
# Platform: Cross-platform
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.restic];

  home.shellAliases = {
    # Manual backup (credentials sourced from ~/.config/restic/env via shell init)
    nix-backup = "${config.home.homeDirectory}/.local/bin/nix-backup";
    # Restic inspection commands (env sourced by shell; use after `source ~/.config/restic/env` if not set)
    restic-snapshots = "${pkgs.restic}/bin/restic snapshots";
    restic-mount = "${pkgs.restic}/bin/restic mount";
    restic-version = "${pkgs.restic}/bin/restic version";
  };
}
