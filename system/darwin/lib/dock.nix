# Darwin Dock Helper Library
#
# Provides helper functions for managing macOS Dock configuration.
# All functions generate idempotent shell scripts safe to run multiple times.
#
# Feature: 023-user-dock-config - Extended with user config resolution
# Feature: 042-fuzzy-dock-matching - Fuzzy app name resolution
{
  pkgs,
  lib,
}: let
  # Import shared dock parsing utilities
  dockParseLib = import ../../shared/lib/dock.nix {inherit lib;};

  # Import fuzzy matcher
  fuzzyMatcher = import ../../shared/lib/fuzzy-dock-matcher.nix {inherit lib;};

  # Helper to get dockutil path
  dockutil = "${pkgs.dockutil}/bin/dockutil";

  # Application search paths in priority order
  appSearchPaths = [
    "/Applications"
    "/System/Applications"
    "/System/Applications/Utilities"
  ];

  # Resolve app name to .app path (case-insensitive). Returns null if not found.
  resolveAppPath = appName: userName: let
    capitalize = s:
      if builtins.stringLength s == 0
      then s
      else (lib.toUpper (builtins.substring 0 1 s)) + (builtins.substring 1 (builtins.stringLength s - 1) s);

    capitalizedName = capitalize appName;
    userAppsPath = "/Users/${userName}/Applications";
    allPaths = appSearchPaths ++ [userAppsPath];

    candidates = lib.flatten (map (
        dir: [
          "${dir}/${capitalizedName}.app"
          "${dir}/${appName}.app"
          "${dir}/${lib.toUpper appName}.app"
        ]
      )
      allPaths);

    existingPaths = lib.filter (p: builtins.pathExists p) candidates;
  in
    if existingPaths == []
    then null
    else builtins.head existingPaths;

  # Resolve folder entry to full path. Tries $HOME/<name> first, then absolute.
  resolveFolderPath = folderName: userName: let
    userPath = "/Users/${userName}/${folderName}";
    absolutePath = "/${folderName}";
  in
    if builtins.pathExists userPath
    then userPath
    else if builtins.pathExists absolutePath
    then absolutePath
    else null;

  # Build app catalog from filesystem for fuzzy matching
  buildDarwinAppCatalog = userName: let
    userAppsPath = "/Users/${userName}/Applications";
    allSearchPaths = appSearchPaths ++ [userAppsPath];

    # Scan all app directories for .app bundles
    findAppsInDir = dir:
      if builtins.pathExists dir
      then let
        entries = builtins.readDir dir;
        appEntries =
          lib.filterAttrs (
            name: type:
              type == "directory" && lib.hasSuffix ".app" name
          )
          entries;
        appNames = lib.attrNames appEntries;
      in
        map (name: {
          name = builtins.substring 0 (builtins.stringLength name - 4) name; # Remove .app
          path = "${dir}/${name}";
        })
        appNames
      else [];

    # Collect all apps from all directories
    allApps = lib.flatten (map findAppsInDir allSearchPaths);

    # Deduplicate by name (first occurrence wins)
    uniqueApps =
      lib.foldl' (
        acc: app:
          if lib.any (a: a.name == app.name) acc
          then acc
          else acc ++ [app]
      ) []
      allApps;
  in
    uniqueApps;
in {
  # Clear all Dock items (idempotent)
  mkDockClear = ''
    ${dockutil} --remove all --no-restart || true
  '';

  # Add application to Dock (idempotent)
  mkDockAddApp = {
    path,
    position ? "end",
  }: let
    posArg =
      if position == "end"
      then ""
      else "--position ${toString position}";
  in ''
    app_name=$(basename ${lib.escapeShellArg path} .app)
    if ! ${dockutil} --find "$app_name" >/dev/null 2>&1; then
      ${dockutil} --add ${lib.escapeShellArg path} ${posArg} --no-restart
    fi
  '';

  # Add folder to Dock (idempotent)
  mkDockAddFolder = {
    path,
    view ? "auto",
    display ? "folder",
    sort ? "name",
  }: ''
    folder_name=$(basename ${lib.escapeShellArg path})
    if ! ${dockutil} --find "$folder_name" >/dev/null 2>&1; then
      ${dockutil} --add ${lib.escapeShellArg path} \
        --view ${view} \
        --display ${display} \
        --sort ${sort} \
        --no-restart
    fi
  '';

  # Add spacer (separator) to Dock
  mkDockAddSpacer = ''
    ${dockutil} --add "" --type spacer --section apps --no-restart
  '';

  # Add small spacer to Dock
  mkDockAddSmallSpacer = ''
    ${dockutil} --add "" --type small-spacer --section apps --no-restart
  '';

  # Restart Dock to apply changes
  mkDockRestart = ''
    killall Dock
  '';

  # Generate complete dock activation script from user config with fuzzy matching
  mkDockFromUserConfig = dockedList: userName: let
    # Build app catalog for fuzzy matching
    appCatalog = buildDarwinAppCatalog userName;

    # Use fuzzy matcher to resolve entries
    fuzzyResult = fuzzyMatcher.fuzzyMatchDock {
      entries = dockedList;
      inherit appCatalog;
    };

    parsedEntries = dockParseLib.parseAndNormalize dockedList;

    resolveEntry = position: entry:
      if entry.type == "app"
      then let
        # Try fuzzy match first
        matched = lib.findFirst (m: m.entry == entry.value && m.matched) null fuzzyResult.summary;
        appPath =
          if matched != null
          then matched.path
          else resolveAppPath entry.value userName;
      in
        if appPath != null
        then ''
          # App: ${entry.value}${
            if matched != null
            then " (${matched.strategy})"
            else ""
          }
          app_name=$(basename ${lib.escapeShellArg appPath} .app)
          if ! ${dockutil} --find "$app_name" >/dev/null 2>&1; then
            ${dockutil} --add ${lib.escapeShellArg appPath} --position ${toString position} --no-restart
          fi
        ''
        else "# Skipped: ${entry.value} (not found)\n"
      else if entry.type == "folder"
      then let
        folderPath = resolveFolderPath entry.value userName;
      in
        if folderPath != null
        then ''
          # Folder: ${entry.value}
          folder_name=$(basename ${lib.escapeShellArg folderPath})
          if ! ${dockutil} --find "$folder_name" >/dev/null 2>&1; then
            ${dockutil} --add ${lib.escapeShellArg folderPath} \
              --view auto \
              --display folder \
              --sort name \
              --no-restart
          fi
        ''
        else "# Skipped: /${entry.value} (folder not found)\n"
      else if entry.type == "separator"
      then
        if entry.value == "thick"
        then ''
          # Thick separator
          ${dockutil} --add "" --type small-spacer --section apps --no-restart
        ''
        else ''
          # Standard separator
          ${dockutil} --add "" --type spacer --section apps --no-restart
        ''
      else if entry.type == "system"
      then "# System item: <${entry.value}> (darwin manages automatically)\n"
      else "# Unknown entry type: ${entry.raw}\n";

    commands = lib.imap1 resolveEntry parsedEntries;
  in
    lib.concatStringsSep "\n" commands;

  # Export resolution functions for external use
  inherit resolveAppPath resolveFolderPath;

  # Re-export parsing library
  inherit (dockParseLib) parseDockEntry parseDockedList parseAndNormalize hasDockedItems;
}
