{
  config,
  pkgs,
  lib,
  ...
}: let
  desktopMetadataLib = import ../../lib/desktop-metadata.nix {inherit lib;};
in {
  # Helix - Modern modal text editor
  # Post-modern modal text editor with built-in LSP and tree-sitter
  # Dependencies: None (LSP servers installed separately as needed)

  # Define desktop option for helix
  options.programs.helix.desktop = lib.mkOption {
    type = lib.types.nullOr desktopMetadataLib.desktopMetadataType;
    default = null;
    description = "Desktop integration metadata for Helix editor";
  };

  config = {
    programs.helix = {
      enable = true;

      # Desktop metadata for file associations
      desktop = {
        paths = {
          darwin = "${pkgs.helix}/bin/hx";
          nixos = "${pkgs.helix}/bin/hx";
        };
        associations = [
          ".txt"
          ".md"
          ".nix"
          ".rs"
          ".py"
          ".js"
          ".ts"
          ".json"
          ".yaml"
          ".toml"
        ];
        autostart = false;
      };

      settings = {
        editor = {
          line-number = "relative";
          mouse = true;
          cursorline = true;
          color-modes = true;

          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };

          file-picker = {
            hidden = false;
          };

          lsp = {
            display-messages = true;
            display-inlay-hints = true;
          };

          indent-guides = {
            render = true;
            character = "│";
          };
        };

        keys.normal = {
          space.space = "file_picker";
          space.w = ":w";
          space.q = ":q";
          esc = ["collapse_selection" "keep_primary_selection"];
        };
      };

      languages = {
        language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "${pkgs.alejandra}/bin/alejandra";
          }
          {
            name = "rust";
            auto-format = true;
          }
          {
            name = "python";
            auto-format = true;
          }
        ];
      };
    };

    # Shell aliases for helix
    home.shellAliases = {
      hx = "helix";
    };
  };
}
