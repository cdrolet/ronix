# Desktop File Cache Refresh
#
# Purpose: Automatically refresh desktop file cache after home-manager activation
# Platform: GNOME and all FreeDesktop-compliant desktop environments
#
# This ensures GNOME Shell sees all installed applications on first login by
# updating the mimeinfo.cache file after .desktop files are written.
#
# Feature: 040-single-reboot-installation (User Story 2)
#
# How it works:
# - Runs after home-manager writes all .desktop files (writeBoundary phase)
# - Updates FreeDesktop MIME cache mapping file types to applications
# - Non-blocking: Activation succeeds even if cache refresh fails
# - Idempotent: Safe to run on every home-manager activation
#
# Benefits:
# - Apps visible immediately on first login (no 3rd reboot needed)
# - Cache always fresh after installing new applications
# - Works with GNOME, KDE, XFCE, and any FreeDesktop-compliant DE
{
  config,
  lib,
  pkgs,
  ...
}: {
  # This module is in settings/user/ so it's ONLY imported in home-manager context
  # No need for context guards per Feature 039
  # Activation script runs AFTER all files written (writeBoundary phase)
  # This ensures .desktop files exist before we update the cache
  home.activation.refreshDesktopCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Check if desktop applications directory exists
    if [[ -d "$HOME/.local/share/applications" ]]; then
      # Update FreeDesktop MIME cache (maps file types to applications)
      # - Uses desktop-file-utils package (standard FreeDesktop tool)
      # - Runs quietly (-q flag suppresses normal output)
      # - Non-blocking (|| true prevents activation failure on error)
      # - Stderr discarded (2>/dev/null suppresses error messages)
      run ${pkgs.desktop-file-utils}/bin/update-desktop-database \
        -q "$HOME/.local/share/applications" 2>/dev/null || true

      # Informational message (shown in activation log)
      $VERBOSE_ECHO "Desktop file cache refreshed"
    fi
  '';
}
