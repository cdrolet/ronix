# Printing - CUPS Service
#
# Purpose: Enable CUPS printing service for network and local printers.
# Platform: NixOS (system-level service)
#
# Auto-discovered: adding this file is sufficient — no manual imports needed.
{
  lib,
  pkgs,
  ...
}: {
  services.printing = {
    enable = lib.mkDefault true;

    # gutenprint: broad driver set covering most thermal, inkjet, and laser printers.
    # For thermal printers (ESC/POS), also works as generic text/raster printer.
    # Add more specific drivers in host config if needed:
    #   services.printing.drivers = [ pkgs.hplip ];   # HP printers
    #   services.printing.drivers = [ pkgs.brlaser ]; # Brother laser
    drivers = lib.mkDefault [pkgs.gutenprint];
  };

  # Avahi: enables auto-discovery of network printers (mDNS/Bonjour)
  services.avahi = {
    enable = lib.mkDefault true;
    nssmdns4 = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
  };
}
