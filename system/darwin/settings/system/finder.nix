{
  config,
  lib,
  pkgs,
  ...
}: {
  # Finder Settings
  #
  # Purpose: Configure macOS Finder windows, views, and behavior
  #
  # Options:
  #   - AppleShowAllExtensions: Show all file extensions
  #   - AppleShowAllFiles: Show hidden files
  #   - FXEnableExtensionChangeWarning: Warn when changing file extensions
  #   - FXPreferredViewStyle: Default view style (Nlsv=list, icnv=icon, clmv=column, Flwv=gallery)
  #   - ShowPathbar: Show path bar at bottom
  #   - ShowStatusBar: Show status bar at bottom
  #   - _FXShowPosixPathInTitle: Show full POSIX path in title bar
  #
  # Examples:
  #   # Show all extensions and path bar
  #   system.defaults.finder.AppleShowAllExtensions = true;
  #   system.defaults.finder.ShowPathbar = true;

  system.defaults.finder = {
    # File visibility
    AppleShowAllExtensions = lib.mkDefault true;
    AppleShowAllFiles = lib.mkDefault true; # Show all files including hidden
    FXEnableExtensionChangeWarning = lib.mkDefault false;

    # View settings
    FXPreferredViewStyle = lib.mkDefault "Nlsv"; # List view
    ShowPathbar = lib.mkDefault true;
    ShowStatusBar = lib.mkDefault true;
    _FXShowPosixPathInTitle = lib.mkDefault true;

    # Behavior settings
    QuitMenuItem = lib.mkDefault true; # Allow quitting Finder with Cmd+Q
  };

  # Finder-specific CustomUserPreferences
  system.defaults.CustomUserPreferences."com.apple.finder" = {
    # Search and navigation
    FXDefaultSearchScope = lib.mkDefault "SCcf"; # Search current folder by default
    _FXSortFoldersFirst = lib.mkDefault true; # Sort folders before files

    # Animation settings
    DisableAllAnimations = lib.mkDefault true; # Disable Finder animations

    # Desktop icon visibility
    ShowExternalHardDrivesOnDesktop = lib.mkDefault false;
    ShowHardDrivesOnDesktop = lib.mkDefault false;
    ShowMountedServersOnDesktop = lib.mkDefault false;
    ShowRemovableMediaOnDesktop = lib.mkDefault false;

    # Additional Finder settings
    # Allow text selection in Quick Look
    QLEnableTextSelection = lib.mkDefault true;
    # Disable warning when changing file extension (already in standard options above)
    # Disable warning when emptying trash
    WarnOnEmptyTrash = lib.mkDefault false;
    # Auto-open window for new removable disk
    OpenWindowForNewRemovableDisk = lib.mkDefault true;
    # Expand File Info panes
    FXInfoPanesExpanded = lib.mkDefault {
      General = true;
      OpenWith = true;
      Privileges = true;
    };
  };

  # Desktop services (related to Finder)
  system.defaults.CustomUserPreferences."com.apple.desktopservices" = {
    # Disable .DS_Store on network volumes
    DSDontWriteNetworkStores = lib.mkDefault true;
    # Disable .DS_Store on USB volumes
    DSDontWriteUSBStores = lib.mkDefault true;
  };
}
