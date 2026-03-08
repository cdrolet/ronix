# GNOME Family: Nautilus File Manager Settings
#
# Purpose: Configure Nautilus (GNOME Files) preferences
# Platform: GNOME family (user-level)
#
# Settings include:
# - Show hidden files by default
# - List view as default
# - Sidebar bookmarks (Downloads, project)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ============================================================================
  # Nautilus Preferences
  # ============================================================================

  dconf.settings = {
    # File manager preferences
    "org/gnome/nautilus/preferences" = {
      # Show hidden files by default
      show-hidden-files = true;

      # Default view (list-view or icon-view)
      default-folder-viewer = "list-view";

      # Sort directories before files
      default-sort-order = "name";
      default-sort-in-reverse-order = false;
    };

    # List view preferences
    "org/gnome/nautilus/list-view" = {
      # Show file type column
      default-visible-columns = ["name" "size" "type" "date_modified"];

      # Use tree view in list mode
      use-tree-view = false;

      # Icon zoom level for list view (small, standard, large, larger)
      default-zoom-level = "small";
    };

    # Icon view preferences (when user switches to icon view)
    "org/gnome/nautilus/icon-view" = {
      # Icon zoom level (small, standard, large, larger, largest)
      default-zoom-level = "standard";
    };
  };

  # ============================================================================
  # Sidebar Bookmarks
  # ============================================================================

  # GTK bookmarks file for sidebar shortcuts
  # Format: file:///absolute/path/to/directory Optional Name
  # Note: Must use absolute paths (not ~), one bookmark per line
  gtk.gtk3.bookmarks = [
    "file:///home/${config.user.name}/Downloads"
    "file:///home/${config.user.name}/project"
  ];
}
