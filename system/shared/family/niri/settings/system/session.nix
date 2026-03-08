{
  config,
  lib,
  pkgs,
  ...
}: {
  # Disable X11 - Niri is Wayland-only
  services.xserver.enable = lib.mkDefault false;

  # Configure Wayland session environment
  environment.sessionVariables = {
    XDG_SESSION_TYPE = lib.mkDefault "wayland";
    XDG_CURRENT_DESKTOP = lib.mkDefault "niri";
  };
}
