# GNOME App Grid Folders
#
# Purpose: Organise the GNOME app launcher into category folders.
#          Uses the Categories= field from .desktop files — any app whose
#          desktop file declares a matching category is placed automatically.
#
# Folders:
#   Games     ← Category: Game
#   System    ← Category: System, Monitor, Settings
#   Utilities ← Category: Utility
#
# Platform: GNOME (dconf, home-manager)
{lib, ...}: {
  dconf.settings = {
    "org/gnome/desktop/app-folders" = {
      folder-children = lib.mkDefault ["Games" "System" "Utilities"];
    };

    "org/gnome/desktop/app-folders/folders/Games" = {
      name = lib.mkDefault "Games";
      categories = lib.mkDefault ["Game"];
      translate = lib.mkDefault false;
    };

    "org/gnome/desktop/app-folders/folders/System" = {
      name = lib.mkDefault "System";
      categories = lib.mkDefault ["System" "Monitor" "Settings"];
      translate = lib.mkDefault false;
    };

    "org/gnome/desktop/app-folders/folders/Utilities" = {
      name = lib.mkDefault "Utilities";
      categories = lib.mkDefault ["Utility"];
      translate = lib.mkDefault false;
    };
  };
}
