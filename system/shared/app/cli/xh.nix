{
  config,
  pkgs,
  lib,
  ...
}: {
  # xh - Friendly and fast tool for sending HTTP requests
  # Modern alternative to httpie and curl
  # Dependencies: None

  home.packages = [pkgs.xh];

  # Shell aliases
  home.shellAliases = {
    http = "${pkgs.xh}/bin/xh";
    https = "${pkgs.xh}/bin/xhs";
  };
}
