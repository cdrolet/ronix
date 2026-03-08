# Shared Settings: Git Repository Handler
#
# Purpose: Automatically clone and update git repositories during activation
# Feature: 038-multi-provider-repositories (refactored from 032-user-git-repos)
# Platform: Cross-platform (darwin, nixos, any Home Manager-compatible platform)
#
# This module:
# 1. Filters repositories by provider type (git only)
# 2. Clones/updates git repositories during activation
# 3. Handles SSH authentication for private repositories
# 4. Preserves local changes when updating existing repositories
# 5. Logs provider handling for each repository
#
# Activation Ordering: Runs after ["writeBoundary" "deployGitSshKey"]
# - Ensures git is installed (package installation before writeBoundary)
# - Ensures SSH credentials deployed (deployGitSshKey completes)
#
# Path Resolution:
# - Uses explicit repo.path if specified
# - Otherwise uses provider default: ~/repositories/<repo-name>
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  # Import provider detection and validation libraries
  providerLib = import ../../lib/provider-detection.nix {inherit lib;};
  validationLib = import ../../lib/repository-validation.nix {inherit lib pkgs;};
  gitLib = import ../../lib/git.nix {inherit lib;};
  appHelpers = import ../../lib/app-helpers.nix {inherit lib;};
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};
in {
  # Implementation: Clone/update git repositories at activation time
  # Feature 039: No context guard needed - file only imported in user/ context
  # Defer config access to avoid infinite recursion
  config = let
    # Get user repositories from schema
    userRepos = (config.user.workspace or {}).repositories or [];

    # Filter repositories by provider type (git only)
    gitRepos = builtins.filter (repo: let
      validation = validationLib.validateRepository repo;
      provider = validation.provider;
    in
      validation.valid && provider == "git")
    userRepos;

    # Check if git is in user's applications (handles wildcards)
    hasGit = appHelpers.hasApp config "git";

    # Check if we have any git repositories to process
    hasGitRepos = gitRepos != [];

    # Transform git repositories to format expected by git helper
    transformedRepos =
      map (repo: let
        repoName = providerLib.extractRepoName repo.url;
        resolvedPath =
          if repo.path != null
          then repo.path
          else providerLib.getDefaultPath "git" repoName;
      in {
        url = repo.url;
        path = resolvedPath;
      })
      gitRepos;
  in
    lib.mkIf (hasGit && hasGitRepos) {
      # Deploy SSH key from secrets to ~/.ssh/id_git before cloning
      home.activation.deployGitSshKey = secrets.mkActivationScript {
        inherit config pkgs lib;
        name = "git-repos";
        fields = {
          "security.sshKeys.git" = ''
            mkdir -p "$HOME/.ssh"
            printf '%s\n' "$SECURITY_SSHKEYS_GIT" > "$HOME/.ssh/id_git"
            chmod 600 "$HOME/.ssh/id_git"
          '';
        };
      };

      home.activation.cloneGitRepos = lib.hm.dag.entryAfter ["writeBoundary" "deployGitSshKey"] ''
        # Log git provider handling
        echo "Git provider: Processing ${toString (builtins.length gitRepos)} repositories"

        # Setup SSH authentication if git key is configured
        ${lib.optionalString (secrets.isSecret (((config.user.security or {}).sshKeys or {}).git or "")) ''
          if [ -f "$HOME/.ssh/id_git" ]; then
            export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ''$HOME/.ssh/id_git -o StrictHostKeyChecking=accept-new -o BatchMode=yes"
            echo "  Using SSH key: ~/.ssh/id_git"
          fi
        ''}

        # Clone/update repositories with path resolution and local change detection
        ${gitLib.mkRepoCloneScriptWithPaths {
          inherit pkgs;
          repos = transformedRepos;
          checkLocal = true; # Preserve local changes
        }}

        echo "Git provider: Complete"
      '';
    };
}
