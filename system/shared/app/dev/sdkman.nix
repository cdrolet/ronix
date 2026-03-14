{
  config,
  pkgs,
  lib,
  ...
}: {
  # SDKMAN - Software Development Kit Manager
  # Manages parallel versions of multiple SDKs (Java, Gradle, Maven, Kotlin, Scala, etc.)
  # https://sdkman.io/
  # Note: SDKMAN must be installed manually: curl -s "https://get.sdkman.io" | bash
  # Dependencies: bash or zsh

  home.sessionVariables = {
    SDKMAN_DIR = "${config.home.homeDirectory}/.sdkman";
  };

  # Initialize SDKMAN in zsh (using new initContent structure)
  programs.zsh.initContent = lib.mkAfter ''
    # SDKMAN initialization
    if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
      source "$HOME/.sdkman/bin/sdkman-init.sh"
    fi
  '';

  # Initialize SDKMAN in bash (for compatibility)
  programs.bash.initExtra = lib.mkAfter ''
    # SDKMAN initialization
    if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
      source "$HOME/.sdkman/bin/sdkman-init.sh"
    fi
  '';

  # Shell aliases for common SDKMAN commands
  home.shellAliases = {
    sdki = "sdk install";
    sdku = "sdk use";
    sdkl = "sdk list";
    sdkc = "sdk current";
  };
}
