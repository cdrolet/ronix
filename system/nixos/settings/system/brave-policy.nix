# Brave Browser - System-level Managed Policy
#
# Purpose: Write Brave managed policies to system policy directories.
#          Linux only reads policies from /etc (not from ~/.config/).
#
# NixOS builds Brave from the chromium derivation, so it reads policies
# from /etc/chromium/policies/managed/ (not /etc/brave/).
# Both paths are written for compatibility.
#
# Policies enforced:
#   - Disable Brave Rewards, Wallet, VPN
#   - Force-install extensions (uBlock Origin, Dark Reader, Bitwarden, etc.)
#
# Platform: NixOS (system-level, environment.etc)
{lib, ...}: let
  chromeWebStoreUrl = "https://clients2.google.com/service/update2/crx";

  extensions = [
    "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite (MV3, uBlock Origin removed from CWS)
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "aimiinbnnkboelefkjlenlgimcabobli" # JSON Viewer
    "mdnleldcmiljblolnjhpnblkcekpdkpa" # Requestly
    "idgpnmonknjnojddfkpgkljpfnnfcklj" # ModHeader
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
  ];

  policy = {
    BraveRewardsDisabled = true;
    BraveWalletDisabled = true;
    BraveVPNDisabled = true;
    ExtensionInstallForcelist =
      map (id: "${id};${chromeWebStoreUrl}") extensions;
    ExtensionSettings = {
      "nngceckbapebfimnlniiiahkandclblb" = {toolbar_pin = "force_pinned";}; # Bitwarden
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" = {toolbar_pin = "force_pinned";}; # Dark Reader
    };
  };

  policyJson = builtins.toJSON policy;
in {
  # /etc/chromium — NixOS brave package reads from chromium policy path
  environment.etc."chromium/policies/managed/brave.json" = {
    text = policyJson;
    mode = "0644";
  };

  # /etc/brave — upstream Brave path (fallback)
  environment.etc."brave/policies/managed/brave.json" = {
    text = policyJson;
    mode = "0644";
  };
}
