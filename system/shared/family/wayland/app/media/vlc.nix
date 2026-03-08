# VLC Media Player - Universal media player
#
# Purpose: Play virtually any audio/video format without extra codecs
# Platform: Linux (via nixpkgs)
# Website: https://www.videolan.org/vlc/
{pkgs, ...}: {
  home.packages = [pkgs.vlc];
}
