# Linux Family: Private Font Repository Cloning
#
# Purpose: Clone private font repos and refresh font cache
# Feature: 030-user-font-config
# Platform: Linux (works on NixOS AND non-NixOS via Home Manager)
#
# Clones private font repositories to ~/.local/share/fonts/private/
# and runs fc-cache to refresh the font cache.
# Font defaults (fontconfig, app fonts) are handled by stylix via fonts.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  gitLib = import ../../../../lib/git.nix {inherit lib;};
  secrets = import ../../../../../../user/lib/secrets.nix {inherit lib pkgs;};

  fontsCfg = (config.user.style or {}).fonts or null;
  fontRepos =
    if fontsCfg != null
    then (fontsCfg.repositories or [])
    else [];

  hasRepos = fontRepos != [];
  hasFontsKey = secrets.isSecret (((config.user.security or {}).sshKeys or {}).fonts or "");

  fontDir = "$HOME/.local/share/fonts/private";
in {
  home.activation.clonePrivateFonts = lib.mkIf (hasRepos && hasFontsKey) (
    lib.hm.dag.entryAfter ["writeBoundary" "applySSHSecrets"] ''
      if [ -f "$HOME/.ssh/id_fonts" ]; then
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ''$HOME/.ssh/id_fonts -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

        mkdir -p "${fontDir}"

        ${gitLib.mkRepoCloneScript {
        inherit pkgs;
        repos = fontRepos;
        targetDir = fontDir;
      }}

        ${pkgs.fontconfig}/bin/fc-cache -f 2>/dev/null || true
      fi
    ''
  );
}
