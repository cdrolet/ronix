{
  config,
  lib,
  pkgs,
  ...
}: {
  # Application-Specific Settings
  #
  # Purpose: Configure application-specific defaults using CustomUserPreferences
  # Note: Settings that affect specific applications belong here, not in input mechanism modules
  #
  # Examples:
  #   # Enable Safari developer menu
  #   system.defaults.CustomUserPreferences."com.apple.Safari" = {
  #     IncludeDevelopMenu = true;
  #   };

  system.defaults.CustomUserPreferences = {
    "com.apple.Safari" = {
      # Enable develop menu
      IncludeDevelopMenu = lib.mkDefault true;
      # Enable debug menu
      IncludeInternalDebugMenu = lib.mkDefault true;
      # Show full URL in address bar
      ShowFullURLInSmartSearchField = lib.mkDefault true;
      # Disable AutoFill
      AutoFillFromAddressBook = lib.mkDefault false;
      AutoFillPasswords = lib.mkDefault false;
      AutoFillCreditCardData = lib.mkDefault false;
      AutoFillMiscellaneousForms = lib.mkDefault false;
      # Privacy settings
      SendDoNotTrackHTTPHeader = lib.mkDefault true;

      # Additional Safari settings
      # Enable WebKit developer extras
      WebKitDeveloperExtrasEnabledPreferenceKey = lib.mkDefault true;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = lib.mkDefault true;
      # Disable thumbnail cache for History and Top Sites
      DebugSnapshotsUpdatePolicy = lib.mkDefault 2;
      # Search: Contains instead of Starts With
      FindOnPageMatchesWordStartsOnly = lib.mkDefault false;
      # Home page to about:blank
      HomePage = lib.mkDefault "about:blank";
      # Prevent auto-opening safe files
      AutoOpenSafeDownloads = lib.mkDefault false;
      # Allow backspace key to go back
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" = lib.mkDefault true;
      # Hide favorites bar by default
      ShowFavoritesBar = lib.mkDefault false;
      # Hide sidebar in Top Sites
      ShowSidebarInTopSites = lib.mkDefault false;
    };

    "com.apple.ActivityMonitor" = {
      # Show all processes (value 100)
      ShowCategory = lib.mkDefault 100;
      # Sort by CPU usage
      SortColumn = lib.mkDefault "CPUUsage";
      SortDirection = lib.mkDefault 0;
      # Refresh frequency every 2 seconds
      UpdatePeriod = lib.mkDefault 2;
    };

    "com.apple.TextEdit" = {
      # Use plain text mode
      RichText = lib.mkDefault false;
      # Plain text font
      PlainTextEncoding = lib.mkDefault 4;
      PlainTextEncodingForWrite = lib.mkDefault 4;
    };

    "com.apple.DiskUtility" = {
      # Enable debug menu
      DUDebugMenuEnabled = lib.mkDefault true;
      # Show all devices
      advanced-image-options = lib.mkDefault true;
    };

    # Disk Image preferences
    "com.apple.frameworks.diskimages" = {
      # Disable disk image verification
      skip-verify = lib.mkDefault true;
      skip-verify-locked = lib.mkDefault true;
      skip-verify-remote = lib.mkDefault true;
      # Auto-open mounted volumes
      auto-open-ro-root = lib.mkDefault true;
      auto-open-rw-root = lib.mkDefault true;
    };

    # Messages settings
    "com.apple.messageshelper.MessageController" = {
      SOInputLineSettings = lib.mkDefault {
        # Disable automatic emoji substitution
        automaticEmojiSubstitutionEnablediMessage = false;
        # Disable smart quotes
        automaticQuoteSubstitutionEnabled = false;
      };
    };

    "com.apple.mail" = {
      # Copy email addresses without names
      AddressesIncludeNameOnPasteboard = lib.mkDefault false;
      # Disable inline attachments
      DisableInlineAttachmentViewing = lib.mkDefault true;

      # Additional Mail settings
      # Disable animations
      DisableReplyAnimations = lib.mkDefault true;
      DisableSendAnimations = lib.mkDefault true;
      # Keyboard shortcut Cmd+Enter to send
      NSUserKeyEquivalents = lib.mkDefault {
        Send = "@\\U21a9";
      };
      # Display emails in threaded mode, sorted by date
      DraftsViewerAttributes = lib.mkDefault {
        DisplayInThreadedMode = "yes";
        SortedDescending = "yes";
        SortOrder = "received-date";
      };
      # Disable automatic spell checking
      SpellCheckingBehavior = lib.mkDefault "NoSpellCheckingEnabled";
    };

    "com.apple.TimeMachine" = {
      # Prevent prompting to use new hard drives as backup volume
      DoNotOfferNewDisksForBackup = lib.mkDefault true;
    };

    "com.apple.appstore" = {
      # Enable Debug Menu
      ShowDebugMenu = lib.mkDefault true;
    };

    "com.apple.commerce" = {
      # Disable video autoplay in App Store
      AutoPlayVideoSetting = lib.mkDefault 0;
    };

    "com.apple.SoftwareUpdate" = {
      # Enable automatic update check
      AutomaticCheckEnabled = lib.mkDefault true;
      # Check for updates daily
      ScheduleFrequency = lib.mkDefault 1;
      # Download newly available updates in background
      AutomaticDownload = lib.mkDefault 1;
      # Install app updates from App Store
      ConfigDataInstall = lib.mkDefault 1;
      # Install macOS updates
      CriticalUpdateInstall = lib.mkDefault 1;
    };

    "com.apple.print.PrintingPrefs" = {
      # Quit printer app when print jobs complete
      "Quit When Finished" = lib.mkDefault true;
    };

    # Siri settings
    "com.apple.siri" = {
      # Disable Siri
      EnableAskSiri = lib.mkDefault false;
      # Hide Siri from menu bar
      StatusMenuVisible = lib.mkDefault false;
    };

    # Terminal settings
    "com.apple.Terminal" = {
      # UTF-8 encoding only
      StringEncodings = lib.mkDefault [4];
      # Focus follows mouse
      FocusFollowsMouse = lib.mkDefault true;
      # Disable resume
      NSQuitAlwaysKeepsWindows = lib.mkDefault false;
    };

    # System Preferences
    "com.apple.systempreferences" = {
      # Disable resume
      NSQuitAlwaysKeepsWindows = lib.mkDefault false;
    };

    # Calculator settings
    "com.apple.calculator" = {
      ViewDefaultsKey = lib.mkDefault "Programmer";
      # Base 10
      CalculatorBase = lib.mkDefault 10;
      # Show thousands separator
      SeparatorsDefaultsKey = lib.mkDefault true;
    };

    # Help Viewer
    "com.apple.helpviewer" = {
      # Enable developer mode
      DevMode = lib.mkDefault true;
    };

    # Note: com.apple.addressbook and com.apple.iCal debug menus removed —
    # their preference domains don't exist on fresh macOS installs, causing
    # "Could not write domain" errors during activation.
  };
}
