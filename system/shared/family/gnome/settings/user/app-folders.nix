# GNOME App Grid Folders
#
# Purpose: Organise the GNOME app launcher into category folders.
#
# Games    — explicit app IDs (mirrors gnome-games.nix package list)
# System   — category-based: System, Monitor, Settings desktop categories
# Utilities— category-based: Utility desktop category
#
# Note: games use explicit IDs because category matching only applies to apps
# already visible in the GNOME Shell grid. A full session restart (logout/login)
# is required after install for newly added apps to appear.
#
# Platform: GNOME (dconf, home-manager)
{lib, ...}: {
  dconf.settings = {
    "org/gnome/desktop/app-folders" = {
      folder-children = lib.mkDefault ["Games" "System" "Utilities"];
    };

    # Games: explicit IDs matching the gnome-games.nix package list.
    # Desktop file IDs correspond to ~/.nix-profile/share/applications/.
    "org/gnome/desktop/app-folders/folders/Games" = {
      name = lib.mkDefault "Games";
      apps = lib.mkDefault [
        "sol.desktop"                      # aisleriot — solitaire
        "org.gnome.Chess.desktop"
        "org.gnome.Mahjongg.desktop"
        "org.gnome.Mines.desktop"
        "org.gnome.Sudoku.desktop"
        "org.gnome.Quadrapassel.desktop"
        "org.gnome.Tetravex.desktop"
        "org.gnome.five-or-more.desktop"
        "org.gnome.Four-in-a-row.desktop"
        "org.gnome.Klotski.desktop"
        "org.gnome.Nibbles.desktop"
        "org.gnome.Hitori.desktop"
        "org.gnome.Lightsoff.desktop"
        "org.gnome.SwellFoop.desktop"
        "org.gnome.Tali.desktop"
        "atomix.desktop"
        "org.gnome.Robots.desktop"
      ];
    };

    # System: category-based — catches btop, dconf-editor, system monitor, etc.
    "org/gnome/desktop/app-folders/folders/System" = {
      name = lib.mkDefault "System";
      categories = lib.mkDefault ["System" "Monitor" "Settings"];
      translate = lib.mkDefault false;
    };

    # Utilities: category-based — catches calculator, text editor, files, etc.
    "org/gnome/desktop/app-folders/folders/Utilities" = {
      name = lib.mkDefault "Utilities";
      categories = lib.mkDefault ["Utility"];
      translate = lib.mkDefault false;
    };
  };
}
