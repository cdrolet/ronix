# Helper library for resolving user default applications
# Generic resolution system - not aware of specific app types
{
  lib,
  pkgs,
}: let
  # Map package names to their binary names (for cases where they differ)
  binaryNameMap = {
    "rofi-wayland" = "rofi";
    "gnome-terminal" = "gnome-terminal";
    # Most packages: binary name = package name
  };

  # Check if a string is a full path (contains /)
  isFullPath = str: lib.hasInfix "/" str;

  # Resolve a single app reference (name or path) to a full executable path
  # Returns null if the app doesn't exist in nixpkgs
  resolveApp = appRef:
    if isFullPath appRef
    then
      # Already a full path - use as-is
      appRef
    else let
      # It's an app name - resolve to path
      packageName = appRef;
      binaryName = binaryNameMap.${packageName} or packageName;
    in
      # Check if package exists in nixpkgs
      if pkgs ? ${packageName}
      then "${pkgs.${packageName}}/bin/${binaryName}"
      else null;

  # Resolve a list of app references to the first available one
  # Returns the resolved path, or a default if none are available
  resolveDefault = {
    apps, # List of app names or paths
    fallback, # Default to use if none are available
  }: let
    # Try to resolve each app in order
    resolved = builtins.filter (x: x != null) (map resolveApp apps);
  in
    if resolved != []
    then builtins.head resolved # First available
    else fallback; # None available - use fallback

  # Generic function to get a default value from user config
  # Looks at config.user.default.<name> and resolves with fallback chain
  # If the config field doesn't exist, returns the default value
  getDefault = {
    config, # The full config object
    name, # The name of the default (e.g., "terminal", "launcher", "browser")
    default, # Default value to use if user hasn't configured it
  }: let
    # Try to get the user's preference list
    userPrefs = config.user.default.${name} or null;
  in
    if userPrefs == null
    then
      # User hasn't configured this default - use provided default
      default
    else
      # User has configured preferences - resolve with fallback chain
      resolveDefault {
        apps = userPrefs;
        fallback = default;
      };
in {
  inherit resolveApp resolveDefault getDefault;
}
