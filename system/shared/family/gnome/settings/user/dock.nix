# GNOME Dock Settings
#
# Purpose: Configure GNOME Shell favorites from user.workspace.docked
# Usage: Import in GNOME family settings when dock config present
# Platform: GNOME desktop environments
#
# Sets GNOME Shell favorites via dconf and creates trash.desktop
# when <trash> is specified in the docked array.
#
# Feature: 024-gnome-dock-module
# Feature: 042-fuzzy-dock-matching - Runtime fuzzy app name resolution
{
  config,
  pkgs,
  lib,
  ...
}: let
  # Import GNOME dock library
  dockLib = import ../../lib/dock.nix {inherit lib;};

  # Get user's docked configuration
  userDocked = (config.user.workspace or {}).docked or [];

  # Check if dock config exists and is non-empty
  hasDockConfig = dockLib.hasDockedItems userDocked;

  # Parse entries for trash detection
  parsedEntries = dockLib.parseDockedList userDocked;

  # Check if trash is requested
  needsTrash = dockLib.hasTrash parsedEntries;

  # Extract folder entries for .desktop file generation
  folderEntries = lib.filter (e: e.type == "folder") parsedEntries;

  # Generate .desktop file content for a folder
  makeFolderDesktop = folderPath: let
    folderName = lib.removePrefix "/" folderPath;
    # Determine icon based on common folder names
    icon =
      if folderName == "Downloads"
      then "folder-download"
      else if folderName == "Documents"
      then "folder-documents"
      else if folderName == "Pictures"
      then "folder-pictures"
      else if folderName == "Music"
      then "folder-music"
      else if folderName == "Videos"
      then "folder-videos"
      else "folder";
    # Use absolute path - ~ doesn't expand in desktop files
    fullPath = "/home/${config.user.name}/${folderName}";
  in ''
    [Desktop Entry]
    Type=Application
    Name=${folderName}
    Comment=Open ${folderName} folder
    Icon=${icon}
    Exec=nautilus ${fullPath}
    Categories=Utility;
    StartupNotify=false
  '';

  # Create desktop files for all folder entries
  folderDesktopFiles = lib.listToAttrs (map (entry: {
      name = ".local/share/applications/folder-${lib.removePrefix "/" entry.value}.desktop";
      value = {
        text = makeFolderDesktop entry.value;
      };
    })
    folderEntries);
in {
  # Create trash.desktop file when <trash> is in docked array
  # And create .desktop files for folder entries
  home.file =
    folderDesktopFiles
    // {
      ".local/share/applications/trash.desktop" = lib.mkIf needsTrash {
        text = dockLib.trashDesktopContent;
      };
    };

  # Runtime fuzzy dock matching and GNOME favorites configuration
  # This runs at activation time when desktop files are actually installed
  home.activation.gnomeFavorites = lib.mkIf hasDockConfig (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      echo "Configuring GNOME favorites with fuzzy matching..." >&2
      echo "Dock Fuzzy Matching Summary (GNOME):" >&2

      # Discover all installed .desktop files (full paths for Name= reading)
      INSTALLED_APPS=$(find ~/.nix-profile/share/applications ~/.local/share/applications /run/current-system/sw/share/applications \
        -name "*.desktop" 2>/dev/null | sort -u || echo "")

      # Build favorites list with fuzzy matching
      FAVORITES=""
      ${lib.concatMapStringsSep "\n" (
          entry: let
            parsed = dockLib.parseDockEntry entry;
          in
            if parsed.type == "app"
            then ''
              # Try fuzzy matching for: ${entry}
              BEST_MATCH=""
              BEST_SCORE=999

              # Normalize user input
              USER_INPUT=$(echo "${entry}" | tr '[:upper:]' '[:lower:]')
              USER_INPUT_NORMALIZED=$(echo "$USER_INPUT" | tr -d ' .-_')

              # Try each installed app
              while IFS= read -r desktop_path; do
                if [ -z "$desktop_path" ]; then continue; fi

                desktop_file=$(basename "$desktop_path")
                app_name="''${desktop_file%.desktop}"
                app_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')
                app_normalized=$(echo "$app_lower" | tr -d ' .-_')

                # Also read Name= field from the .desktop file (e.g. "Nix Update")
                name_field=$(grep -m1 "^Name=" "$desktop_path" 2>/dev/null | sed 's/^Name=//' | tr '[:upper:]' '[:lower:]')
                name_normalized=$(echo "$name_field" | tr -d ' .-_')

                # Strategy 1: Exact match against filename (case-insensitive)
                if [ "$app_lower" = "$USER_INPUT" ]; then
                  BEST_MATCH="$desktop_file"
                  BEST_SCORE=1
                  break
                fi

                # Strategy 1b: Exact match against Name= field
                if [ "$name_field" = "$USER_INPUT" ]; then
                  BEST_MATCH="$desktop_file"
                  BEST_SCORE=1
                  break
                fi

                # Strategy 2: Match without path/namespace (strip org.gnome., com.*, dev.*, etc.)
                app_stripped=$(echo "$app_name" | sed -E 's/^(org|com|net|io|dev)\.[^.]+\.//i')
                app_stripped_lower=$(echo "$app_stripped" | tr '[:upper:]' '[:lower:]')
                if [ "$app_stripped_lower" = "$USER_INPUT" ]; then
                  BEST_MATCH="$desktop_file"
                  BEST_SCORE=2
                  break
                fi

                # Strategy 3: Normalized match against filename (remove all special chars)
                if [ "$app_normalized" = "$USER_INPUT_NORMALIZED" ]; then
                  if [ $BEST_SCORE -gt 3 ]; then
                    BEST_MATCH="$desktop_file"
                    BEST_SCORE=3
                  fi
                fi

                # Strategy 3b: Normalized match against Name= field
                # e.g., "nix update" matches Name=Nix Update → nixupdate
                if [ -n "$name_normalized" ] && [ "$name_normalized" = "$USER_INPUT_NORMALIZED" ]; then
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

                # Strategy 5: CamelCase word match (split CamelCase into words)
                # e.g., "system monitor" matches "SystemMonitor" or "org.gnome.SystemMonitor"
                # First strip namespace, then convert CamelCase to space-separated words
                app_no_namespace=$(echo "$app_name" | sed -E 's/^(org|com|net|io|dev)\.[^.]+\.//i')
                app_words=$(echo "$app_no_namespace" | sed 's/\([A-Z]\)/ \1/g' | tr '[:upper:]' '[:lower:]' | sed 's/^ //; s/  */ /g')
                if [ "$app_words" = "$USER_INPUT" ]; then
                  if [ $BEST_SCORE -gt 5 ]; then
                    BEST_MATCH="$desktop_file"
                    BEST_SCORE=5
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
              # Folders get custom .desktop files: folder-Downloads.desktop
              FOLDER_NAME=$(echo "${entry}" | sed 's|^/||')
              FOLDER_DESKTOP="folder-$FOLDER_NAME.desktop"
              FAVORITES="$FAVORITES'$FOLDER_DESKTOP', "
              echo "  ${entry} → $FOLDER_DESKTOP [folder]" >&2
            ''
            else ""
        )
        userDocked}

      # Remove trailing comma and space
      FAVORITES=''${FAVORITES%, }

      # Set GNOME favorites using dconf
      if [ -n "$FAVORITES" ]; then
        ${pkgs.dconf}/bin/dconf write /org/gnome/shell/favorite-apps "[$FAVORITES]"
        echo "GNOME favorites configured successfully" >&2
      else
        echo "No favorites to configure" >&2
      fi
    ''
  );
}
