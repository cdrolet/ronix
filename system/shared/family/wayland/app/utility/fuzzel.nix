# Fuzzel - Lightweight Wayland application launcher
# https://codeberg.org/dnkl/fuzzel
#
# Fonts and colors are applied automatically by stylix via programs.fuzzel.settings.
{
  config,
  pkgs,
  lib,
  options,
  ...
}: {
  config = lib.optionalAttrs (options ? home) {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          # Terminal emulator for terminal apps
          terminal = builtins.head (config.user.default.terminal or ["foot"]);

          # Number of results to show
          lines = 15;

          # Width as percentage of screen
          width = 40;

          # Prompt text
          prompt = ">";
        };
      };
    };
  };
}
