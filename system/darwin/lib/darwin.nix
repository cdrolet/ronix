# Darwin Configuration Library
# Complete darwin system outputs - self-contained and independent
#
# This module exports ALL darwin-specific flake outputs.
# The main flake.nix simply merges these outputs without knowing darwin details.
#
# Required Inputs (must be declared in root flake.nix):
#   - nixpkgs: Main package repository
#   - nix-darwin: macOS system configuration framework
#   - home-manager: User environment manager
#   - agenix: Secret management (Feature 027)
#
# Example flake.nix inputs:
#   nix-darwin = {
#     url = "github:LnL7/nix-darwin";
#     inputs.nixpkgs.follows = "nixpkgs";
#   };
{
  inputs,
  lib,
  nixpkgs,
  validUsers,
  discoverHosts,
  nixConfigRoot,
}: let
  # Validate required inputs exist
  requiredInputs = ["nix-darwin" "home-manager" "nixpkgs"];
  missingInputs = builtins.filter (name: !(inputs ? ${name})) requiredInputs;
  _ =
    if missingInputs != []
    then
      throw ''
        Darwin system requires the following inputs in flake.nix:
          ${lib.concatStringsSep "\n  " missingInputs}

        Please add them to your flake.nix inputs section.
        See system/darwin/lib/darwin.nix header for examples.
      ''
    else null;

  # Feature 021: Discover darwin hosts from directory structure
  darwinHosts = discoverHosts "darwin";

  # Generate all user-host combinations automatically
  # This creates a cartesian product of users × hosts
  darwinCombinations = lib.flatten (
    map (
      user:
        map (host: {inherit user host;}) darwinHosts
    )
    validUsers
  );

  # Import shared configuration loader
  configLoader = import ../../shared/lib/config-loader.nix {inherit lib discoverHosts inputs nixConfigRoot;};

  # Helper to create darwin config with user/host split
  mkDarwinConfig = {
    user,
    host,
  }: let
    # Get Nix platform string (architecture + system)
    platform = configLoader.getNixPlatform {
      inherit host;
      system = "darwin";
    };

    # Load host configuration using shared loader
    hostConfig = configLoader.loadHost {
      inherit host;
      system = "darwin";
    };
    inherit (hostConfig) hostData;

    # Get family defaults
    familyDefaults = configLoader.getFamilyDefaults {hostFamily = hostData.family or [];};

    # Load user configuration using shared loader
    userConfig = configLoader.loadUser {inherit user;};
    inherit (userConfig) userData;

    # Resolve user applications using shared loader
    userAppPaths = configLoader.resolveApplications {
      system = "darwin";
      families = hostData.family or [];
      applications = (userData.user.workspace or {}).applications or [];
      inherit user;
    };

    # Darwin-specific: Also discover all darwin-specific apps (not filtered by user selection)
    # Needed for homebrew extraction since darwin apps might declare casks
    discovery = import ../../shared/lib/discovery.nix {inherit lib;};
    darwinSpecificApps =
      if builtins.pathExists ../app
      then discovery.discoverModules ../app
      else [];
    darwinAppPaths = map (file: ../app + "/${file}") darwinSpecificApps;

    # Combine both sets of apps for homebrew extraction
    appPaths = userAppPaths ++ darwinAppPaths;

    # Helper to safely extract homebrew from a module
    # Only evaluates the homebrew attributes, ignoring home-manager-specific options
    extractHomebrewFromModule = modulePath: let
      # Read module and evaluate it with minimal context
      # Use builtins.tryEval to catch modules that don't have homebrew declarations
      moduleFunc = import modulePath;

      # Provide dummy config with user data to satisfy modules that reference config.user.name
      # This allows aerospace.nix and similar modules to evaluate without errors
      dummyConfig = {
        _configContext = "darwin-system";
        user = userData.user or {name = "dummy";};
        home = {homeDirectory = "/tmp/dummy";};
      };

      safeEval = builtins.tryEval (
        let
          result = moduleFunc {
            config = dummyConfig;
            pkgs = null;
            lib = lib;
            options = {};
            configContext = "darwin-system";
          };

          # Handle both plain attribute sets and lib.mkMerge/lib.mkIf results
          # lib.mkMerge returns { _type = "merge"; contents = [...]; }
          # lib.mkIf returns { _type = "if"; condition = bool; content = {...}; }
          extractFromResult = r:
            if builtins.isList r
            then
              # It's a list - merge all homebrew declarations
              let
                allDeclarations = map extractFromResult r;
              in {
                casks = lib.flatten (map (d: d.casks) allDeclarations);
                brews = lib.flatten (map (d: d.brews) allDeclarations);
                taps = lib.flatten (map (d: d.taps) allDeclarations);
              }
            else if r ? _type && r._type == "merge"
            then extractFromResult r.contents # Unwrap lib.mkMerge
            else if r ? _type && r._type == "if"
            then extractFromResult r.content # Unwrap lib.mkIf
            else {
              # Plain attribute set
              casks = r.homebrew.casks or [];
              brews = r.homebrew.brews or [];
              taps = r.homebrew.taps or [];
            };
        in
          extractFromResult result
      );
    in
      if safeEval.success
      then safeEval.value
      else {
        casks = [];
        brews = [];
        taps = [];
      };

    # Collect all homebrew declarations from apps
    allHomebrewDeclarations = map extractHomebrewFromModule appPaths;

    # Merge into single set and deduplicate
    homebrewFromApps = {
      casks = lib.unique (lib.flatten (map (d: d.casks) allHomebrewDeclarations));
      brews = lib.unique (lib.flatten (map (d: d.brews) allHomebrewDeclarations));
      taps = lib.unique (lib.flatten (map (d: d.taps) allHomebrewDeclarations));
    };

    # Helper to safely extract overlays from a module
    extractOverlaysFromModule = configLoader.mkExtractOverlays {
      inherit userData;
      configContext = "darwin-system";
    };

    # Collect all overlay declarations from apps
    allOverlayDeclarations = map extractOverlaysFromModule appPaths;
    overlaysFromApps = lib.unique (lib.flatten allOverlayDeclarations);
  in
    inputs.nix-darwin.lib.darwinSystem {
      system = platform;
      specialArgs = {
        inherit inputs;
        configContext = "darwin-system";
      };
      modules = [
        # Import context schema and set context marker
        ../../shared/lib/context-schema.nix
        {
          _configContext = "darwin-system";
        }

        # Central system state version
        {
          system.stateVersion = 5;
        }

        # Nixpkgs configuration (system-wide)
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.config.allowBroken = true;
          # App-declared overlays (extracted from user apps)
          nixpkgs.overlays = overlaysFromApps;
        }

        # Feature 039: Import system-level settings only
        # System settings from system/ subdirectories (no user settings)
        {
          imports =
            [
              # Platform-specific system settings (darwin)
              ../settings/system/default.nix
              # Shared system settings (cross-platform)
              ../../shared/settings/system/default.nix
            ]
            # Family system settings (auto-imported based on host.family)
            ++ (map (family: ../../shared/family/${family}/settings/system/default.nix) (hostData.family or []));
        }

        # Set primary user for nix-darwin multi-user support
        {
          system.primaryUser = user;
        }

        # Import schemas for consistent config across system and home-manager
        # Feature 036: Make user/host config available to system modules
        (configLoader.repoRoot + "/user/lib/user-schema.nix")
        (configLoader.repoRoot + "/system/shared/lib/host-schema.nix")

        # Set user and host data using the schemas
        {
          config.user = userData.user;
          config.host = hostData;
        }

        # System-level homebrew integration
        # Collect homebrew declarations from apps (extracted safely above)
        {
          homebrew = {
            casks = homebrewFromApps.casks;
            brews = homebrewFromApps.brews;
            taps = homebrewFromApps.taps;
          };
        }

        # Feature 036: Home Manager now runs in standalone mode
        # User configuration managed separately via homeConfigurations
        # System only handles darwin-specific settings and homebrew
        # All user apps, settings, secrets, etc. are now in standalone home-manager
        {
          # Placeholder - system-level darwin configuration only
        }
      ];
    };
in {
  # Export complete darwin outputs
  outputs = {
    # Darwin system configurations
    darwinConfigurations = builtins.listToAttrs (
      map (cfg: {
        name = "${cfg.user}-${cfg.host}";
        value = mkDarwinConfig cfg;
      })
      darwinCombinations
    );

    # Note: Formatter is now provided by treefmt-nix in flake.nix

    # Darwin-specific validation data (Feature 021)
    validHosts.darwin = darwinHosts;
  };
}
