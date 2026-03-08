# Repository Schema Contract
# Feature 038: Multi-Provider Repository Support
#
# This file defines the Nix schema contract for the user.repositories option.
# It serves as the authoritative specification for repository configuration.

{ lib, ... }:

let
  # Provider type validation
  validProviders = [ "git" "s3" "proton-drive" ];

  # Repository entity schema
  repositoryType = lib.types.submodule {
    options = {
      # Source URL/location (REQUIRED)
      # Used for automatic provider detection
      url = lib.mkOption {
        type = lib.types.str;
        description = ''
          Source URL or location string.

          Examples:
            - git@github.com:user/repo.git
            - https://github.com/user/repo
            - s3://bucket-name/path
            - https://s3.amazonaws.com/bucket/path
            - https://drive.proton.me/urls/ABC123

          Provider is automatically detected from URL pattern.
        '';
      };

      # Provider type (OPTIONAL)
      # Explicit override for ambiguous URLs or custom providers
      provider = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum validProviders);
        default = null;
        description = ''
          Explicit provider type override.

          Valid values: ${lib.concatStringsSep ", " validProviders}

          If null, provider is auto-detected from URL pattern.
          Use this field for:
            - Ambiguous URLs that match multiple patterns
            - Custom provider implementations
            - Override when auto-detection fails
        '';
      };

      # Local destination path (OPTIONAL)
      # If not specified, uses default location based on provider
      path = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Local destination path for repository content.

          Path resolution precedence:
            1. Explicit path (if specified)
            2. Provider default location:
               - git: ~/repositories/<repo-name>
               - s3: ~/sync/s3/<bucket-name>
               - proton-drive: ~/sync/proton-drive/<share-name>

          Supports tilde expansion (~/) and environment variables.
        '';
      };

      # Authentication reference (OPTIONAL)
      # References a secret key in user.sshKeys or user.tokens
      auth = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Authentication reference for accessing the repository.

          Format: "<secret-type>.<key-name>"

          Examples:
            - "sshKeys.github" → config.user.sshKeys.github
            - "tokens.s3" → config.user.tokens.s3
            - "tokens.protonDrive" → config.user.tokens.protonDrive

          If null:
            - git: Uses default SSH key (~/.ssh/id_ed25519)
            - s3: Uses AWS environment credentials
            - proton-drive: Requires explicit auth
        '';
      };

      # Provider-specific options (OPTIONAL)
      # Flexible attribute set for provider-specific configuration
      options = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = ''
          Provider-specific configuration options.

          Git options:
            - branch (string): Specific branch to clone (default: default branch)
            - depth (int): Shallow clone depth (default: full clone)
            - submodules (bool): Clone submodules (default: true)
            - lfs (bool): Enable Git LFS (default: false)

          S3 options:
            - region (string): AWS region or datacenter location (default: us-east-1)
            - endpoint (string): Custom S3 endpoint for S3-compatible services
                                 (MinIO, Hetzner, etc.)
            - profile (string): AWS CLI profile name
            - syncOptions (list): Additional s3 sync flags

          Proton Drive options:
            - shareId (string): Specific share ID (if URL contains multiple)
            - downloadOptions (list): Additional download flags
        '';
      };
    };
  };

in {
  # Export the repository type for use in user-schema.nix
  inherit repositoryType;

  # Validation functions
  validators = {
    # Validate URL format based on provider
    validateUrl = provider: url:
      if provider == "git" then
        # Git URL validation (git@, https://, .git optional)
        builtins.match "(git@.*|https?://.*)" url != null
      else if provider == "s3" then
        # S3 URL validation (s3://, https://s3.*)
        builtins.match "(s3://.*|https?://s3\\..*)" url != null
      else if provider == "proton-drive" then
        # Proton Drive URL validation (drive.proton.me/urls/*)
        builtins.match "https?://drive\\.proton\\.me/urls/.*" url != null
      else
        # Unknown provider, allow any URL
        true;

    # Validate auth reference format
    validateAuth = auth:
      if auth == null then
        true
      else
        # Must be in format "type.key" (e.g., "sshKeys.github")
        builtins.match "[a-zA-Z][a-zA-Z0-9]*\\.[a-zA-Z][a-zA-Z0-9]*" auth != null;

    # Validate path does not contain dangerous characters
    validatePath = path:
      if path == null then
        true
      else
        # Reject paths with null bytes, newlines
        builtins.match ".*[\x00\n\r].*" path == null;
  };

  # Example configurations for documentation
  examples = {
    # Git repository with SSH
    gitSsh = {
      url = "git@github.com:user/private-repo.git";
      auth = "sshKeys.github";
      options.submodules = true;
    };

    # Git repository with explicit branch
    gitBranch = {
      url = "https://github.com/user/repo";
      options.branch = "develop";
      options.depth = 1;
    };

    # S3 bucket sync
    s3Bucket = {
      url = "s3://my-backup-bucket/data";
      path = "~/backups/s3-data";
      auth = "tokens.s3";
      options = {
        region = "us-west-2";
        syncOptions = [ "--delete" ];
      };
    };

    # S3-compatible service (MinIO)
    s3Compatible = {
      url = "s3://my-bucket/files";
      provider = "s3";  # Explicit override
      auth = "tokens.minio";
      options = {
        endpoint = "https://minio.example.com";
        region = "us-east-1";
      };
    };

    # Hetzner Object Storage
    hetznerStorage = {
      url = "https://my-bucket.fsn1.your-objectstorage.com/data";
      auth = "tokens.hetzner";
      options = {
        region = "fsn1";  # Falkenstein datacenter (nbg1 = Nuremberg, hel1 = Helsinki)
      };
    };

    # Proton Drive share
    protonDrive = {
      url = "https://drive.proton.me/urls/ABC123XYZ";
      path = "~/documents/proton-drive";
      auth = "tokens.protonDrive";
    };

    # Ambiguous URL with explicit provider
    ambiguous = {
      url = "https://custom-git-server.com/repo";
      provider = "git";  # Could be git or generic HTTPS
      auth = "sshKeys.custom";
    };
  };
}
