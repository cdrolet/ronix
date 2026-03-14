# Home Manager Standalone Configuration Library
# Generates homeConfigurations for standalone home-manager mode
#
# Feature: 036-standalone-home-manager
# Purpose: Provide lib.hm utilities by using standalone home-manager mode
#
# This module exports homeConfigurations for all valid user@host combinations.
# Unlike the nix-darwin/NixOS module integration, standalone mode properly
# extends lib with lib.hm before module evaluation.
#
# Required Inputs (must be declared in root flake.nix):
#   - nixpkgs: Main package repository
#   - home-manager: User environment manager
#   - agenix: Secret management (Feature 031)
{
  inputs,
  lib,
  nixpkgs,
  validUsers,
  discoverHosts,
  nixConfigRoot,
}: let
  # Import discovery library
  discovery = import ../../system/shared/lib/discovery.nix {inherit lib;};

  # Validate required inputs exist
  requiredInputs = ["home-manager" "nixpkgs" "stylix"];
  missingInputs = builtins.filter (name: !(inputs ? ${name})) requiredInputs;
  _ =
    if missingInputs != []
    then
      throw ''
        Standalone home-manager requires the following inputs in flake.nix:
          ${lib.concatStringsSep "\n  " missingInputs}

        Please add them to your flake.nix inputs section.
      ''
    else null;

  # Import shared configuration loader
  configLoader = import ../../system/shared/lib/config-loader.nix {inherit lib discoverHosts inputs nixConfigRoot;};

  # Repository root for path construction
  repoRoot = configLoader.repoRoot;

  # Helper to create home-manager configuration for a user@host
  mkHomeConfig = {
    user,
    host,
  }: let
    # Determine system from host (darwin/nixos)
    system = configLoader.getPlatformForHost host;

    # Get Nix platform string (architecture + system)
    platform = configLoader.getNixPlatform {inherit host;};

    # Load user configuration using shared loader
    userConfig = configLoader.loadUser {inherit user;};
    inherit (userConfig) userData;

    # Load host configuration using shared loader
    hostConfig = configLoader.loadHost {inherit host;};
    inherit (hostConfig) hostData;

    # Resolve user applications using shared loader
    resolvedApplications = configLoader.resolveApplications {
      inherit system;
      families = hostData.family or [];
      applications = (userData.user.workspace or {}).applications or [];
      inherit user;
    };

    # Extract overlays from user apps
    extractOverlaysFromModule = configLoader.mkExtractOverlays {
      inherit userData;
      configContext = "home-manager";
    };

    allOverlayDeclarations = map extractOverlaysFromModule resolvedApplications;
    overlaysFromApps = lib.unique (lib.flatten allOverlayDeclarations);

    # pkgs for the target platform
    pkgs = import nixpkgs {
      system = platform;
      config.allowUnfree = true;
      config.allowUnsupportedSystem = true;
      config.allowBroken = true;
      # App-declared overlays (extracted from user apps)
      # Plus workaround for fish test failures on darwin (nixpkgs upstream issue)
      overlays =
        overlaysFromApps
        ++ [
          (final: prev:
            lib.optionalAttrs prev.stdenv.isDarwin {
              fish = prev.fish.overrideAttrs (old: {doCheck = false;});
            })
        ];
    };
  in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      # Import user modules
      modules =
        [
          # Context schema and marker
          (repoRoot + "/system/shared/lib/context-schema.nix")
          {
            _configContext = "home-manager";
          }

          # Stylix module for automatic font theming
          inputs.stylix.homeModules.stylix

          # Disable stylix Qt module on darwin (qt.qt5ctSettings option doesn't exist)
          {
            disabledModules =
              lib.optionals (system == "darwin")
              [(inputs.stylix + "/modules/qt/hm.nix")];
          }

          # User schema (provides options.user with proper types and validation)
          (repoRoot + "/user/lib/user-schema.nix")

          # Host schema (provides options.host for VM detection, family info, etc.)
          (repoRoot + "/system/shared/lib/host-schema.nix")

          # User and host data configuration
          {
            config = {
              # Set user data
              user = userData.user;

              # Set host data (makes config.host available to all modules)
              host = hostData;

              # Home Manager configuration
              home = {
                username = userData.user.name;
                homeDirectory =
                  if system == "darwin"
                  then "/Users/${userData.user.name}"
                  else "/home/${userData.user.name}";

                # State version for compatibility
                stateVersion = "25.05";
              };

              # Enable home-manager self-management
              programs.home-manager.enable = true;
            };
          }

          # Secrets module (user secret validation)
          (import ./secrets.nix {
            inherit lib;
            user = userData.user.name;
            repoRoot = configLoader.userDataRoot;
          }).module

          # Feature 039: Import user-level settings only
          # Platform-specific user settings from user/ subdirectory
          (repoRoot + "/system/${system}/settings/user/default.nix")

          # Feature 039: Import shared user-level settings
          # Cross-platform user settings from user/ subdirectory
          (repoRoot + "/system/shared/settings/user/default.nix")

          # Feature 039: Import family user-level settings
          # Family user settings from user/ subdirectory (if families defined)
        ]
        ++ (lib.flatten (map (
          family: let
            familyUserSettings = repoRoot + "/system/shared/family/${family}/settings/user/default.nix";
          in
            lib.optional (builtins.pathExists familyUserSettings) familyUserSettings
        ) (hostData.family or [])))
        ++ resolvedApplications;

      # Extra special args available to all modules
      extraSpecialArgs = {
        inherit inputs;
        system = platform; # Nix platform string (e.g., "aarch64-darwin")
        configContext = "home-manager";
        # Effective root for user data directories (wallpaper, secrets, etc.)
        userDataRoot = configLoader.userDataRoot;
        # Host name for host-specific filtering (e.g. wallpapers)
        hostName = host;
        # Note: lib is automatically extended with lib.hm in standalone mode!
      };
    };

  # Generate all user-host combinations
  # Platform-agnostic: discovers hosts from all systems automatically
  allCombinations = let
    # Discover hosts from darwin and nixos
    darwinHosts = discoverHosts "darwin";
    nixosHosts = discoverHosts "nixos";
    allHosts = darwinHosts ++ nixosHosts;
  in
    lib.flatten (
      map (
        user:
          map (host: {inherit user host;}) allHosts
      )
      validUsers
    );

  # Generate homeConfigurations attrset
  # Format: "user@host" = homeManagerConfiguration
  homeConfigurations = builtins.listToAttrs (
    map (
      combo: {
        name = "${combo.user}@${combo.host}";
        value = mkHomeConfig {
          inherit (combo) user host;
        };
      }
    )
    allCombinations
  );
in {
  outputs = {
    inherit homeConfigurations;
  };
}
