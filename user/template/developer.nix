{...}: {
  # User: {{USERNAME}}
  # Template: developer
  # Development-focused configuration with comprehensive tooling

  user = {
    name = "{{USERNAME}}";
    email = "{{EMAIL}}";
    fullname = "{{FULLNAME}}";

    # Security configuration (passwords, SSH keys, credentials)
    security = {
      password = "<secret>";
    };

    # Locale configuration (Feature: 018-user-locale-config)
    locale = {
      languages = ["en-CA"];
      keyboard = {
        layout = ["canadian-english" "canadian-french"];
        macStyleMappings = true;
      };
      timezone = "America/Toronto";
      format = "en_CA.UTF-8";
    };

    # Workspace configuration (applications, dock, repositories)
    workspace = {
      # Applications - comprehensive developer toolset
      applications = [
        "*"
      ];

      # Browser bookmarks — shared across librewolf, firefox, and brave
      # Supports individual bookmarks, nested folders, and separators
      # bookmarks = [
      #   { name = "NixOS"; url = "https://nixos.org"; tags = ["nix"]; }
      #   "separator"
      #   {
      #     name = "Dev";
      #     toolbar = true;   # Firefox/LibreWolf: pin folder to bookmark toolbar
      #     bookmarks = [
      #       { name = "GitHub"; url = "https://github.com"; }
      #       { name = "NixPkgs"; url = "https://search.nixos.org/packages"; }
      #     ];
      #   }
      # ];

      # Dock configuration (Feature: 023-user-dock-config)
      # Development-focused layout
      docked = [
        # Main applications
        "calculator"
        "gnome-calculator"
        "zen"
        "brave"
        "maps"
        "gnome-maps"
        "proton mail"
        "geary"
        "bitwarden"
        "qobuz"
        "|"
        # Development
        "zed"
        "ghostty"
        "obsidian"
        "utm"
        "|"
        # System
        "system settings"
        "gnome-control-center"
        "activity monitor"
        "print center"
        "gnome-print-center"
        "||"
        # Folders
        "/Downloads"
      ];
    };

    # Backup configuration (restic + Backblaze B2)
    # Requires: just secrets-set <user> backup.repository.keyId          "004..."
    #           just secrets-set <user> backup.repository.applicationKey "..."
    #           just secrets-set <user> backup.repository.password       "strong passphrase"
    # backup = {
    #   repository = {
    #     bucket   = "my-bucket-name";                   # B2 bucket name (not bucket ID)
    #     endpoint = "s3.ca-east-006.backblazeb2.com";   # B2 S3-compatible endpoint
    #     keyId          = "<secret>";                   # applicationKeyId (starts with 004)
    #     applicationKey = "<secret>";                   # application key secret
    #     password       = "<secret>";                   # restic encryption passphrase
    #   };
    #   schedule = "daily";    # "daily" or "weekly"
    #   retain = {
    #     daily   = 7;         # keep last 7 daily snapshots
    #     weekly  = 4;         # keep last 4 weekly snapshots
    #     monthly = 6;         # keep last 6 monthly snapshots
    #   };
    #   paths   = [];          # extra paths beyond defaults
    #   exclude = [];          # extra exclude patterns beyond defaults
    # };

    # Style configuration (fonts, theme, wallpaper)
    style = {
      fonts = {
        defaults = {
          monospace = {
            families = ["Berkeley Mono" "Fira Code"];
            size = 12;
          };
          sansSerif = {
            families = ["URW Classico" "Inter"];
            size = 10;
          };
          serif = {
            families = ["Libre Baskerville" "Georgia"];
          };
          emoji = {
            families = ["Noto Color Emoji"];
          };
        };
      };

      # Theme configuration — sets color scheme via stylix
      # All fields are optional; omit the entire block to keep defaults
      theme = {
        # Base16 scheme name (case-insensitive, spaces become dashes)
        # Examples: "Nord", "Catppuccin Mocha", "solarized-dark", "gruvbox-dark-hard"
        name = "Nord";

        # Polarity: "dark", "light", or "either" (auto-detect from scheme)
        polarity = "dark";

        # Color configuration
        # color = {
        #   # Extract palette from wallpaper image (ignores theme.name)
        #   fromWallpaper = true;
        #
        #   # Override individual colors — base16 names (base00-base0F) or aliases:
        #   #   background, foreground, black, white, red, orange, yellow,
        #   #   green, cyan, blue, purple, magenta, brown
        #   # Hex values with or without # prefix
        #   overrides = {
        #     background = "#2e3440";
        #     red = "#bf616a";
        #     base02 = "#4c566a";
        #   };
        # };

        # Opacity levels (0.0 = transparent, 1.0 = opaque)
        # opacity = {
        #   applications = 1.0;  # general app windows
        #   terminal = 0.9;      # terminal emulators (ghostty, kitty, etc.)
        #   desktop = 1.0;       # panels, bars (waybar); 0.0 = fully transparent
        #   popups = 1.0;        # notifications and popups
        # };
      };

      # Cursor theme (all fields required when set)
      # cursor = {
      #   package = "bibata-cursors";    # nixpkgs attribute name
      #   name = "Bibata-Modern-Ice";    # theme name in share/icons/
      #   size = 24;                     # cursor size in pixels
      # };

      # Wallpaper configuration — sets desktop background
      # All fields optional. Priority: generate > remote > path
      # wallpaper = {
      #   path = "~/Pictures/wallpaper.jpg";     # local file (supports ~/)
      #   scaleMode = "fill";                     # stretch, fill, fit, center, tile
      #
      #   # Cycling frequency (Linux/Wayland only)
      #   # Requires a wallpapers/ folder alongside this file (user/<name>/wallpapers/)
      #   # wpaperd cycles through ~/Pictures/wallpapers/ synced from that folder
      #   # cyclingFrequency = "daily";   # on-login | every-5min | every-30min | hourly | daily
      #
      #   # Fetch from URL (requires SRI hash for reproducibility)
      #   # remote = {
      #   #   url = "https://unsplash.com/photos/abc/download";
      #   #   hash = "sha256-abc...";
      #   # };
      #
      #   # Generate wallpaper from theme colors
      #   # generate = {
      #   #   color = "base00";       # solid color (aliases: background, red, etc.)
      #   #   pattern = "gradient";   # gradient from base16 background colors
      #   #   brightness = 0.8;       # dim/brighten image (0.0-2.0, 1.0 = unchanged)
      #   # };
      # };
    };
  };
}
