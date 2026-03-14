# Printing - CUPS Service
#
# Purpose: Enable CUPS printing service for network and local printers.
# Platform: NixOS (system-level service)
#
# Auto-discovered: adding this file is sufficient — no manual imports needed.
{lib, ...}: {
  services.printing = {
    enable = lib.mkDefault true;

    # Common printer drivers
    # Add specific drivers in host config if needed:
    #   services.printing.drivers = [ pkgs.gutenprint pkgs.hplip ];
    drivers = lib.mkDefault [];
  };

  # Avahi: enables auto-discovery of network printers (mDNS/Bonjour)
  services.avahi = {
    enable = lib.mkDefault true;
    nssmdns4 = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
  };
}
