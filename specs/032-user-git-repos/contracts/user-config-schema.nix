# Contract: User Configuration Schema for Git Repositories
#
# This defines the user.repositories option schema that users interact with.
# It specifies the types, defaults, and validation rules for repository configuration.
#
# Feature: 032-user-git-repos
# Location: Implemented in system/shared/settings/git-repos.nix

{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options = {
    user.repositories = mkOption {
      type = types.submodule {
        options = {
          # Optional root path for all repositories without individual paths
          rootPath = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "~/projects";
            description = ''
              Default parent directory for repositories without individual paths.
              Supports tilde expansion (~/path) and relative paths (./path).
              If not specified, repositories clone to home folder by default.
            '';
          };

          # List of repositories to clone
          repos = mkOption {
            type = types.listOf (
              types.either types.str (types.submodule {
                options = {
                  # Git repository URL (SSH or HTTPS)
                  url = mkOption {
                    type = types.str;
                    example = "git@github.com:user/repo.git";
                    description = ''
                      Git repository URL. Supports both SSH and HTTPS formats:
                      - SSH: git@github.com:user/repo.git
                      - HTTPS: https://github.com/user/repo.git
                    '';
                  };

                  # Optional custom clone destination
                  path = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    example = "~/work/project";
                    description = ''
                      Custom clone destination path. Overrides rootPath.
                      Supports absolute (/path/to/dir) and relative (~/path) paths.
                      If not specified, uses rootPath or home folder.
                    '';
                  };
                };
              })
            );
            default = [];
            example = [
              "git@github.com:user/simple-repo.git"
              {
                url = "https://github.com/user/work.git";
                path = "~/work";
              }
            ];
            description = ''
              List of git repositories to clone during activation.
              Each entry can be:
              - A simple URL string (uses rootPath or home folder)
              - An attribute set with { url, path } for custom location
            '';
          };
        };
      };
      default = {};
      example = {
        rootPath = "~/projects";
        repos = [
          "git@github.com:user/dotfiles.git"
          {
            url = "https://github.com/user/work-project.git";
            path = "~/work";
          }
        ];
      };
      description = ''
        Git repository configuration for automatic cloning during activation.
        Repositories are cloned/updated after git installation and credential deployment.

        Requires:
        - git in user.applications list
        - (Optional) sshKeys.git in secrets for private repositories

        Path resolution order:
        1. Individual repo.path (if specified)
        2. Section rootPath + repo name (if rootPath specified)
        3. Home folder + repo name (default)
      '';
    };
  };

  # No implementation here - this is just the schema contract
  # Actual implementation in system/shared/settings/git-repos.nix
}
