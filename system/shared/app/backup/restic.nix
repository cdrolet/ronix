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
    restic-version = "${pkgs.restic}/bin/restic version";
    backup = "${pkgs.restic}/bin/restic backup";
    restore = "${pkgs.restic}/bin/restic restore";
  };
}
