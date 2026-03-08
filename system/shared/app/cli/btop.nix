{
  config,
  pkgs,
  lib,
  ...
}: {
  # btop - Resource monitor with modern UI
  # Feature-rich process viewer and system monitor
  # Dependencies: None

  programs.btop = {
    enable = true;
    settings = {
      # color_theme managed by stylix
      theme_background = false;
      vim_keys = true;
      update_ms = 1000;
    };
  };

  # Shell alias
  home.shellAliases = {
    top = "${pkgs.btop}/bin/btop";
  };
}
