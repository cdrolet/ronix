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
  # fuzzel requires wlr-layer-shell (wlroots compositors only — not GNOME/Mutter)
  config = lib.optionalAttrs (options ? home && !builtins.elem "gnome" (config.host.family or [])) {
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
