# Brave Browser - System-level Managed Policy
#
# Purpose: Write Brave managed policies to /etc/brave/policies/managed/
#          Linux only reads policies from /etc (not from ~/.config/).
#
# Policies enforced:
#   - Disable Brave Rewards, Wallet, VPN
#   - Force-install extensions (uBlock Origin, Dark Reader, Bitwarden, etc.)
#
# Platform: NixOS (system-level, environment.etc)
{lib, ...}: let
  chromeWebStoreUrl = "https://clients2.google.com/service/update2/crx";

  extensions = [
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "bgjfeiojhflfhlhjdbfmgjiiceknjlhk" # JSON Viewer
    "begnohkofejdniblmofmajpecknbnklo" # Requestly
    "iaiomicjabeggjcfkbimgmglanimpnae" # ModHeader
    "nndknepjnldbmdaqdcipilghnekkbhag" # Bitwarden
  ];

  policy = {
    BraveRewardsDisabled = true;
    BraveWalletDisabled = true;
    BraveVPNDisabled = true;
    ExtensionInstallForcelist =
      map (id: "${id};${chromeWebStoreUrl}") extensions;
  };
in {
  environment.etc."brave/policies/managed/brave.json" = {
    text = builtins.toJSON policy;
    mode = "0644";
  };
}
