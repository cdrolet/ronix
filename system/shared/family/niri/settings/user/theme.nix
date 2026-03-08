{
  config,
  lib,
  pkgs,
  ...
}: let
  # Default to dark mode for Niri (minimalist, keyboard-driven aesthetic)
  darkMode = config.user.darkMode or true;
in {
  # Use mkIf instead of optionalAttrs to avoid infinite recursion
  gtk = lib.mkIf darkMode {
    enable = true;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # Set GTK theme environment variable
  home.sessionVariables = lib.mkIf darkMode {
    GTK_THEME = "Adwaita:dark";
  };

  # Configure dconf for Wayland portal dark mode preference
  dconf.settings = lib.mkIf darkMode {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
