{
  config,
  pkgs,
  lib,
  ...
}: {
  # aria2 - Lightweight multi-protocol download utility
  # Supports HTTP/HTTPS, FTP, SFTP, BitTorrent and Metalink
  # Dependencies: None

  programs.aria2 = {
    enable = true;
    settings = {
      dir = "${config.home.homeDirectory}/Downloads";
      max-connection-per-server = 16;
      split = 16;
      min-split-size = "1M";
      continue = true;
      file-allocation = "none";
    };
  };

  # Shell aliases
  home.shellAliases = {
    dl = "${pkgs.aria2}/bin/aria2c";
  };
}
