# GNOME Family: Wallpaper Cycling via systemd User Timer
#
# Purpose: Cycle desktop wallpaper from ~/Pictures/wallpapers/ on a schedule.
#          Uses gsettings to apply wallpaper (both light and dark URI keys).
#          Picks randomly, avoiding repeating the current image.
#
# Requires: user.style.wallpaper.cyclingFrequency set in user config.
# Wallpapers are synced from repo by system/shared/settings/user/wallpaper.nix.
# stylix sets the initial wallpaper from stylix.image at activation.
#
# Timer frequencies: on-login | every-5min | every-30min | hourly | daily
{
  config,
  lib,
  pkgs,
  ...
}: let
  styleCfg = config.user.style or {};
  wpCfg = styleCfg.wallpaper or null;
  hasWallpaper = wpCfg != null;

  cycleFreq =
    if hasWallpaper && (wpCfg.cyclingFrequency or null) != null
    then wpCfg.cyclingFrequency
    else null;

  hasCycling = cycleFreq != null && cycleFreq != "on-login";
  hasLoginCycle = cycleFreq == "on-login";

  # Map frequency to systemd OnCalendar expression
  timerOnCalendar =
    if cycleFreq == "every-5min" then "*:0/5"
    else if cycleFreq == "every-30min" then "*:0/30"
    else if cycleFreq == "hourly" then "hourly"
    else "daily";

  wallpapersDir = "${config.home.homeDirectory}/Pictures/wallpapers";

  cycleScript = pkgs.writeShellScript "gnome-cycle-wallpaper" ''
    dir="${wallpapersDir}"
    [ -d "$dir" ] || exit 0

    current=$(${pkgs.glib}/bin/gsettings get org.gnome.desktop.background picture-uri \
      2>/dev/null | tr -d "'" | sed 's|file://||')

    mapfile -t images < <(find "$dir" -maxdepth 1 -type f \
      \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
      | sort)

    [ "''${#images[@]}" -eq 0 ] && exit 0

    if [ "''${#images[@]}" -eq 1 ]; then
      next="''${images[0]}"
    else
      others=()
      for img in "''${images[@]}"; do
        [ "$img" != "$current" ] && others+=("$img")
      done
      [ "''${#others[@]}" -eq 0 ] && next="''${images[0]}" \
        || next="''${others[RANDOM % ''${#others[@]}]}"
    fi

    uri="file://$next"
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.background picture-uri "$uri"
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
  '';
in
  lib.mkMerge [
    # Timed cycling (every-5min, every-30min, hourly, daily)
    (lib.mkIf hasCycling {
      systemd.user.services.gnome-wallpaper-cycle = {
        Unit = {
          Description = "Cycle GNOME desktop wallpaper";
          After = ["graphical-session.target"];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${cycleScript}";
        };
      };

      systemd.user.timers.gnome-wallpaper-cycle = {
        Unit.Description = "Timer for GNOME wallpaper cycling";
        Timer = {
          OnCalendar = timerOnCalendar;
          Persistent = true; # catch up on missed runs (e.g. machine was off)
        };
        Install.WantedBy = ["timers.target"];
      };
    })

    # on-login: run once at graphical session start
    (lib.mkIf hasLoginCycle {
      systemd.user.services.gnome-wallpaper-cycle = {
        Unit = {
          Description = "Cycle GNOME desktop wallpaper on login";
          After = ["graphical-session.target"];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${cycleScript}";
        };
        Install.WantedBy = ["graphical-session.target"];
      };
    })
  ]
