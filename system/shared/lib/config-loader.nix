# Configuration Loader Library
# Shared logic for loading and validating user/host configurations
#
# This module eliminates duplication across darwin.nix, nixos.nix, and home-manager.nix
# by centralizing the common patterns for loading pure data configurations.
#
# Feature 047: user/host configs always come from privateConfigRoot (mandatory).
# Structure: privateConfigRoot/users/<name>/default.nix
#            privateConfigRoot/hosts/<system>/<name>/default.nix
{
  lib,
  discoverHosts,
  inputs ? {},
  # Private user/host config repo root (mandatory — Feature 047)
  privateConfigRoot,
}: let
  # Import discovery system
  discovery = import ./discovery.nix {inherit lib;};

  # Repository root for path construction (always the framework repo)
  repoRoot = ../../..;

  # Where user directories live: privateConfigRoot/users/<name>/
  userDataRoot = privateConfigRoot + "/users";

  # Where host directories live: privateConfigRoot/hosts/<system>/<name>/
  hostDataRoot = system: privateConfigRoot + "/hosts/${system}";

  # Platform-agnostic system discovery
  # Automatically discovers all systems by scanning system/ directory
  getAllSystems = let
    systemsPath = repoRoot + "/system";
    entries = builtins.readDir systemsPath;
    # Filter to only directories with host subdirectories (actual systems)
    systems =
      lib.filterAttrs (
        name: type:
          type
          == "directory"
          && name != "shared"
          && builtins.pathExists (systemsPath + "/${name}/host")
      )
      entries;
  in
    builtins.attrNames systems;

  # Helper to determine platform from host name
  # Scans all system directories to find which contains the host
  getPlatformForHost = hostName:
    lib.findFirst
    (platform: builtins.elem hostName (discoverHosts platform))
    (throw "Unknown host: ${hostName} (not found in any system directory)")
    getAllSystems;

  # Load user configuration
  # Returns: { userData }
  # Note: Field extraction now handled by user-schema.nix (single source of truth)
  loadUser = {
    user,
    userBasePath ? userDataRoot,
  }: let
    userDataPath = userBasePath + "/${user}";
    userData = import userDataPath {};
  in {
    inherit userData;
  };

  # Load host configuration
  # Returns: { hostData }
  # Note: Field extraction now handled by host-schema.nix (single source of truth)
  # Note: Validation still performed here (families exist, no wildcards in settings)
  loadHost = {
    host,
    system ? null,
    hostBasePath ? null,
  }: let
    # Auto-detect system if not provided
    actualSystem =
      if system != null
      then system
      else getPlatformForHost host;

    actualHostBasePath =
      if hostBasePath != null
      then hostBasePath
      else hostDataRoot actualSystem;

    hostDataPath = actualHostBasePath + "/${host}";
    hostData = import hostDataPath {};

    # Validate host configuration
    hostFamily = hostData.family or [];
    _ =
      # Validate families exist
      assert (hostFamily != [] -> discovery.validateFamilyExists hostFamily repoRoot); null;
  in {
    inherit hostData;
  };

  # Get Nix platform string for a host (e.g., "aarch64-darwin", "x86_64-linux")
  # Platform = architecture + system
  # - architecture: from host config (aarch64, x86_64)
  # - system: OS name (darwin, nixos) - auto-detected or provided
  # Returns: Nix platform string (e.g., "aarch64-darwin", "x86_64-linux")
  getNixPlatform = {
    host,
    system ? null,
  }: let
    # Auto-detect system if not provided
    actualSystem =
      if system != null
      then system
      else getPlatformForHost host;

    # Load host to get architecture
    hostConfig = loadHost {
      inherit host;
      system = actualSystem;
    };
    architecture = hostConfig.hostData.architecture;

    # Append system-specific suffix
    suffix =
      if actualSystem == "darwin"
      then "-darwin"
      else "-linux";
  in "${architecture}${suffix}";

  # Get family settings defaults for system-level installation
  # Returns: list of module paths
  getFamilyDefaults = {hostFamily}:
    if hostFamily != []
    then discovery.autoInstallFamilyDefaults hostFamily repoRoot
    else [];

  # Resolve applications using hierarchical discovery
  # Returns: list of module paths
  resolveApplications = {
    system,
    families,
    applications,
    user ? null,
  }: let
    # Determine caller path (user path if provided, otherwise system path)
    callerPath =
      if user != null
      then repoRoot + "/user/${user}"
      else repoRoot + "/system/${system}";

    resolvedApps = applications;
  in
    if resolvedApps != []
    then
      discovery.resolveApplications {
        apps = resolvedApps;
        inherit callerPath;
        basePath = repoRoot;
        inherit system;
        inherit families;
      }
    else [];

  # Extract nixpkgs overlays declared by an app module.
  # Shared across darwin, nixos, and home-manager to avoid duplication.
  #
  # Usage:
  #   extractOverlaysFromModule = configLoader.mkExtractOverlays {
  #     inherit userData;
  #     configContext = "darwin-system"; # or "nixos-system" / "home-manager"
  #     extraArgs = { system = platform; }; # optional, e.g. for nixos
  #   };
  #   overlaysFromApps = lib.unique (lib.flatten (map extractOverlaysFromModule appPaths));
  mkExtractOverlays = {
    userData,
    configContext,
    extraArgs ? {},
  }:
    modulePath: let
      moduleFunc = import modulePath;
      dummyConfig = {
        _configContext = configContext;
        user = userData.user or {name = "dummy";};
        home = {homeDirectory = "/tmp/dummy";};
      };
      safeEval = builtins.tryEval (
        let
          result = moduleFunc ({
              config = dummyConfig;
              pkgs = null;
              lib = lib;
              inputs = inputs;
              options = {};
              configContext = configContext;
            }
            // extraArgs);
          extractFromResult = r:
            if builtins.isList r
            then lib.flatten (map extractFromResult r)
            else if r ? _type && r._type == "merge"
            then extractFromResult r.contents
            else if r ? _type && r._type == "if"
            then extractFromResult r.content
            else r.nixpkgs.overlays or [];
        in
          extractFromResult result
      );
    in
      if safeEval.success then safeEval.value else [];
in {
  inherit loadUser loadHost getNixPlatform getFamilyDefaults resolveApplications;
  inherit getPlatformForHost mkExtractOverlays;
  inherit repoRoot;
  # Effective root for user data directories (used by wallpaper, secrets, etc.)
  inherit userDataRoot;
}
