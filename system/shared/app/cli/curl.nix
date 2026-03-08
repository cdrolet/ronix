{
  config,
  pkgs,
  lib,
  ...
}: {
  # curl - Command line tool for transferring data with URLs
  # Supports HTTP, HTTPS, FTP, and many other protocols
  # Dependencies: None

  home.packages = [pkgs.curl];

  # Shell aliases for common curl operations
  home.shellAliases = {
    curl-json = "${pkgs.curl}/bin/curl -H 'Content-Type: application/json'";
    curl-get = "${pkgs.curl}/bin/curl -X GET";
    curl-post = "${pkgs.curl}/bin/curl -X POST";
  };
}
