# Generic git helper functions
# Provides utilities for cloning and updating git repositories
#
# Feature 032: User Git Repository Configuration
# - normalizeRepo: Convert flexible repo specs to consistent format
# - resolveRepoPath: Determine clone destination with path resolution
# - mkRepoCloneScriptWithPaths: Enhanced clone script with custom paths
{lib}: {
  # Extract repository name from a git URL
  # e.g., "git@github.com:user/my-repo.git" -> "my-repo"
  # e.g., "https://github.com/user/my-repo.git" -> "my-repo"
  repoName = url: let
    withoutGit = lib.removeSuffix ".git" url;
    parts = lib.splitString "/" withoutGit;
  in
    lib.last parts;

  # Generate a bash script fragment to clone or update a list of repositories
  # Args:
  #   pkgs: nixpkgs package set (for git binary)
  #   repos: list of git URLs to clone
  #   targetDir: directory to clone into (repos become subdirectories)
  # Returns: bash script string
  mkRepoCloneScript = {
    pkgs,
    repos,
    targetDir,
  }:
    lib.concatMapStringsSep "\n" (url: let
      name = (import ./git.nix {inherit lib;}).repoName url;
      localPath = "${targetDir}/${name}";
    in ''
      if [ -d "${localPath}" ]; then
        echo "Updating repository: ${name}"
        cd "${localPath}" && ${pkgs.git}/bin/git pull --quiet 2>&1 || echo "Warning: Failed to update ${name}"
      else
        echo "Cloning repository: ${name}"
        ${pkgs.git}/bin/git clone --quiet "${url}" "${localPath}" 2>&1 || echo "Warning: Failed to clone ${name}"
      fi
    '')
    repos;

  # Normalize repository specification to consistent format
  # Accepts: String (simple URL) or AttrSet ({ url, path })
  # Returns: { url = "..."; path = null | "..."; }
  normalizeRepo = repo:
    if builtins.isString repo
    then {
      url = repo;
      path = null;
    }
    else if builtins.isAttrs repo
    then {
      url = repo.url;
      path = repo.path or null;
    }
    else throw "Invalid repository specification: must be string or { url, path }";

  # Resolve final clone destination for a repository
  # Args:
  #   repo: normalized repository { url, path }
  #   rootPath: section-level default path (or null)
  # Returns: resolved clone path string
  # Precedence: individual path > rootPath > $HOME
  resolveRepoPath = repo: rootPath: let
    repoName = (import ./git.nix {inherit lib;}).repoName repo.url;
  in
    if repo.path != null
    then repo.path # Priority 1: Individual path
    else if rootPath != null
    then "${rootPath}/${repoName}" # Priority 2: Section root
    else "$HOME/${repoName}"; # Priority 3: Home folder

  # Generate bash script for cloning/updating with custom paths and local change detection
  # Args:
  #   pkgs: nixpkgs package set (for git binary)
  #   repos: list of { url, path } specifications (normalized)
  #   checkLocal: if true, check for local changes before pull
  # Returns: bash script string
  mkRepoCloneScriptWithPaths = {
    pkgs,
    repos,
    checkLocal ? true,
  }:
    lib.concatMapStringsSep "\n" (repo: let
      gitLib = import ./git.nix {inherit lib;};
      name = gitLib.repoName repo.url;
      # Expand ~ to $HOME so shell interprets it correctly
      resolvedPath =
        if lib.hasPrefix "~/" repo.path
        then "$HOME/${lib.removePrefix "~/" repo.path}"
        else repo.path;
    in ''
      # Create parent directory
      mkdir -p "$(dirname "${resolvedPath}")"

      if [ -d "${resolvedPath}" ]; then
        cd "${resolvedPath}"

        ${lib.optionalString checkLocal ''
        # Check for local changes
        if [ -n "$(${pkgs.git}/bin/git status --porcelain 2>/dev/null)" ]; then
          echo "Skipping update for ${name}: local changes detected"
        else
      ''}
          echo "Updating repository: ${name}"
          ${pkgs.git}/bin/git pull --quiet 2>&1 || echo "Warning: Failed to update ${name}"
        ${lib.optionalString checkLocal ''
        fi
      ''}
      else
        echo "Cloning repository: ${name} to ${resolvedPath}"
        ${pkgs.git}/bin/git clone --quiet "${repo.url}" "${resolvedPath}" 2>&1 || echo "Warning: Failed to clone ${name}"
      fi
    '')
    repos;
}
