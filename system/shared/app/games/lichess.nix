# Lichess - Free Online Chess
#
# Purpose: Access to Lichess.org free chess platform
# Platform: Cross-platform (browser-based)
#
# Lichess is a free, open-source online chess server featuring:
# - Unlimited games with no ads
# - Puzzles, analysis, and training tools
# - All chess variants (standard, chess960, crazyhouse, etc.)
# - Tournaments and simuls
# - Engine analysis with Stockfish
# - Study and opening explorer
#
# Note: Lichess doesn't have an official desktop app
# This module provides easy browser access via shell alias
#
# For desktop app experience:
# - Use your browser's "Install as App" feature (PWA)
# - Or install one of the unofficial Electron wrappers manually
#
# Constitutional: <200 lines, uses lib.mkDefault
#
# Usage:
# Add "lichess" to user.workspace.applications array
# Run 'lichess' in terminal to open in default browser
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Shell aliases to open Lichess in browser
  home.shellAliases = {
    lichess = "xdg-open https://lichess.org 2>/dev/null || open https://lichess.org";
    chess-online = "xdg-open https://lichess.org 2>/dev/null || open https://lichess.org";
  };

  # Note for users
  # To install as PWA (Progressive Web App):
  # - Chrome/Brave/Edge: Visit lichess.org → Menu → "Install Lichess"
  # - Firefox: Visit lichess.org → ... → "Install" or use PWAsForFirefox extension
  # - Safari (macOS): Visit lichess.org → File → "Add to Dock"
}
