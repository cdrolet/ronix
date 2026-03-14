# GNOME App Grid Folders
#
# Purpose: Organise the GNOME app launcher into category folders.
#
# Games     ← Categories: Game
# System    ← Categories: System, Monitor, Settings
# Utilities ← Categories: Utility
#
# The activation script resets /org/gnome/desktop/app-folders/ before each
# activation so stale keys from prior runs never accumulate in dconf.
#
# Platform: GNOME (dconf, home-manager)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Reset app-folders dconf namespace before home-manager writes its values.
  # Without this, old keys (e.g. leftover `apps` or `categories` from a prior
  # activation) persist and conflict with the current config.
  home.activation.resetGnomeAppFolders = lib.hm.dag.entryBefore ["dconfSettings"] ''
    ${pkgs.dconf}/bin/dconf reset -f /org/gnome/desktop/app-folders/
  '';

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
