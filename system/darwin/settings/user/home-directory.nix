# Darwin Settings: Home Directory Configuration
#
# Purpose: Set platform-specific home directory path for macOS
# Platform: Darwin (macOS) only
#
# macOS uses /Users/{username} for home directories
{
  config,
  lib,
  ...
}: {
  # Darwin home directory path
  home.homeDirectory = lib.mkDefault "/Users/${config.user.name}";

  # Unhide ~/Library folder in Finder
  # Makes Library folder visible for easier access to app data
  # Operation is idempotent - safe to run on every activation
  home.activation.unhideLibrary = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if chflags nohidden ~/Library 2>/dev/null; then
      if [[ -v VERBOSE ]]; then
        echo "Unhidden ~/Library folder"
      fi
    fi
  '';
}
