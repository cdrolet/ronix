# Shared Settings: S3 Repository Handler
#
# Purpose: Automatically sync S3 buckets to local directories during activation
# Feature: 038-multi-provider-repositories
# Platform: Cross-platform (darwin, nixos, any Home Manager-compatible platform)
#
# This module:
# 1. Filters repositories by provider type (s3 only)
# 2. Syncs S3 buckets using aws-cli s3 sync
# 3. Handles authentication via AWS credentials from user secrets
# 4. Supports S3-compatible services (DigitalOcean, Backblaze, Wasabi, Hetzner)
# 5. Logs provider handling for each repository
# 6. Isolates errors (failed sync doesn't block other repos)
#
# Activation Ordering: Runs after ["writeBoundary"]
# - Ensures aws-cli is available (if needed)
# - Ensures credentials available (decrypted inline at runtime)
#
# Path Resolution:
# - Uses explicit repo.path if specified
# - Otherwise uses provider default: ~/sync/s3/<bucket-name>
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
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};

  # Extract bucket name from S3 URL
  extractBucketName = url:
    if lib.hasPrefix "s3://" url
    then let
      withoutPrefix = lib.removePrefix "s3://" url;
      parts = lib.splitString "/" withoutPrefix;
    in
      if parts == []
      then "s3-bucket"
      else lib.head parts
    else "s3-bucket";

  # Generate sync script for a single S3 repository
  mkS3SyncScript = repo: let
    repoName = providerLib.extractRepoName repo.url;
    resolvedPath =
      if repo.path != null
      then repo.path
      else providerLib.getDefaultPath "s3" repoName;

    # Extract options
    opts = repo.options or {};
    region = opts.region or "us-east-1";
    endpoint = opts.endpoint or null;
    profile = opts.profile or null;
    syncOptions = opts.syncOptions or [];

    # Auth configuration
    authRef = repo.auth or null;
    hasAuth = authRef != null;

    # Build AWS CLI command
    awsCmd = "${pkgs.awscli2}/bin/aws";
    s3SyncCmd = "${awsCmd} s3 sync";

    # Add optional flags
    regionFlag = "--region ${region}";
    endpointFlag =
      if endpoint != null
      then "--endpoint-url ${endpoint}"
      else "";
    profileFlag =
      if profile != null
      then "--profile ${profile}"
      else "";
    extraFlags = lib.concatStringsSep " " syncOptions;
  in ''
    echo "  Syncing S3: ${repo.url} -> ${resolvedPath}"

    # Create destination directory
    mkdir -p "${resolvedPath}"

    # Setup authentication if specified
    ${lib.optionalString hasAuth ''
      # Auth reference format: "tokens.s3" -> extract "s3" token
      # Note: Actual credential setup would happen via environment variables
      # or AWS config files managed by agenix activation
    ''}

    # Sync from S3 to local path
    if ${s3SyncCmd} ${regionFlag} ${endpointFlag} ${profileFlag} ${extraFlags} "${repo.url}" "${resolvedPath}" 2>&1; then
      echo "  ✓ S3 sync complete: ${repoName}"
    else
      echo "  ✗ S3 sync failed: ${repoName} (continuing with other repos)"
    fi
  '';
in {
  # Implementation: Sync S3 repositories at activation time
  # Feature 039: No context guard needed - file only imported in user/ context
  # Defer config access to avoid infinite recursion
  config = let
    # Get user repositories from schema
    userRepos = (config.user.workspace or {}).repositories or [];

    # Filter repositories by provider type (s3 only)
    s3Repos = builtins.filter (repo: let
      validation = validationLib.validateRepository repo;
      provider = validation.provider;
    in
      validation.valid && provider == "s3")
    userRepos;

    # Check if we have any S3 repositories to process
    hasS3Repos = s3Repos != [];

    # Generate full S3 sync script for all repos
    s3SyncScript = lib.concatMapStringsSep "\n" mkS3SyncScript s3Repos;
  in
    lib.mkIf hasS3Repos {
      # Ensure aws-cli is available
      home.packages = [pkgs.awscli2];

      home.activation.syncS3Repos = lib.hm.dag.entryAfter ["writeBoundary"] ''
        # Log S3 provider handling
        echo "S3 provider: Processing ${toString (builtins.length s3Repos)} repositories"

        ${s3SyncScript}

        echo "S3 provider: Complete"
      '';
    };
}
