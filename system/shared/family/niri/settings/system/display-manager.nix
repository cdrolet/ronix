{
  config,
  lib,
  pkgs,
  ...
}: {
  # Configure greetd display manager with tuigreet greeter
  services.greetd = {
    enable = lib.mkDefault true;
    settings = {
      default_session = {
        command = lib.mkDefault "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --cmd niri-session";
      };

      # TEMPORARY DEBUG: Removed - use F2 at login to run commands
      # Run: niri-session 2>&1 | tee /tmp/niri.log
      # Then check: cat /tmp/niri.log
    };
  };

  # Ensure niri and essential packages are available
  environment.systemPackages = [
    pkgs.niri
    pkgs.foot
    pkgs.fuzzel # Launcher for Niri
  ];
}
