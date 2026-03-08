# Desktop Metadata Schema Contract
#
# This file defines the type schema and validation contracts for desktop metadata
# in application configuration files. It serves as the authoritative reference for
# the structure and constraints of desktop metadata.
#
# Feature: 019-app-desktop-metadata
# Version: 1.0.0
# Created: 2025-11-16

{ lib }:

let
  inherit (lib) types mkOption;

in {
  # Desktop metadata option type definition
  # This can be used in application modules to declare desktop metadata support
  desktopMetadataType = types.submodule {
    options = {
      paths = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        example = {
          darwin = "/Applications/Zed.app";
          nixos = "\${pkgs.zed-editor}/bin/zed";
        };
        description = ''
          Platform-specific desktop paths for the application.

          Keys are platform names (darwin, nixos, etc.) and values are
          absolute paths to the application on that platform.

          Required if `associations` or `autostart` are specified.
          Only the path for the active platform is used.
        '';
      };

      associations = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ ".json" ".xml" ".yaml" ".nix" ];
        description = ''
          File extensions that should be associated with this application.

          Each extension must start with a period (e.g., ".json").
          When specified, a desktop path for the active platform is required.

          The platform will register these associations using native mechanisms:
          - Darwin: Launch Services / duti
          - NixOS: XDG MIME / mimeapps.list
        '';
      };

      autostart = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          Whether to start the application automatically at user login.

          When enabled, a desktop path for the active platform is required.

          The platform will create autostart configuration using native mechanisms:
          - Darwin: LaunchAgent plist
          - NixOS: systemd user service or XDG autostart entry
        '';
      };
    };
  };

  # Validation function: Check if desktop metadata is valid for a given platform
  #
  # Args:
  #   - appName: Name of the application (for error messages)
  #   - desktop: Desktop metadata attribute set
  #   - platform: Active platform name (darwin, nixos, etc.)
  #
  # Returns:
  #   { valid = bool; errors = [string]; }
  validateDesktopMetadata = appName: desktop: platform:
    let
      hasAssociations = (desktop.associations or []) != [];
      hasAutostart = desktop.autostart or false;
      hasPaths = desktop.paths or null != null;
      platformPath = if hasPaths then (desktop.paths.${platform} or null) else null;

      # Validation checks
      checks = {
        # If associations or autostart are specified, paths must exist
        pathsRequired = {
          condition = (hasAssociations || hasAutostart) -> hasPaths;
          error = "Application '${appName}' has file associations or autostart enabled but no desktop.paths defined";
        };

        # If paths exist and associations/autostart are specified, platform path must exist
        platformPathRequired = {
          condition = (hasPaths && (hasAssociations || hasAutostart)) -> (platformPath != null);
          error = "Application '${appName}' requires desktop.paths.${platform} for file associations or autostart on this platform";
        };

        # If platform path exists, it must not be empty
        platformPathNotEmpty = {
          condition = (platformPath != null) -> (platformPath != "");
          error = "Application '${appName}' has empty desktop.paths.${platform}";
        };

        # File extensions must start with "."
        extensionsValid = {
          condition = lib.all (ext: lib.hasPrefix "." ext) (desktop.associations or []);
          error = "Application '${appName}' has invalid file extensions (must start with '.')";
        };
      };

      # Collect errors from failed checks
      errors = lib.filter (e: e != null) (
        lib.mapAttrsToList (name: check:
          if check.condition then null else check.error
        ) checks
      );

    in {
      valid = errors == [];
      inherit errors;
    };

  # Validation function: Validate multiple applications' desktop metadata
  #
  # Args:
  #   - apps: Attribute set of { appName = { desktop = {...}; ... }; }
  #   - platform: Active platform name
  #
  # Returns:
  #   { valid = bool; errors = { appName = [errors]; }; }
  validateAllDesktopMetadata = apps: platform:
    let
      # Validate each app that has desktop metadata
      validationResults = lib.mapAttrs (appName: appConfig:
        if appConfig ? desktop
        then validateDesktopMetadata appName appConfig.desktop platform
        else { valid = true; errors = []; }
      ) apps;

      # Check if all are valid
      allValid = lib.all (result: result.valid) (lib.attrValues validationResults);

      # Collect only apps with errors
      appsWithErrors = lib.filterAttrs (name: result: !result.valid) validationResults;

    in {
      valid = allValid;
      errors = lib.mapAttrs (name: result: result.errors) appsWithErrors;
    };

  # Helper function: Extract desktop path for current platform
  #
  # Args:
  #   - desktop: Desktop metadata attribute set
  #   - platform: Active platform name
  #
  # Returns:
  #   Path string or null if not defined
  getDesktopPath = desktop: platform:
    if (desktop.paths or null) != null
    then (desktop.paths.${platform} or null)
    else null;

  # Helper function: Check if desktop metadata requests any features
  #
  # Args:
  #   - desktop: Desktop metadata attribute set
  #
  # Returns:
  #   Boolean indicating if any desktop features are requested
  hasDesktopFeatures = desktop:
    let
      hasAssociations = (desktop.associations or []) != [];
      hasAutostart = desktop.autostart or false;
    in
      hasAssociations || hasAutostart;

  # Helper function: Get list of platforms that have desktop paths
  #
  # Args:
  #   - desktop: Desktop metadata attribute set
  #
  # Returns:
  #   List of platform names
  getAvailablePlatforms = desktop:
    if (desktop.paths or null) != null
    then lib.attrNames desktop.paths
    else [];

  # Example validation usage contract
  #
  # This shows how platform libraries should validate desktop metadata
  # before processing it.
  exampleValidation = platform: apps: ''
    # In platform library (e.g., platform/darwin/lib/darwin.nix):

    let
      desktopSchema = import ../../../specs/019-app-desktop-metadata/contracts/desktop-metadata-schema.nix { inherit lib; };

      # Validate all applications
      validation = desktopSchema.validateAllDesktopMetadata apps "${platform}";

    in
      # Fail evaluation if validation errors exist
      assert validation.valid || throw ''
        Desktop metadata validation failed:
        ${lib.concatStringsSep "\n" (
          lib.flatten (lib.mapAttrsToList (appName: errors:
            map (err: "  - ${err}") errors
          ) validation.errors)
        )}
      '';

      # Process desktop metadata for valid apps...
  '';

  # Example processing contract
  #
  # This shows how platform libraries should process validated desktop metadata.
  exampleProcessing = platform: apps: ''
    # After validation passes, extract apps with desktop features:

    let
      desktopSchema = import ../../../specs/019-app-desktop-metadata/contracts/desktop-metadata-schema.nix { inherit lib; };

      # Get apps that need desktop integration
      appsWithDesktop = lib.filterAttrs (name: app:
        (app ? desktop) && (desktopSchema.hasDesktopFeatures app.desktop)
      ) apps;

      # Process each app
      processedApps = lib.mapAttrs (appName: app:
        let
          desktop = app.desktop;
          desktopPath = desktopSchema.getDesktopPath desktop "${platform}";
          hasAssociations = (desktop.associations or []) != [];
          hasAutostart = desktop.autostart or false;
        in {
          path = desktopPath;

          # Generate file association configuration
          fileAssociations = lib.optionalAttrs hasAssociations {
            # Platform-specific file association config
            extensions = desktop.associations;
            appPath = desktopPath;
          };

          # Generate autostart configuration
          autostartConfig = lib.optionalAttrs hasAutostart {
            # Platform-specific autostart config
            enabled = true;
            appPath = desktopPath;
          };
        }
      ) appsWithDesktop;

    in processedApps
  '';

  # Type assertion helpers for application modules
  #
  # These can be used in application .nix files to enable type checking
  desktopMetadataOption = description: mkOption {
    type = types.nullOr desktopMetadataType;
    default = null;
    inherit description;
  };

  # Schema version for compatibility checking
  schemaVersion = "1.0.0";

  # Metadata about this schema
  metadata = {
    version = schemaVersion;
    feature = "019-app-desktop-metadata";
    created = "2025-11-16";
    description = "Type definitions and validation contracts for application desktop metadata";
  };
}
