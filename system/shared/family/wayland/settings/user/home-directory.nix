# Linux Family Settings: Home Directory and XDG Configuration
#
# Purpose: Configure home directory and XDG base directories for Linux systems
# Platform: Linux family (NixOS, Kali, Ubuntu, etc.)
#
# Linux systems:
# - Use /home/{username} for home directories
# - Follow XDG Base Directory Specification for config/data/cache directories
{
  config,
  lib,
  ...
}: {
  # This module is in settings/user/ so it's ONLY imported in home-manager context
  # No need for context guards per Feature 039

  # Linux home directory path
  home.homeDirectory = lib.mkDefault "/home/${config.user.name}";

  # Enable XDG Base Directory Specification
  # Defines standard directories:
  # - XDG_CONFIG_HOME: ~/.config (user configuration files)
  # - XDG_DATA_HOME: ~/.local/share (user data files)
  # - XDG_CACHE_HOME: ~/.cache (user cache files)
  # - XDG_STATE_HOME: ~/.local/state (user state files)
  xdg.enable = lib.mkDefault true;

  # Create XDG user directories (Downloads, Documents, etc.)
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
    templates = "${config.home.homeDirectory}/Templates";
    publicShare = "${config.home.homeDirectory}/Public";
  };
}
