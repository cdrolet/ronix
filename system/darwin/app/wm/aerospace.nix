{
  config,
  lib,
  pkgs,
  configContext ? "home-manager",
  ...
}:
lib.mkMerge [
  # System-level installation (collected by darwin.nix)
  # Only declared when in darwin system context (Stage 1)
  (lib.optionalAttrs (configContext == "darwin-system") {
    homebrew.casks = ["nikitabobko/tap/aerospace"];
  })

  # AeroSpace - Tiling window manager for macOS
  # i3-like tiling window manager specifically designed for macOS
  #
  # Installation: Via homebrew cask (system-wide)
  # Configuration: Per-user launch and settings
  #
  # Works well with: window-borders.nix (active window highlighting)
  {
    # Autostart AeroSpace on login (per-user launchd agent via home-manager)
    launchd.agents.aerospace = {
      enable = true;
      config = {
        ProgramArguments = ["/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/aerospace-${config.user.name}.log";
        StandardErrorPath = "/tmp/aerospace-${config.user.name}.err";
      };
    };

    # Configuration file
    xdg.configFile."aerospace/aerospace.toml".text = ''
      # AeroSpace configuration
      # Tiling window manager for macOS

      # Modifier key
      mod = 'cmd'

      # Gaps
      gaps.inner = 8
      gaps.outer = 8

      # Workspace configuration
      [workspaces]
      1 = 'main'
      2 = 'web'
      3 = 'code'
      4 = 'term'
      5 = 'chat'

      # Keybindings
      [keybindings]
      'mod-h' = 'focus left'
      'mod-j' = 'focus down'
      'mod-k' = 'focus up'
      'mod-l' = 'focus right'

      'mod-shift-h' = 'move left'
      'mod-shift-j' = 'move down'
      'mod-shift-k' = 'move up'
      'mod-shift-l' = 'move right'

      'mod-1' = 'workspace 1'
      'mod-2' = 'workspace 2'
      'mod-3' = 'workspace 3'
      'mod-4' = 'workspace 4'
      'mod-5' = 'workspace 5'

      'mod-shift-1' = 'move-to-workspace 1'
      'mod-shift-2' = 'move-to-workspace 2'
      'mod-shift-3' = 'move-to-workspace 3'
      'mod-shift-4' = 'move-to-workspace 4'
      'mod-shift-5' = 'move-to-workspace 5'

      'mod-f' = 'fullscreen'
      'mod-shift-space' = 'toggle floating'
    '';
  }
]
