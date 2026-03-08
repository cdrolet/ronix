# NixOS Configuration Library
# Complete nixos system outputs - self-contained and independent
#
# This module exports ALL nixos-specific flake outputs.
# The main flake.nix simply merges these outputs without knowing nixos details.
#
# Required Inputs (must be declared in root flake.nix):
#   - nixpkgs: Main package repository
#   - home-manager: User environment manager
#   - agenix: Secret management (Feature 027)
#
# Example flake.nix inputs:
#   nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
#   home-manager = {
#     url = "github:nix-community/home-manager";
#     inputs.nixpkgs.follows = "nixpkgs";
#   };
{
  inputs,
  lib,
  nixpkgs,
  validUsers,
  discoverHosts,
  privateConfigRoot,
}: let
  # Validate required inputs exist
  requiredInputs = ["nixpkgs" "home-manager"];
  missingInputs = builtins.filter (name: !(inputs ? ${name})) requiredInputs;

  # Import shared configuration loader
  configLoader = import ../../shared/lib/config-loader.nix {inherit lib discoverHosts inputs privateConfigRoot;};

  _ =
    if missingInputs != []
    then
      throw ''
        NixOS system requires the following inputs in flake.nix:
          ${lib.concatStringsSep "\n  " missingInputs}

        Please add them to your flake.nix inputs section.
        See system/nixos/lib/nixos.nix header for examples.
      ''
    else null;
  # Feature 021: Discover nixos hosts from directory structure
  nixosHosts = discoverHosts "nixos";

  # Generate all user-host combinations automatically
  # This creates a cartesian product of users × hosts
  nixosCombinations = let
    # Generate ALL possible combinations
    allCombinations = lib.flatten (
      map (
        user:
          map (host: {inherit user host;}) nixosHosts
      )
      validUsers
    );
    # Optional: Add validation rules to filter invalid combinations
    # Uncomment and customize the filter below if needed:
    #
    # validCombinations = lib.filter (cfg:
    #   # Add custom validation rules here
    #   true  # Accept all combinations by default
    # ) allCombinations;
  in
    allCombinations; # Use validCombinations if filtering enabled

  # Helper to create nixos config with user/host split
  mkNixosConfig = {
    user,
    host, # Feature 021: renamed from profile
  }: let
    # Get Nix platform string (architecture + system)
    platform = configLoader.getNixPlatform {
      inherit host;
      system = "nixos";
    };

    # Load host configuration using shared loader
    hostConfig = configLoader.loadHost {
      inherit host;
      system = "nixos";
    };
    inherit (hostConfig) hostData;

    # Load user configuration using shared loader
    userConfig = configLoader.loadUser {inherit user;};
    inherit (userConfig) userData;

    # Get family defaults
    familySettingsDefaults = configLoader.getFamilyDefaults {hostFamily = hostData.family or [];};

    # Resolve user applications for overlay extraction
    resolvedApplications = configLoader.resolveApplications {
      system = "nixos";
      families = hostData.family or [];
      applications = (userData.user.workspace or {}).applications or [];
      inherit user;
    };

    # Extract overlays from user apps
    extractOverlaysFromModule = configLoader.mkExtractOverlays {
      inherit userData;
      configContext = "nixos-system";
      extraArgs = {system = platform;};
    };

    allOverlayDeclarations = map extractOverlaysFromModule resolvedApplications;
    overlaysFromApps = lib.unique (lib.flatten allOverlayDeclarations);

    # Feature 045: Resolve shared hardware profiles from host config
    discovery = import ../../shared/lib/discovery.nix {inherit lib;};
    sharedHardwareModules = discovery.resolveHardwareProfiles (hostData.hardware or []) configLoader.repoRoot;

    # Check if hardware configuration exists for this host
    hardwarePath = configLoader.repoRoot + "/system/nixos/host/${host}/hardware.nix";
    hardwareModule = lib.optional (builtins.pathExists hardwarePath) hardwarePath;
  in
    nixpkgs.lib.nixosSystem {
      system = platform;
      specialArgs = {
        inherit inputs;
        configContext = "nixos-system";
      };
      modules =
        [
          # Nixpkgs configuration (system-wide)
          {
            # Derive platform from host architecture + system
            nixpkgs.hostPlatform = platform;
            nixpkgs.config.allowUnfree = true;
            nixpkgs.config.allowUnsupportedSystem = true;
            nixpkgs.config.allowBroken = true;
            # App-declared overlays (extracted from user apps)
            nixpkgs.overlays = overlaysFromApps;
          }

          # Feature 046: Disko declarative disk management
          inputs.disko.nixosModules.disko
          # Default disk device for disko storage profiles (override per-host with _module.args.disks)
          {_module.args.disks = lib.mkDefault ["/dev/vda"];}

          # Feature 039: Import system-level settings only
          # Platform-specific system settings (nixos)
          (configLoader.repoRoot + "/system/nixos/settings/system/default.nix")

          # Shared system settings (cross-platform)
          (configLoader.repoRoot + "/system/shared/settings/system/default.nix")

          # Feature 028: Import family settings at SYSTEM level
          # Family system settings (desktop environment, etc.)
        ]
        ++ familySettingsDefaults
        ++ sharedHardwareModules
        ++ hardwareModule
        ++ [
          # Import schemas for consistent config across system and home-manager
          # Feature 036: Make user/host config available to system modules
          (configLoader.repoRoot + "/user/lib/user-schema.nix")
          (configLoader.repoRoot + "/system/shared/lib/host-schema.nix")

          # Set user and host data using the schemas
          {
            config.user = userData.user;
            config.host = hostData;
          }

          # Feature 036: Home Manager now runs in standalone mode
          # User configuration managed separately via homeConfigurations
          # System only handles NixOS-specific settings
        ];
    };
in {
  # Export complete nixos outputs
  # These are merged directly into flake outputs by flake.nix
  outputs = {
    # NixOS system configurations
    nixosConfigurations = builtins.listToAttrs (
      map (cfg: {
        name = "${cfg.user}-${cfg.host}";
        value = mkNixosConfig cfg;
      })
      nixosCombinations
    );

    # NixOS formatter (when needed - currently empty)
    # formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;

    # NixOS-specific validation data
    validHosts.linux = nixosHosts;
  };
}
