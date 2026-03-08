# rclone - Rsync for cloud storage
#
# Command-line program to sync files and directories to/from cloud storage
# Supports 70+ cloud storage providers (S3, Google Drive, Dropbox, OneDrive, etc.)
#
# Platform: Cross-platform
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.rclone];

  home.shellAliases = {
    rclone-version = "${pkgs.rclone}/bin/rclone version";
  };
}
