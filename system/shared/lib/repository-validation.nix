# Repository Validation Library
# Feature 038: Multi-Provider Repository Support
#
# Purpose: Validate repository configuration at evaluation time
# Platform: Cross-platform (darwin, nixos, any Home Manager-compatible platform)
#
# This library provides:
# 1. URL validation (format, required fields)
# 2. Authentication reference validation (format, secret existence)
# 3. Path validation (dangerous characters, conflicts)
# 4. Provider-specific option validation
#
# Validation occurs at Nix evaluation time (nix flake check)
# Runtime errors handled gracefully in activation scripts
{
  lib,
  pkgs,
}: let
  providerLib = import ./provider-detection.nix {inherit lib;};

  # Validate repository URL is non-empty and well-formed
  # Returns: { valid = bool; error = string | null; }
  validateUrl = url:
    if url == null || url == ""
    then {
      valid = false;
      error = "Repository URL cannot be empty";
    }
    else {
      valid = true;
      error = null;
    };

  # Validate authentication reference format
  # Format: "type.key" (e.g., "sshKeys.github", "tokens.s3")
  # Returns: { valid = bool; error = string | null; }
  validateAuth = auth:
    if auth == null
    then {
      valid = true;
      error = null;
    }
    else
      # Must be in format "type.key" (e.g., "sshKeys.github")
      if builtins.match "[a-zA-Z][a-zA-Z0-9]*\\.[a-zA-Z][a-zA-Z0-9_-]*" auth != null
      then {
        valid = true;
        error = null;
      }
      else {
        valid = false;
        error = ''
          Invalid authentication reference format: "${auth}"
          Expected format: "type.key" (e.g., "sshKeys.github", "tokens.s3")
        '';
      };

  # Validate path does not contain dangerous characters
  # Returns: { valid = bool; error = string | null; }
  validatePath = path:
    if path == null
    then {
      valid = true;
      error = null;
    }
    else
      # Reject paths with newlines or carriage returns
      # Note: null bytes cannot exist in Nix strings, so no need to check.
      # builtins.match does not support \x00 or \r escape sequences in character
      # classes — use literal newline/CR via Nix string interpolation.
      if builtins.match ".*[\n\r].*" path != null
      then {
        valid = false;
        error = "Path contains dangerous characters (newlines): ${path}";
      }
      else {
        valid = true;
        error = null;
      };

  # Validate repository configuration (URL, provider, auth, path)
  # repo: Repository configuration attribute set
  # Returns: { valid = bool; errors = [string]; warnings = [string]; }
  validateRepository = repo: let
    # Extract fields
    url = repo.url or null;
    explicitProvider = repo.provider or null;
    auth = repo.auth or null;
    path = repo.path or null;

    # Validate individual fields
    urlCheck = validateUrl url;
    authCheck = validateAuth auth;
    pathCheck = validatePath path;

    # Resolve provider
    providerResolution = providerLib.resolveProvider explicitProvider url;
    resolvedProvider = providerResolution.provider;
    providerSource = providerResolution.source;

    # Validate provider type
    providerCheck = providerLib.validateProviderType resolvedProvider;

    # Provider-specific URL validation
    providerUrlCheck =
      if resolvedProvider != null
      then providerLib.validateProviderUrl resolvedProvider url
      else {
        valid = true;
        error = null;
      };

    # Collect errors
    errors = builtins.filter (e: e != null) [
      (if !urlCheck.valid then urlCheck.error else null)
      (if !authCheck.valid then authCheck.error else null)
      (if !pathCheck.valid then pathCheck.error else null)
      (if !providerCheck.valid then providerCheck.error else null)
      (if !providerUrlCheck.valid then providerUrlCheck.error else null)
    ];

    # Collect warnings
    warnings = let
      providerMismatchWarning =
        if explicitProvider != null && providerResolution.source == "explicit"
        then let
          autoDetected = providerLib.detectProvider url;
        in
          if autoDetected != null && autoDetected != explicitProvider
          then "Provider explicitly set to '${explicitProvider}' but URL pattern suggests '${autoDetected}'. Explicit provider takes precedence."
          else null
        else null;
    in
      builtins.filter (w: w != null) [providerMismatchWarning];
  in {
    valid = errors == [];
    errors = errors;
    warnings = warnings;
    provider = resolvedProvider;
    providerSource = providerSource;
  };

  # Validate list of repositories
  # Returns: { valid = bool; errorCount = int; warningCount = int; details = [{ repo, validation }]; }
  validateRepositories = repos: let
    validations = map (repo: {
      inherit repo;
      validation = validateRepository repo;
    }) repos;

    errorCount = builtins.length (builtins.filter (v: !v.validation.valid) validations);
    warningCount = builtins.length (builtins.concatMap (v: v.validation.warnings) validations);
  in {
    valid = errorCount == 0;
    inherit errorCount warningCount;
    details = validations;
  };

  # Format validation error message for display
  # validation: Result from validateRepository
  # Returns: string (error message)
  formatValidationError = validation:
    if validation.valid
    then ""
    else let
      errorLines = map (err: "  ✗ ${err}") validation.errors;
      warningLines = map (warn: "  ⚠ ${warn}") validation.warnings;
    in
      lib.concatStringsSep "\n" (errorLines ++ warningLines);

  # Validate options attribute set for a specific provider
  # Returns: { valid = bool; warnings = [string]; }
  validateProviderOptions = provider: options: let
    knownGitOptions = ["branch" "depth" "submodules" "lfs"];
    knownS3Options = ["region" "endpoint" "profile" "syncOptions"];
    knownProtonDriveOptions = ["shareId" "downloadOptions"];

    knownOptions =
      if provider == "git"
      then knownGitOptions
      else if provider == "s3"
      then knownS3Options
      else if provider == "proton-drive"
      then knownProtonDriveOptions
      else [];

    optionKeys = builtins.attrNames options;

    unknownKeys = builtins.filter (key: !(lib.elem key knownOptions)) optionKeys;

    warnings =
      if unknownKeys == []
      then []
      else ["Unknown ${provider} options: ${lib.concatStringsSep ", " unknownKeys}. These will be ignored."];
  in {
    valid = true; # Unknown options are warnings, not errors
    inherit warnings;
  };
in {
  inherit validateUrl validateAuth validatePath;
  inherit validateRepository validateRepositories;
  inherit formatValidationError validateProviderOptions;
}
