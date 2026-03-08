{
  config,
  lib,
  pkgs,
  ...
}: {
  # Install Niri compositor
  # Note: We don't use programs.niri.enable because it installs a default config
  # that conflicts with home-manager's xdg.configFile. Instead, install the package
  # and let home-manager manage the configuration.
  # Register niri as a Wayland session
  services.displayManager.sessionPackages = [pkgs.niri];

  # Wayland environment variables for better app compatibility
  environment.sessionVariables = {
    # Enable Wayland support for Electron apps
    NIXOS_OZONE_WL = "1";
  };

  # Enable XDG desktop portal for Wayland
  xdg.portal = {
    enable = lib.mkDefault true;
    extraPortals = [pkgs.xdg-desktop-portal-gnome];
    config.common.default = "*";
  };

  # Enable polkit for privilege escalation
  security.polkit.enable = lib.mkDefault true;

  # Enable GNOME keyring (needed for secrets management)
  services.gnome.gnome-keyring.enable = lib.mkDefault true;

  # Install required system packages
  environment.systemPackages = with pkgs; [
    niri # Compositor (config managed by home-manager, not programs.niri)
    waybar # Status bar (config managed by home-manager waybar app module)
    xwayland-satellite # Required for X11 app support in Niri
  ];
}
