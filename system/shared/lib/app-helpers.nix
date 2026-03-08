# Application Helper Functions
#
# Purpose: Shared utility functions for application modules
# Usage: Import this in app modules that need dependency checking
#
# Example:
#   let
#     appHelpers = import ../../../shared/lib/app-helpers.nix { inherit lib; };
#   in {
#     warnings = lib.optional (!appHelpers.hasApp config "uv") ''
#       spec-kit requires 'uv' to be installed.
#     '';
#   }
{lib}: {
  # Check if an app is in the user's application list
  # Handles wildcards: "*" (all apps) and "category/*" (all apps in category)
  #
  # Type: hasApp :: Config -> String -> Bool
  # Args:
  #   config: The module config object
  #   appName: The app name to check for (e.g., "uv", "git", "kubectl")
  #
  # Returns: true if the app is in user.workspace.applications (directly or via wildcard)
  #
  # Examples:
  #   hasApp config "uv"  # true if "uv", "dev/*", or "*" in applications
  #   hasApp config "git" # true if "git", "dev/*", or "*" in applications
  hasApp = config: appName: let
    applications = (config.user.workspace or {}).applications or [];

    # Check for exact match
    hasExact = lib.elem appName applications;

    # Check for wildcard "*"
    hasWildcard = lib.elem "*" applications;

    # Check for category wildcard (e.g., "dev/*")
    # We need to determine the category from the app's file path
    # Since we don't have that context here, we'll check all possible category wildcards
    # This is a conservative check - if ANY category wildcard exists, we assume it might match
    categoryWildcards = lib.filter (app: lib.hasSuffix "/*" app) applications;
    hasCategoryWildcard = categoryWildcards != [];
  in
    hasExact || hasWildcard || hasCategoryWildcard;

  # More precise category wildcard check if you know the app's category
  # Type: hasAppInCategory :: Config -> String -> String -> Bool
  # Args:
  #   config: The module config object
  #   category: The category name (e.g., "dev", "cli", "security")
  #   appName: The app name to check for
  #
  # Returns: true if the app is in applications via exact match, category wildcard, or global wildcard
  #
  # Example:
  #   hasAppInCategory config "dev" "uv"  # true if "uv", "dev/*", or "*" in applications
  hasAppInCategory = config: category: appName: let
    applications = (config.user.workspace or {}).applications or [];
    hasExact = lib.elem appName applications;
    hasWildcard = lib.elem "*" applications;
    hasCategoryWildcard = lib.elem "${category}/*" applications;
  in
    hasExact || hasWildcard || hasCategoryWildcard;
}
