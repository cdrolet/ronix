# GNOME Games - Collection of GNOME desktop games
#
# Purpose: Install GNOME games collection for individual users.
#
# Design note: services.gnome.games.enable is a NixOS system-level option —
# it installs games for all users system-wide. gnome-core.nix keeps that
# option disabled (lib.mkDefault false) to reduce system size.
# This module installs the same packages at the user level via home.packages,
# so only users who opt in to "gnome-games" get them. No system config clash.
#
# Platform: GNOME desktop environments (NixOS + home-manager)
{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    aisleriot        # Solitaire card games
    gnome-chess      # Chess
    gnome-mahjongg   # Mahjongg tile matching
    gnome-mines      # Minesweeper
    gnome-sudoku     # Sudoku puzzle
    quadrapassel     # Tetris-style
    gnome-tetravex   # Puzzle: match tile edges
    five-or-more     # Connect-five strategy game
    four-in-a-row    # Connect Four
    gnome-klotski    # Sliding block puzzles
    gnome-nibbles    # Snake-style game
    hitori           # Puzzle: eliminate duplicate numbers
    lightsoff        # Lights-off puzzle
    swell-foop       # Color-matching puzzle
    tali             # Yahtzee-style dice game
    atomix           # Molecule assembly puzzle
    gnome-robots     # Robots avoidance game
  ];
}
