# Discovery Functions Library
#
# Purpose: Shared utilities for automatically finding and loading modules from directory structures
# Usage: Import in flake.nix, defaults.nix, or any module that needs auto-discovery
# Platform: Cross-platform (platform-agnostic)
#
# Example:
#   let
#     discovery = import ./system/shared/lib/discovery.nix { inherit lib; };
#   in {
#     validUsers = discovery.discoverUsers ./user;
#     imports = map (file: ./${file}) (discovery.discoverModules ./.);
#   }
{lib}: let
  # Predicate: is this a discoverable .nix file?
  # Excludes default.nix (circular deps) and files starting with # (disabled)
  isDiscoverableNixFile = name: type:
    type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix" && !lib.hasPrefix "#" name;

  # Generic function to discover directories containing default.nix
  # Type: discoverDirectoriesWithDefault :: Path → [String]
  # Returns: List of directory names that contain default.nix
  discoverDirectoriesWithDefault = basePath:
    if !builtins.pathExists basePath
    then []
    else let
      entries = builtins.readDir basePath;
      dirs = lib.filterAttrs (name: type: type == "directory") entries;
      hasDefault = name: builtins.pathExists (basePath + "/${name}/default.nix");
    in
      builtins.attrNames (lib.filterAttrs (name: _: hasDefault name) dirs);

  # Discover users from directory structure
  # Type: discoverUsers :: → [String]
  # Returns: List of user names (directories with default.nix)
  discoverUsers = let
    # Note: This function is called from flake.nix, so paths are relative to repo root
    basePath = ../../../user;
  in
    discoverDirectoriesWithDefault basePath;

  # Recursively discover all .nix files in a directory tree
  # Type: discoverModules :: Path → [String]
  # Returns: List of relative file paths (e.g., ["dock.nix", "dev/git.nix"])
  # Excludes: default.nix (to prevent circular dependencies)
  discoverModules = basePath: let
    entries = builtins.readDir basePath;

    # Filter for discoverable .nix files
    files = lib.filterAttrs isDiscoverableNixFile entries;

    # Filter for directories
    dirs = lib.filterAttrs (name: type: type == "directory") entries;

    # Recursively discover files in subdirectories
    subdirFiles = lib.flatten (lib.mapAttrsToList (
        name: _:
          map (file: "${name}/${file}") (discoverModules (basePath + "/${name}"))
      )
      dirs);
  in
    (lib.attrNames files) ++ subdirFiles;

  # Discover modules within a specific context subdirectory
  # Type: discoverModulesInContext :: { basePath :: Path, context :: String } → [String]
  # Returns: List of relative file paths from context subdirectory (e.g., ["dock.nix", "desktop/gnome-core.nix"])
  # Context: "system" or "user" - determines which subdirectory to scan
  # Feature: 039-segregate-settings-directories
  #
  # Example:
  #   discoverModulesInContext { basePath = ./settings; context = "system"; }
  #   # Returns files from ./settings/system/ subdirectory
  #
  # Validation:
  #   - Returns empty list if subdirectory doesn't exist (graceful)
  #   - Excludes default.nix to prevent circular dependencies
  #   - Recursively scans subdirectories
  discoverModulesInContext = {
    basePath,
    context, # "system" or "user"
  }: let
    subdirPath = basePath + "/${context}";
  in
    if builtins.pathExists subdirPath
    then discoverModules subdirPath
    else [];

  # ============================================================================
  # SYSTEM DISCOVERY FUNCTIONS
  # For dynamic system detection without hardcoding
  # ============================================================================

  # Discover all systems in the repository
  # Type: discoverSystems :: Path → [System]
  # Returns: List of system names (directory names in system/ excluding "shared")
  discoverSystems = basePath: let
    systemDir = basePath + "/system";
    entries = builtins.readDir systemDir;
    # Filter for directories, exclude "shared"
    systems =
      lib.filterAttrs (
        name: type:
          type == "directory" && name != "shared"
      )
      entries;
  in
    builtins.attrNames systems;

  # Build complete app registry for validation
  # Type: buildAppRegistry :: Path → AppRegistry
  # Returns: Registry with systems, apps per system, and index
  buildAppRegistry = basePath: let
    # Discover all systems dynamically
    systems = discoverSystems basePath;

    # Discover apps in shared
    sharedPath = basePath + "/system/shared/app";
    sharedApps =
      if builtins.pathExists sharedPath
      then discoverApplicationNames sharedPath
      else [];

    # Discover apps per system
    systemApps = lib.listToAttrs (map (system: {
        name = system;
        value = let
          systemPath = basePath + "/system/${system}/app";
        in
          if builtins.pathExists systemPath
          then discoverApplicationNames systemPath
          else [];
      })
      systems);

    # Build index: app name → list of systems where it exists
    allApps = lib.unique (sharedApps ++ (lib.flatten (lib.attrValues systemApps)));
    index = lib.listToAttrs (map (appName: {
        name = appName;
        value =
          (
            if lib.elem appName sharedApps
            then ["shared"]
            else []
          )
          ++ (lib.filter (system: lib.elem appName systemApps.${system}) systems);
      })
      allApps);
  in {
    inherit systems index;
    apps = systemApps // {shared = sharedApps;};
  };

  # ============================================================================
  # APPLICATION DISCOVERY FUNCTIONS
  # For automatic app resolution by name
  # ============================================================================

  # Discover application names in app directories
  # Type: discoverApplicationNames :: Path → [String]
  # Returns: List of app names (file names without .nix extension or path)
  # Example: ["git", "zsh", "helix"] from system/shared/app/**/
  discoverApplicationNames = basePath: let
    # Reuse discoverModules to get all .nix files recursively (excludes default.nix)
    allFiles = discoverModules basePath;

    # Convert file paths to app names by removing:
    # 1. Directory prefixes (e.g., "dev/git.nix" → "git.nix")
    # 2. .nix extension (e.g., "git.nix" → "git")
    toAppName = filePath:
      lib.removeSuffix ".nix" (baseNameOf filePath);
  in
    map toAppName allFiles;

  # Discover all applications available for a given caller context
  # Type: discoverApplications :: { callerPath :: Path, basePath :: Path } → [String]
  # Returns: List of all application names available in context-appropriate search paths
  discoverApplications = {
    callerPath, # Path of calling file
    basePath, # Repository root
  }: let
    # Detect caller context
    context = detectContext callerPath basePath;

    # Build prioritized search paths
    searchPaths = buildSearchPaths context basePath;

    # Discover apps from all search paths
    allApps = lib.flatten (map (
        path:
          if builtins.pathExists path
          then discoverApplicationNames path
          else []
      )
      searchPaths);
  in
    # Remove duplicates (in case same app exists in multiple locations)
    lib.unique allApps;

  # Detect caller context from path
  # Type: detectContext :: Path → Path → { callerType :: String, system :: String? }
  # Returns: Context information about where the function was called from
  detectContext = callerPath: basePath: let
    # Get relative path from base
    callerStr = toString callerPath;
    baseStr = toString basePath;
    relPath = lib.removePrefix baseStr callerStr;

    # Extract system dynamically from path using regex pattern
    # Pattern: .*/system/([^/]+)/.* captures the system name
    systemMatch = builtins.match ".*/system/([^/]+)/.*" relPath;
    system =
      if systemMatch != null
      then builtins.head systemMatch
      else null;

    # Determine caller type
    isHost = lib.hasInfix "/host/" relPath;
    isUserConfig = lib.hasInfix "/user/" relPath;
  in {
    callerPath = callerPath;
    callerType =
      if isHost && system != null
      then "${system}-host"
      else if isUserConfig
      then "user-config"
      else "unknown";
    system = system;
    basePath = basePath;
  };

  # Build prioritized search paths based on caller context
  # Type: buildSearchPaths :: { callerType :: String, ... } → Path → [Path]
  # Returns: Ordered list of paths to search (highest priority first)
  buildSearchPaths = context: basePath: let
    sharedAppPath = basePath + "/system/shared/app";
    # Construct system-specific path dynamically if system is known
    systemAppPath =
      if context.system != null
      then basePath + "/system/${context.system}/app"
      else null;
  in
    # Priority based on caller context
    if context.system != null && lib.hasInfix "-host" context.callerType
    then
      # System app: system/app first (if exists), then shared
      (lib.optional (systemAppPath != null && builtins.pathExists systemAppPath) systemAppPath)
      ++ [sharedAppPath]
    else if context.callerType == "user-config"
    then
      # User config: shared only (system-agnostic)
      [sharedAppPath]
    else
      # Unknown context: just search shared
      [sharedAppPath];

  # Find app in a directory path (recursive search)
  # Type: findAppInPath :: String → Path → Path?
  # Returns: Full path to app.nix if found, null otherwise
  findAppInPath = appName: searchPath: let
    # Recursive directory search
    searchDir = dir:
      if !builtins.pathExists dir
      then null
      else let
        entries = builtins.readDir dir;

        # Check for direct match: appName.nix
        directMatchName = "${appName}.nix";
        hasDirectMatch = builtins.hasAttr directMatchName entries;
        directMatch = dir + "/${directMatchName}";

        # Check for directory match: appName/default.nix
        hasDirEntry = builtins.hasAttr appName entries;
        isDirType = hasDirEntry && entries.${appName} == "directory";
        dirMatch = dir + "/${appName}/default.nix";
        hasDirMatch = isDirType && builtins.pathExists dirMatch;

        # Get subdirectories to search recursively
        subdirs = lib.filterAttrs (n: v: v == "directory") entries;
        subdirNames = builtins.attrNames subdirs;

        # Search subdirectories (returns first match found)
        searchSubdirs =
          if subdirNames == []
          then null
          else let
            results = map (subdir: searchDir (dir + "/${subdir}")) subdirNames;
            matches = lib.filter (x: x != null) results;
          in
            if matches == []
            then null
            else builtins.head matches;
      in
        if hasDirectMatch
        then directMatch
        else if hasDirMatch
        then dirMatch
        else searchSubdirs;
  in
    searchDir searchPath;

  # Match app with partial or full path
  # Type: matchPartialPath :: String → Path → Path → Path?
  # Returns: Matched path if found, null otherwise
  matchPartialPath = appPath: searchPath: basePath: let
    # Remove leading slash if present
    cleanPath = lib.removePrefix "/" appPath;

    # Remove .nix extension if present
    pathWithoutExt = lib.removeSuffix ".nix" cleanPath;

    # Try various combinations
    attempts = [
      # Try in search path
      (searchPath + "/${cleanPath}.nix")
      (searchPath + "/${cleanPath}/default.nix")
      (searchPath + "/${pathWithoutExt}.nix")
      (searchPath + "/${pathWithoutExt}/default.nix")
      # Try from base path
      (basePath + "/${cleanPath}.nix")
      (basePath + "/${cleanPath}/default.nix")
      (basePath + "/${pathWithoutExt}.nix")
      (basePath + "/${pathWithoutExt}/default.nix")
    ];

    # Find first existing path
    existing = lib.filter builtins.pathExists attempts;
  in
    if existing == []
    then null
    else builtins.head existing;

  # Resolve single app name to path
  # Type: resolveApp :: String → [Path] → Path → Path?
  # Returns: Resolved path or null if not found
  resolveApp = appName: searchPaths: basePath: let
    # Check if appName contains path separator
    hasPath = lib.hasInfix "/" appName;

    # Try each search path in order
    findInPaths = paths:
      if paths == []
      then null
      else let
        currentPath = builtins.head paths;
        remainingPaths = builtins.tail paths;
        result =
          if hasPath
          then matchPartialPath appName currentPath basePath
          else findAppInPath appName currentPath;
      in
        if result != null
        then result
        else findInPaths remainingPaths;
  in
    findInPaths searchPaths;

  # Main function: Resolve list of application names to paths
  # Type: resolveApplications :: { apps :: [String], callerPath :: Path, basePath :: Path, system :: String?, families :: [String]? } → [Path]
  # Returns: List of resolved absolute paths to app modules
  resolveApplications = {
    apps, # List of app names to resolve
    callerPath, # Path of calling file
    basePath, # Repository root
    system ? null, # Optional: system for hierarchical discovery
    families ? [], # Optional: families for hierarchical discovery
  }: let
    # FEATURE 037: Expand wildcards before resolution
    # FEATURE 043: Classify entries and apply exclusion patterns
    wildcardSearchPaths = buildWildcardSearchPaths {
      inherit system families basePath;
    };

    # Classify input into wildcards, exclusions, and explicit includes
    classified = classifyApplicationEntries apps;

    # Expand wildcard includes
    expandedWildcards = lib.flatten (map (
        app:
          expandCategoryWildcard app wildcardSearchPaths
      )
      classified.wildcards);

    # Expand exclusion patterns to flat list of names to exclude
    excludedNames = expandExclusions classified.exclusions wildcardSearchPaths;

    # Subtract exclusions from wildcard results
    afterExclusions =
      lib.filter (
        app:
          !lib.elem app excludedNames
      )
      expandedWildcards;

    # Union with explicit includes (explicits always win, even if excluded)
    deduplicatedApps = lib.unique (afterExclusions ++ classified.explicits);

    # Detect caller context
    context = detectContext callerPath basePath;

    # Build prioritized search paths
    searchPaths = buildSearchPaths context basePath;

    # Build app registry for validation
    registry = buildAppRegistry basePath;

    # Determine if caller is a host (strict validation)
    isHost = lib.hasInfix "-host" context.callerType;

    # Simple suggestion algorithm - find apps with similar names
    suggestApps = appName: let
      allAppNames = builtins.attrNames registry.index;
      # Filter for apps that start with same letter or contain the search term
      similar =
        lib.filter (
          name:
            (lib.hasPrefix (lib.substring 0 1 appName) name)
            || (lib.hasInfix appName name)
            || (lib.hasInfix name appName)
        )
        allAppNames;
      # Limit to 5 suggestions
      limited = lib.take 5 similar;
    in
      limited;

    # Resolve each app with graceful degradation for user configs
    resolved =
      builtins.map (
        appName: let
          # Use hierarchical discovery if system/families provided, otherwise use searchPaths
          result =
            if system != null
            then
              discoverWithHierarchy {
                itemName = appName;
                itemType = "app";
                inherit system families basePath;
              }
            else resolveApp appName searchPaths basePath;
          appExists = builtins.hasAttr appName registry.index;
          availableIn =
            if appExists
            then registry.index.${appName}
            else [];
          suggestions =
            if !appExists
            then suggestApps appName
            else [];
          suggestionText =
            if suggestions != []
            then ''

              Did you mean one of these?
              ${lib.concatMapStringsSep "\n" (s: "  - ${s} (in ${lib.concatStringsSep ", " registry.index.${s}})") suggestions}''
            else "";
        in
          if result == null
          then
            # App not found in current search paths
            if !appExists
            then
              # App doesn't exist anywhere - always error
              throw ''
                error: Application '${appName}' not found in any system

                Searched locations:
                ${lib.concatMapStringsSep "\n" (p: "  - ${toString p}/**/${appName}.nix") searchPaths}

                Called from: ${toString callerPath}${suggestionText}

                Tip: Check app name spelling or add the app to system/*/app/
              ''
            else if isHost
            then
              # Host: strict validation - error on missing app
              throw ''
                error: Application '${appName}' not found in system '${context.system}'

                Available in other systems:
                ${lib.concatMapStringsSep "\n" (p: "  - ${p}") availableIn}

                Searched in current context:
                ${lib.concatMapStringsSep "\n" (p: "  - ${toString p}/**/${appName}.nix") searchPaths}

                Called from: ${toString callerPath}

                Tip: Remove '${appName}' from this host's application list or make it system-specific
              ''
            else
              # User config: graceful degradation - skip unavailable app
              null
          else result
      )
      deduplicatedApps;

    # Filter out nulls (skipped apps from graceful degradation)
    filtered = lib.filter (x: x != null) resolved;
  in
    filtered;

  # ============================================================================
  # FEATURE 037: APP CATEGORY WILDCARDS
  # For wildcard expansion in user.workspace.applications array
  # ============================================================================

  # Detect if a string is a wildcard pattern
  # Type: isWildcard :: String → Bool
  # Returns: true if pattern is "category/*" or "*", false otherwise
  isWildcard = str:
    (builtins.match "(.+)/\\*" str)
    != null # Matches "category/*"
    || str == "*"; # Matches "*"

  # Extract category name from wildcard pattern
  # Type: extractCategory :: String → String?
  # Returns: category name for "category/*", null for "*" or non-wildcards
  extractCategory = str: let
    match = builtins.match "(.+)/\\*" str;
  in
    if match != null
    then builtins.head match # Returns category name
    else null; # Not a category wildcard

  # ============================================================================
  # FEATURE 043: APP EXCLUSION PATTERNS
  # For "!" prefix exclusion in user.workspace.applications array
  # ============================================================================

  # Detect if a string is an exclusion pattern
  # Type: isExclusion :: String → Bool
  # Returns: true if pattern starts with "!", false otherwise
  isExclusion = str: lib.hasPrefix "!" str;

  # Remove "!" prefix from exclusion pattern
  # Type: stripExclusion :: String → String
  # Returns: pattern with "!" prefix removed
  stripExclusion = str: lib.removePrefix "!" str;

  # Classify application entries into wildcards, exclusions, and explicit includes
  # Type: classifyApplicationEntries :: [String] → { wildcards :: [String], exclusions :: [String], explicits :: [String] }
  # Returns: Attrset with three buckets. Exclusions have "!" prefix stripped.
  classifyApplicationEntries = apps: let
    exclusionEntries = lib.filter isExclusion apps;
    wildcardEntries = lib.filter (app: !isExclusion app && isWildcard app) apps;
    explicitEntries = lib.filter (app: !isExclusion app && !isWildcard app) apps;
  in {
    wildcards = wildcardEntries;
    exclusions = map stripExclusion exclusionEntries;
    explicits = explicitEntries;
  };

  # Expand exclusion patterns to a flat list of app names to exclude
  # Type: expandExclusions :: [String] → [Path] → [String]
  # Returns: Flat list of app names to exclude
  # Reuses wildcard infrastructure for category exclusions, silently ignores non-matching
  expandExclusions = exclusions: searchPaths:
    lib.flatten (map (
        pattern:
          if isWildcard pattern
          then
            # Expand wildcard exclusion across all search paths (same as inclusion wildcards)
            let
              category = extractCategory pattern;
              paths =
                map (
                  p:
                    if category != null
                    then p + "/${category}"
                    else p
                )
                searchPaths;
            in
              lib.flatten (map listAppsInCategorySafe paths)
          else [pattern]
      )
      exclusions);

  # List all app names in a category directory (recursive)
  # Type: listAppsInCategory :: Path → [String]
  # Returns: List of app names (filenames without .nix extension)
  listAppsInCategory = dir: let
    entries = builtins.readDir dir;

    # Filter for discoverable .nix files
    nixFiles = lib.filterAttrs isDiscoverableNixFile entries;
    appNames = map (n: lib.removeSuffix ".nix" n) (builtins.attrNames nixFiles);

    # Recursively search subdirectories
    subdirs = lib.filterAttrs (n: t: t == "directory") entries;
    subdirApps = lib.flatten (lib.mapAttrsToList (
        name: _:
          listAppsInCategory (dir + "/${name}")
      )
      subdirs);
  in
    appNames ++ subdirApps;

  # Safe wrapper for listAppsInCategory (handles missing directories)
  # Type: listAppsInCategorySafe :: Path → [String]
  # Returns: List of app names, or empty list if directory doesn't exist
  listAppsInCategorySafe = categoryPath:
    if builtins.pathExists categoryPath
    then listAppsInCategory categoryPath
    else [];

  # Build hierarchical search paths for wildcard expansion
  # Type: buildWildcardSearchPaths :: { system, families, basePath } → [Path]
  # Returns: Ordered list of search paths (system → families → shared)
  buildWildcardSearchPaths = {
    system ? null,
    families ? [],
    basePath,
  }: let
    systemPath = basePath + "/system/${system}/app";
    familyPaths = map (f: basePath + "/system/shared/family/${f}/app") families;
    sharedPath = basePath + "/system/shared/app";
  in
    # Filter out non-existent paths
    (lib.optional (system != null && builtins.pathExists systemPath) systemPath)
    ++ familyPaths
    ++ [sharedPath];

  # Expand a single category wildcard to app names
  # Type: expandCategoryWildcard :: String → [Path] → [String]
  # Returns: List of app names found in category across all search paths
  expandCategoryWildcard = pattern: searchPaths: let
    category = extractCategory pattern;

    # Validate not multi-level wildcard (throws error if invalid)
    # Regex explanation: ^[^/]+/[^/]+/\*$ matches "word/word/*" (multi-level)
    # We want to reject patterns with 2+ slashes (e.g., "browser/sub/*")
    validateMultiLevel =
      if builtins.match "^[^/]+/[^/]+/\\*$" pattern != null
      then
        throw ''
          error: Multi-level wildcards not supported: '${pattern}'

          Wildcard patterns must be single-level:
            - Supported: "category/*"
            - Not supported: "category/subcategory/*"

          Tip: Use "category/*" to get all apps in category, or list specific apps
        ''
      else true;

    # Search each path - for bare "*", list all apps directly; for "category/*", descend into category
    appsInPaths = lib.flatten (map (
        basePath:
          listAppsInCategorySafe (
            if category != null
            then basePath + "/${category}"
            else basePath
          )
      )
      searchPaths);

    # Warn if empty expansion
    warnIfEmpty =
      if appsInPaths == []
      then
        lib.warn ''
          warning: Wildcard '${pattern}' matched zero apps

          Possible causes:
            - Category directory doesn't exist
            - Category is empty
            - Typo in category name

          Available categories can be found in:
            - system/shared/app/
            - system/{platform}/app/
        ''
        true
      else true;
  in
    # Force validation before returning results
    if validateMultiLevel && warnIfEmpty
    then appsInPaths
    else [];

  # ============================================================================
  # FEATURE 021: HOST/FAMILY HIERARCHICAL DISCOVERY
  # For host configurations and cross-platform family support
  # ============================================================================

  # Discover hosts for a specific system
  # Type: discoverHosts :: String → [String]
  # Returns: List of host names found in system/${system}/host/
  discoverHosts = system: let
    # Note: This function is called from flake.nix, so paths are relative to repo root
    hostPath = ./../../${system}/host;
  in
    if builtins.pathExists hostPath
    then discoverDirectoriesWithDefault hostPath
    else [];

  # Validate that all family names in array exist
  # Type: validateFamilyExists :: [String] → Path → Bool
  # Throws: Error if any family doesn't exist
  validateFamilyExists = families: basePath: let
    familyPath = basePath + "/system/shared/family";

    checkFamily = family: let
      path = familyPath + "/${family}";
    in
      if !builtins.pathExists path
      then
        throw ''
          error: Family '${family}' not found

          Expected location: ${toString path}

          Available families:
          ${lib.concatStringsSep "\n" (map (f: "  - ${f}") (
            if builtins.pathExists familyPath
            then builtins.attrNames (builtins.readDir familyPath)
            else []
          ))}

          Tip: Create the family directory or fix the family name in your host configuration
        ''
      else true;
  in
    lib.all checkFamily families;

  # Validate that settings array doesn't contain "*" wildcard
  # Type: validateNoWildcardInSettings :: [String] → Bool
  # Throws: Error if "*" found in settings
  validateNoWildcardInSettings = settings:
    if lib.elem "*" settings
    then
      throw ''
        error: Wildcard "*" is not allowed in settings arrays

        Settings array contains: ${lib.concatStringsSep ", " settings}

        Why: Settings require explicit selection for safety.
        Use "default" to import all system settings, or list specific settings.

        Examples:
          settings = ["default"];           # Import all system settings
          settings = ["dock" "keyboard"];   # Import specific settings

        Tip: Replace ["*"] with ["default"] in your host configuration
      ''
    else true;

  # Auto-install family defaults if they exist
  # Type: autoInstallFamilyDefaults :: [String] → Path → [Path]
  # Returns: List of paths to family default.nix files that exist
  # Feature 039: Updated to use system/ subdirectory for system-level settings
  autoInstallFamilyDefaults = families: basePath: let
    familyBasePath = basePath + "/system/shared/family";

    # For each family, check if app/default.nix and settings/system/default.nix exist
    collectDefaults = family: let
      familyPath = familyBasePath + "/${family}";
      appDefault = familyPath + "/app/default.nix";
      settingsSystemDefault = familyPath + "/settings/system/default.nix";
    in
      (lib.optional (builtins.pathExists appDefault) appDefault)
      ++ (lib.optional (builtins.pathExists settingsSystemDefault) settingsSystemDefault);
  in
    lib.flatten (map collectDefaults families);

  # Hierarchical discovery: search system → families → shared
  # Type: discoverWithHierarchy :: { itemName, itemType, system, families, basePath } → Path?
  # Returns: Path to first match, or null if not found
  discoverWithHierarchy = {
    itemName, # String: app/setting name
    itemType, # String: "app" or "setting"
    system, # String: "darwin", "nixos"
    families ? [], # [String]: optional family names
    basePath, # Path: repository root
  }: let
    # Build search paths in priority order
    systemPath = basePath + "/system/${system}/${itemType}";
    familyPaths =
      map (
        family:
          basePath + "/system/shared/family/${family}/${itemType}"
      )
      families;
    sharedPath = basePath + "/system/shared/${itemType}";

    # All paths in search order
    searchPaths = [systemPath] ++ familyPaths ++ [sharedPath];

    # Search in order, return first match
    searchInOrder = paths:
      if paths == []
      then null
      else let
        currentPath = builtins.head paths;
        remainingPaths = builtins.tail paths;
        result =
          if builtins.pathExists currentPath
          then findAppInPath itemName currentPath
          else null;
      in
        if result != null
        then result
        else searchInOrder remainingPaths;
  in
    searchInOrder searchPaths;

  # ============================================================================
  # FEATURE 045: SHARED HARDWARE PROFILES
  # Resolve hardware profile names to paths with fuzzy resolution
  # ============================================================================

  # Resolve a list of hardware profile names to absolute paths
  # Type: resolveHardwareProfiles :: [String] -> Path -> [Path]
  # Returns: List of resolved absolute paths to hardware profile modules
  #
  # Resolution rules:
  # - Names containing "/" resolve directly: "vm/qemu-guest" -> basePath/vm/qemu-guest.nix
  # - Bare names search all subdirectories: "qemu-guest" -> finds vm/qemu-guest.nix
  # - Ambiguous bare names (multiple matches) cause a build error
  # - Missing profiles cause a build error listing available profiles
  resolveHardwareProfiles = profileNames: basePath: let
    hardwareDir = basePath + "/system/shared/hardware";

    # List all available profiles for error messages
    listAvailableProfiles =
      if builtins.pathExists hardwareDir
      then discoverModules hardwareDir
      else [];

    # Find all matches for a bare name across all subdirectories
    findAllMatches = name: let
      allFiles = listAvailableProfiles;
      # Match files where the basename (without .nix) equals the name
      matches =
        lib.filter (
          file: (lib.removeSuffix ".nix" (baseNameOf file)) == name
        )
        allFiles;
    in
      matches;

    # Resolve a single profile name to a path
    resolveProfile = name: let
      hasPath = lib.hasInfix "/" name;

      # Direct resolution for full paths
      directPath = hardwareDir + "/${name}.nix";

      # Fuzzy resolution for bare names
      matches = findAllMatches name;
      matchCount = builtins.length matches;

      availableText = let
        profiles = listAvailableProfiles;
      in
        if profiles == []
        then "  (no profiles found)"
        else lib.concatMapStringsSep "\n" (f: "  - ${lib.removeSuffix ".nix" f}") profiles;
    in
      if hasPath
      then
        # Direct path resolution
        if builtins.pathExists directPath
        then directPath
        else
          throw ''
            error: Hardware profile '${name}' not found

            Expected location: ${toString directPath}

            Available profiles:
            ${availableText}

            Tip: Check the profile name or create it at the expected location
          ''
      else
        # Fuzzy resolution for bare names
        if matchCount == 1
        then hardwareDir + "/${builtins.head matches}"
        else if matchCount > 1
        then
          throw ''
            error: Ambiguous hardware profile '${name}'

            Multiple matches found:
            ${lib.concatMapStringsSep "\n" (f: "  - ${lib.removeSuffix ".nix" f}") matches}

            Use the full path to disambiguate (e.g., "${lib.removeSuffix ".nix" (builtins.head matches)}")
          ''
        else
          throw ''
            error: Hardware profile '${name}' not found

            Searched in: ${toString hardwareDir}/

            Available profiles:
            ${availableText}

            Tip: Check the profile name or create it under system/shared/hardware/
          '';
    resolvedPaths = map resolveProfile profileNames;

    # Feature 046: Validate at most one storage profile
    storageProfiles = lib.filter (p: lib.hasInfix "/storage/" (toString p)) resolvedPaths;
    storageCount = builtins.length storageProfiles;
  in
    if storageCount > 1
    then
      throw ''
        error: Multiple storage profiles declared — only one is allowed per host

        Found ${toString storageCount} storage profiles:
        ${lib.concatMapStringsSep "\n" (p: "  - ${toString p}") storageProfiles}

        Storage profiles (standard-partitions, luks-encrypted, etc.) are mutually exclusive.
        Remove all but one from the host's hardware list.
      ''
    else resolvedPaths;
in {
  # Export only externally-used discovery functions
  # Internal functions (discoverSystems, buildAppRegistry, detectContext,
  # buildSearchPaths, findAppInPath) are not exported
  inherit
    discoverDirectoriesWithDefault
    discoverUsers
    discoverModules
    discoverModulesInContext
    discoverApplicationNames
    discoverApplications
    resolveApplications
    discoverHosts
    discoverWithHierarchy
    validateFamilyExists
    validateNoWildcardInSettings
    autoInstallFamilyDefaults
    resolveHardwareProfiles
    ;
}
