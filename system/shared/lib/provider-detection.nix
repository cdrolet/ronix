# Provider Detection Library
# Feature 038: Multi-Provider Repository Support
#
# Purpose: Auto-detect repository provider type from URL patterns
# Platform: Cross-platform (darwin, nixos, any Home Manager-compatible platform)
#
# This library provides:
# 1. URL pattern matching for known providers (git, s3, proton-drive)
# 2. Automatic provider type resolution with explicit override support
# 3. Repository name extraction for default path resolution
# 4. Provider validation and error reporting
#
# Supported Providers:
# - git: GitHub, GitLab, Bitbucket, git@, https://, ssh://, file://
# - s3: AWS S3, DigitalOcean Spaces, Backblaze B2, Wasabi, Hetzner Object Storage
# - proton-drive: Proton Drive share links (drive.proton.me/urls/*)
#
# Detection Priority:
# 1. Explicit provider field (highest priority)
# 2. Protocol prefix (s3://, git@, ssh://, git://, file://)
# 3. Known hostname patterns (github.com, s3.amazonaws.com, etc.)
# 4. Path characteristics (.git suffix, bucket/key structure)
# 5. Unknown (requires explicit provider field)
#
# Adding New Providers:
# To add a new provider (e.g., "rsync"), update:
# 1. detectProvider function: Add URL pattern matching
# 2. knownProviders list: Add provider name
# 3. extractRepoName function: Add repo name extraction logic (if needed)
# 4. getDefaultPath function: Add default path for provider
# 5. validateProviderUrl function: Add URL validation patterns
# Then create a handler in system/shared/settings/<provider>-repos.nix
# See custom-provider-template.nix for a template
{lib}: {
  # Auto-detect provider type from URL
  # Returns: "git" | "s3" | "proton-drive" | null (unknown)
  detectProvider = url:
    if builtins.isNull url || url == ""
    then null
    # Protocol-based detection (highest confidence)
    else if lib.hasPrefix "s3://" url
    then "s3"
    else if lib.hasPrefix "git@" url
    then "git"
    else if lib.hasPrefix "ssh://" url
    then "git"
    else if lib.hasPrefix "git://" url
    then "git"
    else if lib.hasPrefix "file://" url || lib.hasPrefix "/" url
    then "git"
    else if lib.hasPrefix "https://drive.proton.me/urls/" url
    then "proton-drive"
    else if lib.hasPrefix "proton-drive://" url
    then "proton-drive"
    # HTTPS/HTTP hostname-based detection
    else if lib.hasPrefix "https://" url || lib.hasPrefix "http://" url
    then
      # Git hosting services
      if lib.hasInfix "github.com" url
      then "git"
      else if lib.hasInfix "gitlab.com" url
      then "git"
      else if lib.hasInfix "bitbucket.org" url
      then "git"
      # S3-compatible services
      else if lib.hasInfix ".digitaloceanspaces.com" url
      then "s3"
      else if lib.hasInfix ".backblazeb2.com" url
      then "s3"
      else if lib.hasInfix ".wasabisys.com" url
      then "s3"
      else if lib.hasInfix ".your-objectstorage.com" url
      then "s3"
      else if lib.hasInfix ".amazonaws.com" url
      then "s3"
      else if lib.hasInfix ".s3" url && lib.hasInfix ".amazonaws.com" url
      then "s3"
      # Weak signals (low confidence)
      else if lib.hasSuffix ".git" url || lib.hasInfix "/.git/" url
      then "git"
      else null
    else null;

  # Resolve provider type with explicit override
  # explicitProvider: User-specified provider type (can be null)
  # url: Repository URL for auto-detection
  # Returns: { provider = "git" | "s3" | "proton-drive" | null; source = "explicit" | "auto-detected"; }
  resolveProvider = explicitProvider: url: let
    detected = lib.getAttr "detectProvider" (import ./provider-detection.nix {inherit lib;}) url;
  in
    if explicitProvider != null
    then {
      provider = explicitProvider;
      source = "explicit";
    }
    else if detected != null
    then {
      provider = detected;
      source = "auto-detected";
    }
    else {
      provider = null;
      source = "unknown";
    };

  # Extract repository name from URL for default path resolution
  # Used when user doesn't specify custom path
  # Returns: repository name (string)
  extractRepoName = url: let
    # Helper to get last path segment
    lastSegment = path: let
      parts = lib.splitString "/" path;
      nonEmpty = builtins.filter (s: s != "") parts;
    in
      if nonEmpty == []
      then "repository"
      else lib.last nonEmpty;

    # Remove .git suffix if present
    withoutGit = lib.removeSuffix ".git" url;
  in
    # S3 URLs: extract bucket name
    if lib.hasPrefix "s3://" url
    then let
      withoutPrefix = lib.removePrefix "s3://" url;
      parts = lib.splitString "/" withoutPrefix;
    in
      if parts == []
      then "s3-bucket"
      else lib.head parts
    # Proton Drive: extract share token
    else if lib.hasInfix "drive.proton.me/urls/" url
    then let
      parts = lib.splitString "/" url;
      nonEmpty = builtins.filter (s: s != "") parts;
    in
      if (builtins.length nonEmpty) > 0
      then "proton-drive-${lib.last nonEmpty}"
      else "proton-drive-share"
    # Git URLs: extract repo name from path
    else if lib.hasPrefix "git@" url
    then let
      # Format: git@host:path/to/repo.git
      afterColon = lib.last (lib.splitString ":" url);
    in
      lastSegment afterColon
    else
      # Standard URL: get last path segment
      lastSegment withoutGit;

  # Validate provider type is recognized
  # Returns: { valid = bool; error = string | null; }
  validateProviderType = provider: let
    knownProviders = ["git" "s3" "proton-drive"];
  in
    if provider == null
    then {
      valid = false;
      error = "Provider type is null - cannot determine provider from URL. Please specify explicit provider field.";
    }
    else if lib.elem provider knownProviders
    then {
      valid = true;
      error = null;
    }
    else {
      valid = false;
      error = "Unknown provider type: ${provider}. Supported providers: ${lib.concatStringsSep ", " knownProviders}";
    };

  # Get default path for a repository based on provider
  # Returns: default path string (e.g., "~/repositories/<name>")
  getDefaultPath = provider: repoName:
    if provider == "git"
    then "~/repositories/${repoName}"
    else if provider == "s3"
    then "~/sync/s3/${repoName}"
    else if provider == "proton-drive"
    then "~/sync/proton-drive/${repoName}"
    else "~/${repoName}";

  # List of known providers
  knownProviders = ["git" "s3" "proton-drive"];

  # Provider-specific URL validation patterns
  # Returns: { valid = bool; error = string | null; }
  validateProviderUrl = provider: url:
    if provider == "git"
    then
      # Git: Accept various formats (SSH, HTTPS, git://, file://)
      if url == ""
      then {
        valid = false;
        error = "Empty git URL";
      }
      else {
        valid = true;
        error = null;
      }
    else if provider == "s3"
    then
      if lib.hasPrefix "s3://" url
      then let
        # Validate bucket name (first segment after s3://)
        withoutPrefix = lib.removePrefix "s3://" url;
        parts = lib.splitString "/" withoutPrefix;
        bucket =
          if parts == []
          then ""
          else lib.head parts;
        bucketValid =
          lib.stringLength bucket
          >= 3
          && lib.stringLength bucket <= 63
          && !(lib.hasInfix ".." bucket);
      in
        if bucketValid
        then {
          valid = true;
          error = null;
        }
        else {
          valid = false;
          error = "Invalid S3 bucket name: ${bucket}. Must be 3-63 characters, no consecutive dots.";
        }
      else if
        lib.hasInfix ".amazonaws.com" url
        || lib.hasInfix ".digitaloceanspaces.com" url
        || lib.hasInfix ".wasabisys.com" url
        || lib.hasInfix ".your-objectstorage.com" url
        || lib.hasInfix ".backblazeb2.com" url
      then {
        valid = true;
        error = null;
      }
      else {
        valid = false;
        error = "Invalid S3 URL format. Use s3://bucket/path or HTTPS URL to S3-compatible service.";
      }
    else if provider == "proton-drive"
    then
      # Accept any non-empty URL for Proton Drive (validation at runtime)
      if url == ""
      then {
        valid = false;
        error = "Empty Proton Drive URL";
      }
      else {
        valid = true;
        error = null;
      }
    else {
      valid = false;
      error = "Unknown provider: ${provider}";
    };
}
