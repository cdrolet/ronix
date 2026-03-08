{
  config,
  pkgs,
  lib,
  ...
}: {
  # duti - Set default applications for document types on macOS
  # Command-line tool for managing file associations using UTIs
  # Platform: macOS only
  # Dependencies: None

  home.packages = [pkgs.duti];

  # Shell aliases for common operations
  home.shellAliases = {
    duti-list = "${pkgs.duti}/bin/duti -l";
    duti-ext = "${pkgs.duti}/bin/duti -x";
  };
}
