{
  config,
  lib,
  pkgs,
  ...
}: {
  # UI and Visual Settings
  #
  # Purpose: Configure visual effects, animations, menu bar, scrollbars, and appearance
  #
  # Options:
  #   - AppleInterfaceStyle: Light or Dark mode
  #   - AppleShowScrollBars: When to show scrollbars (Automatic, Always, WhenScrolling)
  #   - NSNavPanelExpandedStateForSaveMode: Expand save dialogs by default
  #   - PMPrintingExpandedStateForPrint: Expand print dialogs by default
  #
  # Examples:
  #   # Enable dark mode and always show scrollbars
  #   system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark";
  #   system.defaults.NSGlobalDomain.AppleShowScrollBars = "Always";

  system.defaults.NSGlobalDomain = {
    # Dark mode
    AppleInterfaceStyle = lib.mkDefault "Dark";

    # Scrollbar visibility
    AppleShowScrollBars = lib.mkDefault "Always";

    # Visual effects
    NSAutomaticWindowAnimationsEnabled = lib.mkDefault false; # Disable window animations
    NSWindowResizeTime = lib.mkDefault 0.001; # Fast window resize

    # Expand save and print panels by default
    NSNavPanelExpandedStateForSaveMode = lib.mkDefault true;
    NSNavPanelExpandedStateForSaveMode2 = lib.mkDefault true;
    PMPrintingExpandedStateForPrint = lib.mkDefault true;
    PMPrintingExpandedStateForPrint2 = lib.mkDefault true;

    # Window behavior
    NSDocumentSaveNewDocumentsToCloud = lib.mkDefault false; # Save to disk not iCloud

    # Additional UI settings
    # Set sidebar icon size to medium
    NSTableViewDefaultSizeMode = lib.mkDefault 2;
  };

  # Additional UI preferences via CustomUserPreferences
  system.defaults.CustomUserPreferences = {
    # Universal Access / Accessibility
    "com.apple.universalaccess" = {
      reduceMotion = lib.mkDefault 1; # Reduce motion animations
    };

    # NSGlobalDomain settings via CustomUserPreferences
    # Note: use "NSGlobalDomain" not "Apple Global Domain" — nix-darwin doesn't
    # shell-escape the domain, so spaces break the defaults command.
    NSGlobalDomain = {
      # Scrolling behavior
      "com.apple.swipescrolldirection" = lib.mkDefault 0; # Disable natural scrolling
      # Set highlight color to green
      AppleHighlightColor = lib.mkDefault "0.764700 0.976500 0.568600";
      # Disable menu bar transparency (deprecated setting)
      AppleEnableMenuBarTransparency = lib.mkDefault false;
    };
  };
}
