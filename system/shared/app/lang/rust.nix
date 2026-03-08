# Rust - Systems programming language
#
# Includes rustc compiler, cargo build tool, rustfmt formatter, and rust-analyzer LSP
# Focused on safety, speed, and concurrency
#
# Platform: Cross-platform
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [
    pkgs.rustc
    pkgs.cargo
    pkgs.rustfmt
    pkgs.rust-analyzer
  ];

  home.shellAliases = {
    rust-version = "${pkgs.rustc}/bin/rustc --version";
    cargo-version = "${pkgs.cargo}/bin/cargo --version";
  };
}
