# Darwin Settings: Private Font Repository Cloning
#
# Purpose: Clone private font repositories and symlink to ~/Library/Fonts/
# Feature: 030-user-font-config
# Platform: macOS only
#
# macOS does NOT scan subdirectories in ~/Library/Fonts/. This module:
# 1. Clones private repos to ~/.local/share/fonts/private/ (same as Linux)
# 2. Symlinks all .ttf/.otf files to ~/Library/Fonts/
{
  config,
  lib,
  pkgs,
  ...
}: let
  gitLib = import ../../../shared/lib/git.nix {inherit lib;};
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};

  fontsCfg = (config.user.style or {}).fonts or null;
  fontRepos =
    if fontsCfg != null
    then (fontsCfg.repositories or [])
    else [];
  hasRepos = fontRepos != [];

  hasFontsKey = secrets.isSecret (((config.user.security or {}).sshKeys or {}).fonts or "");

  repoDir = "$HOME/.local/share/fonts/private";
  fontDir = "$HOME/Library/Fonts";
in {
  home.activation.clonePrivateFonts = lib.mkIf (hasRepos && hasFontsKey) (
    lib.hm.dag.entryAfter ["writeBoundary" "applySSHSecrets"] ''
      if [ -f "$HOME/.ssh/id_fonts" ]; then
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ''$HOME/.ssh/id_fonts -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

        mkdir -p "${repoDir}"

        ${gitLib.mkRepoCloneScript {
        inherit pkgs;
        repos = fontRepos;
        targetDir = repoDir;
      }}

        find "${repoDir}" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \) | while read font; do
          ln -sf "$font" "${fontDir}/$(basename "$font")"
        done
      fi
    ''
  );
}
