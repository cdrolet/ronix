# Ruby - Dynamic, object-oriented programming language
#
# Includes Ruby interpreter, gem package manager, and solargraph LSP
# Known for elegant syntax and productivity
#
# Platform: Cross-platform
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [
    pkgs.ruby
    pkgs.rubyPackages.solargraph
  ];

  home.shellAliases = {
    ruby-version = "${pkgs.ruby}/bin/ruby --version";
    gem-version = "${pkgs.ruby}/bin/gem --version";
  };
}
