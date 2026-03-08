# GNOME Dock Library
#
# Purpose: GNOME-specific dock configuration utilities
# Usage: Imported by GNOME settings/dock.nix to configure favorites
# Platform: GNOME desktop environments (NixOS, etc.)
#
# This library provides functions for:
# - Resolving app names to .desktop file names
# - Filtering dock entries to GNOME-supported items
# - Generating the favorites array for dconf
#
# Feature: 024-gnome-dock-module
# Feature: 042-fuzzy-dock-matching - Fuzzy app name resolution
{lib}: let
  # Import shared dock parsing library
  sharedDock = import ../../../lib/dock.nix {inherit lib;};

  # Import fuzzy matcher
  fuzzyMatcher = import ../../../../lib/fuzzy-dock-matcher.nix {inherit lib;};

  # XDG application directories in search priority order
  # Note: These are evaluated at activation time, not build time
  xdgAppDirs = [
    "~/.local/share/applications"
    "/run/current-system/sw/share/applications"
    "/usr/share/applications"
  ];

  # Check if an entry is supported on GNOME
  # Only apps and trash system item are supported
  isGnomeSupported = entry:
    entry.type == "app" || (entry.type == "system" && entry.value == "trash");

  # Check if parsed entries contain trash
  hasTrash = entries:
    lib.any (e: e.type == "system" && e.value == "trash") entries;

  # Generate .desktop filename for an app (simple fallback - no fuzzy matching)
  toDesktopName = entry:
    if entry.type == "app"
    then "${entry.value}.desktop"
    else if entry.type == "system" && entry.value == "trash"
    then "trash.desktop"
    else null;

  # Filter entries to GNOME-supported items only
  filterForGnome = entries: lib.filter isGnomeSupported entries;

  # Generate shell script to discover installed desktop files and build favorites list
  # This runs at activation time when desktop files actually exist
  mkRuntimeFavoritesScript = {
    dockedList,
    userDocked,
  }: ''
    # Discover all installed .desktop files
    INSTALLED_APPS=$(find ~/.local/share/applications /run/current-system/sw/share/applications \
      -name "*.desktop" 2>/dev/null | xargs -n1 basename 2>/dev/null | sort -u || echo "")

    # Build favorites list with fuzzy matching
    FAVORITES=""
    ${lib.concatMapStringsSep "\n" (
        entry: let
          parsed = sharedDock.parseDockEntry entry;
        in
          if parsed.type == "app"
          then ''
            # Try fuzzy matching for: ${entry}
            BEST_MATCH=""
            BEST_SCORE=999

            # Normalize user input
            USER_INPUT="${lib.toLower entry}"
            USER_INPUT_NORMALIZED=$(echo "$USER_INPUT" | tr -d ' .-_')

            # Try each installed app
            while IFS= read -r desktop_file; do
              if [ -z "$desktop_file" ]; then continue; fi

              app_name="''${desktop_file%.desktop}"
              app_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')
              app_normalized=$(echo "$app_lower" | tr -d ' .-_')

              # Strategy 1: Exact match (case-insensitive)
              if [ "$app_lower" = "$USER_INPUT" ]; then
                BEST_MATCH="$desktop_file"
                BEST_SCORE=1
                break
              fi

              # Strategy 2: Match without path/namespace (strip org.gnome., com.*, etc.)
              app_stripped=$(echo "$app_name" | sed -E 's/^(org|com|net|io)\.[^.]+\.//i')
              app_stripped_lower=$(echo "$app_stripped" | tr '[:upper:]' '[:lower:]')
              if [ "$app_stripped_lower" = "$USER_INPUT" ]; then
                BEST_MATCH="$desktop_file"
                BEST_SCORE=2
                break
              fi

              # Strategy 3: Normalized match (remove all special chars)
              if [ "$app_normalized" = "$USER_INPUT_NORMALIZED" ]; then
                if [ $BEST_SCORE -gt 3 ]; then
                  BEST_MATCH="$desktop_file"
                  BEST_SCORE=3
                fi
              fi

              # Strategy 4: Word match (user input is a word in app name)
              if echo "$app_lower" | grep -qw "$USER_INPUT"; then
                if [ $BEST_SCORE -gt 4 ]; then
                  BEST_MATCH="$desktop_file"
                  BEST_SCORE=4
                fi
              fi
            done <<< "$INSTALLED_APPS"

            if [ -n "$BEST_MATCH" ]; then
              FAVORITES="$FAVORITES'$BEST_MATCH', "
              echo "  ${entry} → $BEST_MATCH [score:$BEST_SCORE]" >&2
            else
              echo "  ${entry} → SKIPPED [no match]" >&2
            fi
          ''
          else if parsed.type == "system" && parsed.value == "trash"
          then ''
            FAVORITES="$FAVORITES'trash.desktop', "
            echo "  <trash> → trash.desktop [passthrough]" >&2
          ''
          else if parsed.type == "separator"
          then ''
            echo "  ${entry} → [separator - filtered]" >&2
          ''
          else if parsed.type == "folder"
          then ''
            echo "  ${entry} → [folder - filtered]" >&2
          ''
          else ""
      )
      userDocked}

    # Remove trailing comma and space
    FAVORITES=''${FAVORITES%, }

    # Set GNOME favorites
    if [ -n "$FAVORITES" ]; then
      gsettings set org.gnome.shell favorite-apps "[$FAVORITES]"
      echo "GNOME favorites configured successfully" >&2
    else
      echo "No favorites to configure" >&2
    fi
  '';

  # Trash desktop file content
  trashDesktopContent = ''
    [Desktop Entry]
    Type=Application
    Name=Trash
    Comment=View deleted files
    Icon=user-trash-full
    Exec=nautilus trash://
    Categories=Utility;
    StartupNotify=true
  '';
in {
  # Re-export shared library functions
  inherit (sharedDock) parseDockEntry parseDockedList hasDockedItems;

  # GNOME-specific functions
  inherit
    isGnomeSupported
    hasTrash
    filterForGnome
    mkRuntimeFavoritesScript
    trashDesktopContent
    xdgAppDirs
    ;
}
