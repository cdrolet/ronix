# Brave Browser - Privacy-focused Chromium-based browser
#
# Purpose: Chromium-based browser with built-in ad/tracker blocking
# Platform: Cross-platform (Homebrew on Darwin, nix on Linux)
# Website: https://brave.com/
#
# Extensions & Policies:
#   Linux:  managed via programs.chromium (writes ~/.config/chromium/policies/managed/)
#   Darwin: managed via home.file to the macOS-specific managed policies directory
#           (~/Library/Application Support/BraveSoftware/Brave-Browser/policies/managed/)
#
# commandLineArgs:
#   Linux only — nix wraps the binary so flags are injected at launch.
#   Darwin: Brave is Homebrew-managed; nix cannot wrap the binary.
#
# Bookmarks:
#   Seeded from user.workspace.bookmarks on each activation (home.activation).
#   Uses cp (not symlink) so Brave can write to the file at runtime.
{
  config,
  pkgs,
  lib,
  configContext ? "home-manager",
  system ? "",
  ...
}: let
  isDarwin = lib.hasSuffix "darwin" system;
  isLinux = configContext != "darwin-system" && !isDarwin;
  isHomeManager = configContext != "darwin-system";

  # Shared configuration (used by both Linux and Darwin)
  extensions = [
    {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";} # uBlock Origin
    {id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";} # Dark Reader
    {id = "bgjfeiojhflfhlhjdbfmgjiiceknjlhk";} # JSON Viewer
    {id = "begnohkofejdniblmofmajpecknbnklo";} # Requestly
    {id = "iaiomicjabeggjcfkbimgmglanimpnae";} # ModHeader
    {id = "nndknepjnldbmdaqdcipilghnekkbhag";} # Bitwarden
  ];

  extraOpts = {
    BraveRewardsDisabled = true;
    BraveWalletDisabled = true;
    BraveVPNDisabled = true;
  };

  # Linux only — nix wraps the binary; has no effect on Homebrew-installed Brave
  commandLineArgs = [
    "--disable-features=PrivacySandboxSettings4"
    "--disable-features=WebRtcHideLocalIpsWithMdns"
    "--password-store=basic"
  ];

  # Darwin policy JSON: combines extraOpts + ExtensionInstallForcelist
  # Policy files are read-only by Brave, so home.file symlinks are safe here.
  chromeWebStoreUrl = "https://clients2.google.com/service/update2/crx";
  darwinPolicyJson = builtins.toJSON (extraOpts
    // {
      ExtensionInstallForcelist =
        map (e: "${e.id};${chromeWebStoreUrl}") extensions;
    });

  # Bookmarks
  bookmarksLib = import ../../lib/bookmarks.nix {inherit lib pkgs;};
  userBookmarks = (config.user.workspace or {}).bookmarks or [];
  bookmarksFile = bookmarksLib.mkChromiumBookmarksFile userBookmarks;

  braveProfileDir =
    if isDarwin
    then "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default"
    else "$HOME/.config/BraveSoftware/Brave-Browser/Default";
in
  lib.mkMerge [
    # Darwin system: install via Homebrew
    (lib.optionalAttrs (configContext == "darwin-system") {
      homebrew.casks = ["brave-browser"];
    })

    # Linux: install + extensions + policies + commandLineArgs via programs.chromium
    (lib.optionalAttrs isLinux {
      programs.chromium = {
        enable = true;
        package = pkgs.brave;
        inherit extensions commandLineArgs;
        extraOpts = extraOpts;
      };

      xdg.mimeApps.defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
      };
    })

    # Darwin home-manager: extensions + policies via managed policy file
    # commandLineArgs are not applicable (Homebrew binary, nix cannot wrap it)
    (lib.optionalAttrs (isHomeManager && isDarwin) {
      home.file."Library/Application Support/BraveSoftware/Brave-Browser/policies/managed/brave.json".text =
        darwinPolicyJson;
    })

    # All platforms: seed bookmarks on activation
    (lib.optionalAttrs (isHomeManager && userBookmarks != []) {
      home.activation.braveBookmarks = lib.hm.dag.entryAfter ["writeBoundary"] ''
        braveDir="${braveProfileDir}"
        $DRY_RUN_CMD mkdir -p "$braveDir"
        $DRY_RUN_CMD cp --no-preserve=mode ${bookmarksFile} "$braveDir/Bookmarks"
      '';
    })
  ]
