# Contract: Keyboard Configuration Schema
#
# Defines the expected structure for user.keyboard in user-schema.nix
# This is a reference contract — the actual implementation lives in user-schema.nix
{lib}: {
  keyboard = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        layout = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = ''
            Ordered list of keyboard layouts using platform-agnostic names.
            First layout is default, subsequent layouts available for switching.

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
}
