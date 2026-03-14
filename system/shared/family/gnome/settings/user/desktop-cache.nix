# Desktop File Cache Refresh
#
# Purpose: Make home-manager installed apps visible to GNOME Shell and
#          keep the FreeDesktop MIME cache fresh after each activation.
#
# Problem: In standalone home-manager, packages land in ~/.nix-profile/.
#          GDM/Wayland sessions do not source the Nix profile environment,
#          so XDG_DATA_DIRS never includes ~/.nix-profile/share. GNOME Shell
#          therefore cannot see any app installed via home.packages.
#
# Fix: Symlink all .desktop files from ~/.nix-profile/share/applications/
#      into ~/.local/share/applications/ which GNOME always scans.
#      Stale symlinks (from removed packages) are cleaned up automatically.
#      Regular files (home-manager managed .desktop entries) are never touched.
#
# Feature: 040-single-reboot-installation (User Story 2)
#
# Platform: GNOME and all FreeDesktop-compliant desktop environments
{
  config,
  lib,
  pkgs,
  ...
}: {
  home.activation.refreshDesktopCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _local_apps="$HOME/.local/share/applications"
    _profile_apps="$HOME/.nix-profile/share/applications"

    $DRY_RUN_CMD mkdir -p "$_local_apps"

    # Symlink nix-profile .desktop files into ~/.local/share/applications/
    # so GNOME Shell sees home-manager installed apps in GDM/Wayland sessions.
    if [ -d "$_profile_apps" ]; then
      for _f in "$_profile_apps"/*.desktop; do
        [ -f "$_f" ] || continue
        _dst="$_local_apps/$(basename "$_f")"
        # Skip regular files — those are explicitly managed by home-manager
        [ -e "$_dst" ] && ! [ -L "$_dst" ] && continue
        $DRY_RUN_CMD ln -sf "$_f" "$_dst"
      done
    fi

    # Remove stale symlinks pointing at nix-profile apps that no longer exist
    for _dst in "$_local_apps"/*.desktop; do
      [ -L "$_dst" ] || continue
      _target="$(readlink "$_dst")"
      [[ "$_target" == "$_profile_apps"* ]] || continue
      [ -e "$_target" ] || $DRY_RUN_CMD rm "$_dst"
    done

    # Update FreeDesktop MIME cache
    run ${pkgs.desktop-file-utils}/bin/update-desktop-database \
      -q "$_local_apps" 2>/dev/null || true
    $VERBOSE_ECHO "Desktop file cache refreshed"
  '';
}
