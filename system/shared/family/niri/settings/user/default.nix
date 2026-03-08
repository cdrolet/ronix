{
  config,
  lib,
  pkgs,
  ...
}: let
  discovery = import ../../../../lib/discovery.nix {inherit lib;};
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
