# Helper Library: Home Manager Bootstrap Module
#
# Purpose: Provide standard Home Manager initialization for all users
# Usage: Automatically imported by platform libs (darwin.nix, nixos.nix, etc.)
# Platform: Cross-platform (macOS, Linux)
#
# This module provides options for user configuration and sets up
# Home Manager defaults declaratively. It is automatically included
# by the platform libraries - users do not need to import it.
#
# Feature 027: User schema with freeformType for extensibility
# Core fields are documented with proper types, but arbitrary fields
# can be added without schema changes (e.g., user.tokens.github = "<secret>")
#
# Example user config (pure data):
#   { ... }:
#   {
#     user = {
#       name = "username";
#       email = "user@example.com";        # or "<secret>" for encrypted
#       fullName = "Full Name";            # or "<secret>" for encrypted
#       security.password = "<secret>";
#       locale = {
#         languages = ["en-CA"];
#         keyboard.layout = ["canadian-english"];
#         timezone = "America/Toronto";
#         format = "en_CA.UTF-8";
#       };
#       workspace = {
#         applications = [ "git" "zsh" ];
#         docked = [ "zen" "|" "ghostty" "/Downloads" ];
#       };
#       style = {
#         fonts.defaults.monospace = { families = ["Fira Code"]; size = 12; };
#         theme = { name = "Nord"; polarity = "dark"; };
#         wallpaper = { path = "~/Pictures/bg.jpg"; scaleMode = "fill"; };
#       };
#       tokens.github = "<secret>";        # Freeform field (no schema change needed)
#     };
#   }
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.user = lib.mkOption {
    type = lib.types.submodule {
      # Feature 027: Freeform type allows arbitrary nested attributes
      # without requiring schema changes (e.g., user.tokens.github, user.git.signingKey)
      freeformType = lib.types.attrsOf lib.types.anything;

      options = {
        name = lib.mkOption {
          type = lib.types.str;
          description = "User's login name (must match system username)";
          example = "cdrokar";
        };

        email = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            User's email address (for git, etc.)
            Can be set to "<secret>" to load from encrypted secrets file.
          '';
          example = "cdrokar@example.com";
        };

        fullName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            User's full display name.
            Can be set to "<secret>" to load from encrypted secrets file.
          '';
          example = "Charles Drokar";
        };

        # Security configuration (passwords, SSH keys, credentials)
        security = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              password = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  User's initial password (hashed).
                  MUST be set to "<secret>" to load from encrypted secrets file.
                  Never store passwords in plain text in user configuration.

                  The password is used only for initial user account creation.
                  After the account exists, changing this value has no effect.
                '';
                example = "<secret>";
              };

              sshKeys = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = {};
                description = ''
                  SSH key declarations. Each key name maps to a secret placeholder.
                  Keys are deployed to ~/.ssh/ during activation.

                  Common key names:
                    personal - Primary SSH key (deployed as id_ed25519)
                    git - Deploy key for git repositories
                    fonts - Deploy key for private font repositories
                '';
                example = {
                  git = "<secret>";
                  fonts = "<secret>";
                };
              };

              protonPassword = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  Proton account password. Used by both Proton VPN (CLI login)
                  and Proton Mail Bridge.
                  Set to "<secret>" to load from encrypted secrets file.
                '';
                example = "<secret>";
              };

              cachixAuthToken = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  Write authentication token for pushing builds to Cachix cache.
                  Set to "<secret>" to load from encrypted secrets file.

                  Token obtained from: https://app.cachix.org/personal-auth-tokens
                '';
                example = "<secret>";
              };
            };
          });
          default = null;
          description = ''
            Security configuration for passwords, SSH keys, and credentials.
          '';
        };

        # Locale configuration (Feature: 018-user-locale-config)
        locale = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              languages = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null;
                description = ''
                  Ordered list of preferred languages (ISO 639-1 + ISO 3166-1 format).
                  First language is primary, subsequent languages are fallbacks.

                  Examples: ["en-CA" "fr-CA"], ["en-US"], ["fr-FR" "en-GB"]
                '';
                example = ["en-CA" "fr-CA"];
              };

              keyboard = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    layout = lib.mkOption {
                      type = lib.types.nullOr (lib.types.listOf lib.types.str);
                      default = null;
                      description = ''
                        Ordered list of keyboard layouts using platform-agnostic names.
                        First layout is default, subsequent layouts available for switching.

                        Platform-agnostic names are translated to platform-specific identifiers
                        by the platform's locale configuration module.

                        Common layouts: us, canadian-english, canadian-french, british, dvorak, colemak
                      '';
                      example = ["canadian-english" "canadian-french"];
                    };

                    macStyleMappings = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = ''
                        Whether to swap Super and Ctrl modifier keys on Linux.
                        When true, Linux keyboard behaves like macOS (Super acts as Ctrl).
                        Has no effect on macOS (Darwin) builds.
                      '';
                      example = false;
                    };
                  };
                });
                default = null;
                description = ''
                  Keyboard configuration including layout selection and modifier key behavior.
                '';
              };

              timezone = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  IANA timezone identifier for the user's timezone.

                  Examples: "America/Toronto", "America/Vancouver", "Europe/London"
                  See: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
                '';
                example = "America/Toronto";
              };

              format = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  POSIX locale identifier for regional settings (date/time/number format,
                  measurements, currency).

                  Format: language_REGION[.encoding]
                  Examples: "en_CA.UTF-8", "en_US.UTF-8", "fr_CA.UTF-8"

                  The format setting is independent of languages, allowing users to have
                  UI in one language while using regional formatting from another locale.
                '';
                example = "en_CA.UTF-8";
              };
            };
          });
          default = null;
          description = ''
            Locale configuration for languages, keyboard, timezone, and regional format.
            All fields are optional - platform uses defaults when not specified.
          '';
        };

        # Workspace configuration (applications, dock, repositories)
        workspace = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              # Application configuration field (Feature: 020-app-array-config)
              applications = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null;
                description = ''
                  List of application names to import from the platform application registry.

                  Platform libraries (darwin.nix, nixos.nix) automatically read this field
                  and generate the appropriate imports. Users simply declare which apps they
                  want - no imports or helper functions needed.

                  Applications are resolved from:
                  - system/shared/app/**/*.nix (cross-platform applications)
                  - system/{platform}/app/**/*.nix (platform-specific applications)

                  The system automatically handles:
                  - Application name validation against registry
                  - Platform-specific application availability
                  - Helpful error messages for typos or missing apps
                  - Graceful degradation for unavailable platform-specific apps

                  Examples:
                    # Minimal configuration
                    applications = [ "git" ];

                    # Import all available applications
                    applications = [ "*" ];

                    # No applications
                    applications = null;  # or omit the field
                '';
                example = ["git" "zsh" "helix"];
              };

              # Dock configuration field (Feature: 023-user-dock-config)
              docked = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = ''
                  Dock items in display order. Supports:
                  - Application names: "zen", "firefox", "mail"
                  - Folders: "/Downloads", "/Documents" (resolved to $HOME/<name>)
                  - Separators: "|" (standard), "||" (thick)
                  - System items: "<trash>"

                  Missing items are silently skipped. Empty array clears dock.
                  If not specified (empty), dock configuration is unchanged.

                  Platform behavior:
                  - Darwin: Uses dockutil to configure dock
                  - GNOME: Sets favorite-apps via gsettings
                  - Other platforms: Field is ignored
                '';
                example = ["zen" "brave" "|" "zed" "ghostty" "/Downloads"];
              };

              # Browser bookmarks (shared across supported browsers)
              bookmarks = lib.mkOption {
                type = lib.types.listOf lib.types.anything;
                default = [];
                description = ''
                  Declarative browser bookmarks, consumed by browser app modules
                  that support home-manager bookmark management (e.g. librewolf, firefox).

                  Each item is one of:
                  - Bookmark:  { name = "..."; url = "..."; tags = [...]; keyword = "..."; }
                  - Folder:    { name = "..."; toolbar = true; bookmarks = [ ... ]; }
                  - Separator: "separator"
                '';
                example = [
                  {name = "NixOS"; url = "https://nixos.org"; tags = ["nix"];}
                  {
                    name = "Nix Sites";
                    toolbar = true;
                    bookmarks = [
                      {name = "Home Manager"; url = "https://nix-community.github.io/home-manager/";}
                      {name = "Nixpkgs"; url = "https://search.nixos.org/packages";}
                    ];
                  }
                ];
              };

              # Repository configuration field (Feature: 038-multi-provider-repositories)
              repositories = lib.mkOption {
                description = ''
                  List of remote repositories to synchronize during activation.

                  Each repository is automatically synced based on its detected or
                  specified provider type (git, s3, proton-drive). Failed syncs are
                  logged but don't block other repositories.
                '';
                type = lib.types.listOf (lib.types.submodule {
                  options = {
                    url = lib.mkOption {
                      type = lib.types.str;
                      description = ''
                        Repository URL or location string.
                        Provider is automatically detected from URL pattern.
                      '';
                      example = "git@github.com:user/repo.git";
                    };

                    provider = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = ''
                        Explicit provider type override (git, s3, proton-drive).
                        If null, provider is auto-detected from URL pattern.
                      '';
                      example = "git";
                    };

                    path = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = ''
                        Local destination path for repository content.
                        If null, uses provider default.
                      '';
                      example = "~/projects/my-repo";
                    };

                    auth = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = ''
                        Authentication reference for accessing the repository.
                        Format: "<secret-type>.<key-name>"

                        Examples:
                          - "security.sshKeys.github" → user.security.sshKeys.github
                          - "tokens.s3" → user.tokens.s3
                      '';
                      example = "security.sshKeys.github";
                    };

                    options = lib.mkOption {
                      type = lib.types.attrs;
                      default = {};
                      description = ''
                        Provider-specific configuration options.
                      '';
                      example = {
                        branch = "main";
                        depth = 1;
                      };
                    };
                  };
                });
                default = [];
              };
            };
          });
          default = null;
          description = ''
            Workspace configuration for applications, dock layout, and repositories.
          '';
        };

        # Style configuration (visual theming: fonts, wallpaper, colors)
        style = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              # Font configuration field (Feature: 030-user-font-config)
              # Optional field for declaring fonts to install and configure

              fonts = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = let
                    # Submodule for font category (serif, sansSerif, monospace, emoji)
                    fontCategoryType = lib.types.submodule {
                      options = {
                        families = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [];
                          description = ''
                            List of font family names in preference order.
                            Use the exact font family name as shown by fc-list.
                            First font is primary, rest are fallbacks.

                            Examples: ["Fira Code"], ["Berkeley Mono" "JetBrains Mono"]
                          '';
                          example = ["Fira Code" "JetBrains Mono"];
                        };

                        size = lib.mkOption {
                          type = lib.types.int;
                          default = 11;
                          description = ''
                            Font size in points. Default is 11.
                          '';
                          example = 12;
                        };
                      };
                    };
                  in {
                    defaults = lib.mkOption {
                      type = lib.types.nullOr (lib.types.submodule {
                        options = {
                          serif = lib.mkOption {
                            type = fontCategoryType;
                            default = {};
                            description = "Default serif font configuration.";
                            example = {
                              families = ["Crimson Pro"];
                              size = 12;
                            };
                          };

                          sansSerif = lib.mkOption {
                            type = fontCategoryType;
                            default = {};
                            description = "Default sans-serif font configuration.";
                            example = {
                              families = ["Inter"];
                              size = 10;
                            };
                          };

                          monospace = lib.mkOption {
                            type = fontCategoryType;
                            default = {};
                            description = "Default monospace font configuration.";
                            example = {
                              families = ["Fira Code" "JetBrains Mono"];
                              size = 11;
                            };
                          };

                          emoji = lib.mkOption {
                            type = fontCategoryType;
                            default = {};
                            description = "Default emoji font configuration.";
                            example = {
                              families = ["Noto Color Emoji"];
                            };
                          };
                        };
                      });
                      default = null;
                      description = ''
                        Default font settings for each font category.
                        Font family names are auto-translated to nixpkgs packages.
                      '';
                    };

                    packages = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [];
                      description = ''
                        Explicit font package names from nixpkgs.
                        Use this as escape hatch when auto-translation fails.

                        Example: ["hack-font"] when "Hack" doesn't translate correctly.
                      '';
                      example = ["hack-font"];
                    };

                    repositories = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [];
                      description = ''
                        Private git repository URLs containing fonts.
                        Requires security.sshKeys.fonts to be configured for authentication.

                        Use SSH URL format: git@github.com:user/repo.git
                        Repositories are cloned to ~/.local/share/fonts/private/
                      '';
                      example = ["git@github.com:cdrolet/d-fonts.git"];
                    };
                  };
                });
                default = null;
                description = ''
                  Font configuration for installing and configuring fonts.

                  Font family names in defaults are auto-translated to nixpkgs packages:
                    "Fira Code" → pkgs.fira-code
                    "JetBrains Mono" → pkgs.jetbrains-mono

                  Example:
                    fonts = {
                      defaults = {
                        monospace = { families = ["Fira Code"]; size = 12; };
                        sansSerif = { families = ["Inter"]; };
                      };
                      repositories = ["git@github.com:user/fonts.git"];
                    };
                '';
              };
              # Theme configuration (color scheme, polarity, color overrides)
              theme = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = ''
                        Base16 color scheme name to load from base16-schemes.
                        Case-insensitive, spaces converted to dashes.

                        Examples: "Nord", "solarized-dark", "Catppuccin Mocha"
                      '';
                      example = "Nord";
                    };

                    polarity = lib.mkOption {
                      type = lib.types.nullOr (lib.types.enum [ "either" "light" "dark" ]);
                      default = null;
                      description = ''
                        Theme polarity for stylix. Controls light/dark theme generation.
                        - "dark": Dark background, light text
                        - "light": Light background, dark text
                        - "either": Auto-detect from scheme
                      '';
                      example = "dark";
                    };

                    color = lib.mkOption {
                      type = lib.types.nullOr (lib.types.submodule {
                        options = {
                          fromWallpaper = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = ''
                              When true, stylix extracts a base16 color palette from the
                              wallpaper image using a genetic algorithm. The theme.name
                              field is ignored when this is enabled.

                              theme.polarity still applies (guides light/dark selection).
                              color.overrides still apply on top of the generated palette.
                            '';
                            example = true;
                          };

                          overrides = lib.mkOption {
                            type = lib.types.attrsOf lib.types.str;
                            default = {};
                            description = ''
                              Color overrides using base16 names (base00-base0F) or friendly aliases.
                              Values are hex color strings (with or without #).

                              Supported aliases:
                                background → base00    foreground → base05
                                black → base00         white → base07
                                red → base08           orange → base09
                                yellow → base0A        green → base0B
                                cyan → base0C          blue → base0D
                                purple → base0E        magenta → base0E
                                brown → base0F

                              Direct base16 names also accepted: base00, base01, ..., base0F
                            '';
                            example = {
                              background = "#2e3440";
                              red = "#bf616a";
                              base02 = "#4c566a";
                            };
                          };
                        };
                      });
                      default = null;
                      description = ''
                        Color configuration for the theme.
                        Set fromWallpaper to extract palette from wallpaper image,
                        or use overrides to customize individual base16 colors.
                      '';
                    };

                    # Opacity configuration (transparency levels)
                    opacity = lib.mkOption {
                      type = lib.types.nullOr (lib.types.submodule {
                        options = {
                          applications = lib.mkOption {
                            type = lib.types.float;
                            default = 1.0;
                            description = ''
                              Opacity for general application windows (0.0 = transparent, 1.0 = opaque).
                              Support varies by application — works best with GTK/Qt apps.
                            '';
                            example = 0.95;
                          };

                          terminal = lib.mkOption {
                            type = lib.types.float;
                            default = 1.0;
                            description = ''
                              Opacity for terminal emulators (ghostty, kitty, alacritty, etc.).
                              Works across all terminals supported by stylix.
                            '';
                            example = 0.9;
                          };

                          desktop = lib.mkOption {
                            type = lib.types.float;
                            default = 1.0;
                            description = ''
                              Opacity for desktop UI elements like panels and bars (e.g. waybar).
                              Setting to 0.0 makes them fully transparent but may affect tooltips.
                            '';
                            example = 0.8;
                          };

                          popups = lib.mkOption {
                            type = lib.types.float;
                            default = 1.0;
                            description = ''
                              Opacity for notifications and popup windows.
                              Support varies by notification daemon.
                            '';
                            example = 0.95;
                          };
                        };
                      });
                      default = null;
                      description = ''
                        Opacity levels for different UI categories.
                        All values range from 0.0 (fully transparent) to 1.0 (fully opaque).
                      '';
                    };
                  };
                });
                default = null;
                description = ''
                  Theme configuration for color scheme, overrides, and opacity.
                  All fields are optional. Name loads a base16 scheme,
                  colors override individual values.
                '';
              };
              # Cursor theme configuration (package, name, size)
              cursor = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    package = lib.mkOption {
                      type = lib.types.str;
                      description = ''
                        Nixpkgs attribute name for the cursor theme package.
                        The package must provide cursor themes in share/icons/.

                        Examples: "bibata-cursors", "capitaine-cursors", "phinger-cursors"
                      '';
                      example = "bibata-cursors";
                    };

                    name = lib.mkOption {
                      type = lib.types.str;
                      description = ''
                        Cursor theme name within the package (directory name under share/icons/).

                        Examples: "Bibata-Modern-Ice", "capitaine-cursors", "phinger-cursors-light"
                      '';
                      example = "Bibata-Modern-Ice";
                    };

                    size = lib.mkOption {
                      type = lib.types.int;
                      default = 24;
                      description = ''
                        Cursor size in pixels.
                        Common sizes: 16, 24, 32, 48.
                      '';
                      example = 24;
                    };
                  };
                });
                default = null;
                description = ''
                  Cursor theme configuration. When set, all fields (package, name, size)
                  are applied to stylix.cursor for system-wide cursor theming.
                '';
              };

              # Icon theme configuration (package, dark/light theme names)
              icon = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    package = lib.mkOption {
                      type = lib.types.str;
                      description = ''
                        Nixpkgs attribute name for the icon theme package.

                        Examples: "papirus-icon-theme", "adwaita-icon-theme", "tela-icon-theme"
                      '';
                      example = "papirus-icon-theme";
                    };

                    darkName = lib.mkOption {
                      type = lib.types.str;
                      description = ''
                        Icon theme name to use in dark mode (directory name under share/icons/).

                        Examples: "Papirus-Dark", "Adwaita", "Tela-dark"
                      '';
                      example = "Papirus-Dark";
                    };

                    lightName = lib.mkOption {
                      type = lib.types.str;
                      description = ''
                        Icon theme name to use in light mode (directory name under share/icons/).

                        Examples: "Papirus-Light", "Adwaita", "Tela"
                      '';
                      example = "Papirus-Light";
                    };
                  };
                });
                default = null;
                description = ''
                  Icon theme configuration. When set, enables stylix icon theming
                  with separate themes for dark and light mode.
                '';
              };

              # Wallpaper configuration (desktop background)
              wallpaper = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    path = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = ''
                        Local wallpaper image path. Supports home-relative paths with ~/.
                        Supported formats: .jpg, .jpeg, .png, .heic, .webp
                      '';
                      example = "~/Pictures/wallpaper.jpg";
                    };

                    remote = lib.mkOption {
                      type = lib.types.nullOr (lib.types.submodule {
                        options = {
                          url = lib.mkOption {
                            type = lib.types.str;
                            description = "URL to fetch the wallpaper image from.";
                            example = "https://unsplash.com/photos/ZqLeQDjY6fY/download";
                          };
                          hash = lib.mkOption {
                            type = lib.types.str;
                            description = ''
                              SRI hash for the fetched image (required for reproducibility).
                              Get with: nix-prefetch-url --type sha256 <url> | nix hash convert
                            '';
                            example = "sha256-Dm/0nKiTFOzNtSiARnVg7zM0J1o+EuIdUQ3OAuasM58=";
                          };
                        };
                      });
                      default = null;
                      description = "Fetch wallpaper from a URL at build time.";
                    };

                    scaleMode = lib.mkOption {
                      type = lib.types.nullOr (lib.types.enum [
                        "stretch" "fill" "fit" "center" "tile"
                      ]);
                      default = null;
                      description = ''
                        How the wallpaper is scaled to fit the screen.
                        - stretch: Stretch to cover (may distort)
                        - fill: Scale to fill, cropping if needed
                        - fit: Scale to fit without cropping
                        - center: Center without resizing
                        - tile: Tile to cover screen
                        When null, platform default is used (typically "fill").
                      '';
                      example = "fill";
                    };

                    cyclingFrequency = lib.mkOption {
                      type = lib.types.nullOr (lib.types.enum [
                        "on-login" "every-5min" "every-30min" "hourly" "daily"
                      ]);
                      default = null;
                      description = ''
                        How often to cycle through wallpapers when path points to a folder.
                        When path is a folder and this is null, defaults to "daily".
                        - on-login: Change wallpaper once at login
                        - every-5min: Change every 5 minutes
                        - every-30min: Change every 30 minutes
                        - hourly: Change every hour
                        - daily: Change once per day (default for folders)
                        Linux: uses wpaperd duration. macOS: uses built-in folder rotation.
                      '';
                      example = "daily";
                    };

                    generate = lib.mkOption {
                      type = lib.types.nullOr (lib.types.submodule {
                        options = {
                          color = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = ''
                              Generate a solid-color wallpaper from a base16 color.
                              Accepts base16 names (base00-base0F) or aliases
                              (background, red, blue, etc.).
                            '';
                            example = "base00";
                          };

                          brightness = lib.mkOption {
                            type = lib.types.nullOr lib.types.float;
                            default = null;
                            description = ''
                              Brightness adjustment applied to the wallpaper image
                              (from path or remote) via ImageMagick.
                              Range: 0.0 (black) to 2.0 (double brightness).
                              1.0 = unchanged. Values < 1.0 dim the image.
                            '';
                            example = 0.8;
                          };

                          pattern = lib.mkOption {
                            type = lib.types.nullOr (lib.types.enum [
                              "solid" "gradient"
                            ]);
                            default = null;
                            description = ''
                              Generate a wallpaper from theme colors.
                              - solid: Single-color pixel from generate.color (or base00)
                              - gradient: Horizontal gradient using base16 background
                                colors (base00 through base03)
                            '';
                            example = "gradient";
                          };
                        };
                      });
                      default = null;
                      description = ''
                        Generate a wallpaper from theme colors or adjust an existing image.
                        Takes precedence over path and remote.
                      '';
                    };
                  };
                });
                default = null;
                description = ''
                  Wallpaper configuration for desktop background.
                  Priority: generate > remote > path.
                  All fields are optional.
                '';
              };
            }; # end style options
          });
          default = null;
          description = ''
            Style configuration for visual theming.
            Groups fonts, wallpaper, and color settings.
          '';
        };

        # Backup configuration (Restic + Backblaze B2)
        backup = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              repository = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    bucket = lib.mkOption {
                      type = lib.types.str;
                      description = "Backblaze B2 bucket name.";
                      example = "my-backup-bucket";
                    };
                    endpoint = lib.mkOption {
                      type = lib.types.str;
                      description = "B2 S3-compatible endpoint (without https://).";
                      example = "s3.ca-east-006.backblazeb2.com";
                    };
                    keyId = lib.mkOption {
                      type = lib.types.str;
                      default = "<secret>";
                      description = "B2 application key ID. Use \"<secret>\" to read from secrets.age.";
                    };
                    applicationKey = lib.mkOption {
                      type = lib.types.str;
                      default = "<secret>";
                      description = "B2 application key. Use \"<secret>\" to read from secrets.age.";
                    };
                    password = lib.mkOption {
                      type = lib.types.str;
                      default = "<secret>";
                      description = "Restic repository encryption password. Use \"<secret>\" to read from secrets.age.";
                    };
                  };
                };
                description = "Backblaze B2 repository connection and credentials.";
              };

              schedule = lib.mkOption {
                type = lib.types.nullOr (lib.types.enum ["daily" "weekly"]);
                default = "daily";
                description = "How often to run automatic backups.";
              };

              retain = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    daily = lib.mkOption {
                      type = lib.types.int;
                      default = 7;
                      description = "Number of daily snapshots to keep.";
                    };
                    weekly = lib.mkOption {
                      type = lib.types.int;
                      default = 4;
                      description = "Number of weekly snapshots to keep.";
                    };
                    monthly = lib.mkOption {
                      type = lib.types.int;
                      default = 6;
                      description = "Number of monthly snapshots to keep.";
                    };
                  };
                };
                default = {};
                description = "Snapshot retention policy.";
              };

              paths = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Additional paths to back up beyond the defaults.";
                example = ["~/Work" "~/Archive"];
              };

              exclude = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Additional exclude patterns beyond defaults.";
                example = ["**/.DS_Store" "~/project/large-assets"];
              };
            };
          });
          default = null;
          description = ''
            Restic backup configuration targeting a Backblaze B2 bucket.

            Default included paths:
              ~/Documents  ~/Pictures  ~/Videos  ~/Music  ~/project
              ~/.config/agenix  ~/.gnupg  ~/.ssh  ~/.local/share

            Default excluded patterns:
              ~/.local/share/nix-config  ~/.local/share/Trash
              **/node_modules  **/.git  **/*.tmp

            Credentials are read from secrets.age at activation time and written
            to ~/.config/restic/env (chmod 600).

            Example:
              backup = {
                repository = {
                  bucket   = "my-bucket";
                  endpoint = "s3.ca-east-006.backblazeb2.com";
                  keyId          = "<secret>";
                  applicationKey = "<secret>";
                  password       = "<secret>";
                };
                schedule = "daily";
                retain   = { daily = 7; weekly = 4; monthly = 6; };
              };

            Secrets:
              just secrets-set <user> backup.repository.keyId          "..."
              just secrets-set <user> backup.repository.applicationKey "..."
              just secrets-set <user> backup.repository.password       "..."
          '';
        };

        # Note: Additional fields can be added without schema changes thanks to freeformType
        # Common freeform fields used with secrets:
        #   tokens.github = "<secret>";
        #   tokens.openai = "<secret>";
        #   git.signingKey = "<secret>";
        #   services.aws.secretKey = "<secret>";
      };
    };
  };

  # Default fullName to name when not explicitly set
  # mkDefault allows user to override with explicit value
  config.user.fullName = lib.mkDefault config.user.name;
}
