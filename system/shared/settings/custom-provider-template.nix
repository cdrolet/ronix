# Template: Custom Provider Handler
#
# Purpose: Template for implementing custom repository provider handlers
# Feature: 038-multi-provider-repositories
# Platform: Cross-platform (darwin, nixos, any Home Manager-compatible platform)
#
# How to add a new provider:
# 1. Copy this file to system/shared/settings/<provider>-repos.nix
# 2. Update provider detection in system/shared/lib/provider-detection.nix
#    - Add URL patterns to detectProvider function
#    - Add provider to knownProviders list
#    - Add validateProviderUrl patterns
# 3. Implement the filtering and sync logic below
# 4. Test with nix flake check
#
# Example providers: rsync, dropbox, webdav, ftp, etc.
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  # Import provider detection and validation libraries
  providerLib = import ../lib/provider-detection.nix {inherit lib;};
  validationLib = import ../lib/repository-validation.nix {inherit lib pkgs;};
  secrets = import ../../../user/lib/secrets.nix {inherit lib pkgs;};

  # Get user repositories from schema
  userRepos = config. or [];

  # Filter repositories by YOUR provider type
  # Change "custom" to your provider name (e.g., "rsync", "dropbox")
  customRepos = builtins.filter (repo: let
    validation = validationLib.validateRepository repo;
    provider = validation.provider;
  in
    validation.valid && provider == "custom") # Change "custom" here
  userRepos;

  # Check if we have any repositories for this provider
  hasCustomRepos = customRepos != [];

  # Generate sync script for a single repository
  # Customize this function for your provider's sync command
  mkCustomSyncScript = repo: let
    repoName = providerLib.extractRepoName repo.url;
    resolvedPath =
      if repo.path != null
      then repo.path
      else providerLib.getDefaultPath "custom" repoName; # Change "custom" here

    # Extract provider-specific options
    opts = repo.options or {};
    # Example: customOption = opts.customOption or "default";

    # Auth configuration
    authRef = repo.auth or null;
    hasAuth = authRef != null;

    # Build your provider's sync command
    # Example: customCmd = "${pkgs.customTool}/bin/customTool";
  in ''
    echo "  Syncing Custom Provider: ${repo.url} -> ${resolvedPath}"

    # Create destination directory
    mkdir -p "${resolvedPath}"

    # Setup authentication if needed
    ${lib.optionalString hasAuth ''
      # Configure your provider's authentication here
      # Example: export CUSTOM_TOKEN="$TOKEN_VALUE"
    ''}

    # Execute sync command
    # Replace this with your actual sync logic
    echo "  ✓ Custom provider sync: ${repoName} (implement your sync command here)"

    # Error handling example:
    # if <your-sync-command>; then
    #   echo "  ✓ Sync complete: ${repoName}"
    # else
    #   echo "  ✗ Sync failed: ${repoName} (continuing with other repos)"
    # fi
  '';

  # Generate full sync script for all repos
  customSyncScript = lib.concatMapStringsSep "\n" mkCustomSyncScript customRepos;
in {
  # Implementation: Sync repositories at activation time
  # Only activate in home-manager context when we have repos for this provider
  #
  # IMPORTANT: Always use context validation (lib.optionalAttrs with options ? home)
  # This prevents evaluation errors in system context (Stage 1)
  config = lib.optionalAttrs (
    (options ? home) # Check if in home-manager context
    && (lib ? hm) # Check if lib.hm is available
    && hasCustomRepos # Check if we have repos to process
  ) {
    # Install required tools for your provider
    # Example: home.packages = [pkgs.customTool];

    home.activation.syncCustomRepos = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Log provider handling
      echo "Custom Provider: Processing ${toString (builtins.length customRepos)} repositories"

      ${customSyncScript}

      echo "Custom Provider: Complete"
    '';
  };
}
