# Qobuz - Hi-res music streaming
#
# Purpose: High-resolution music streaming service
# Platform: macOS only (no official Linux app)
# Website: https://www.qobuz.com/
#
# Features:
#   - Hi-res audio streaming (up to 24-bit/192 kHz)
#   - Lossless FLAC downloads
#   - Editorial content and music discovery
#   - Offline playback
#   - External audio device support
#
# macOS Versions:
#   - Intel processors
#   - Apple Silicon (M1/M2/M3)
#
# Linux Alternatives:
#   - Web player: play.qobuz.com
#   - Wine/Bottles (run Windows app)
#   - No official Linux desktop app available
#
# Installation: Via Homebrew cask
#
# Sources:
#   - https://www.qobuz.com/us-en/discover/apps-qobuz
#   - https://www.viwizard.com/qobuz-music-tips/qobuz-for-linux.html
# Homebrew-only app: cask installed via darwin.nix extraction
# No home-manager configuration needed
{
  lib,
  configContext ? "home-manager",
  ...
}:
lib.optionalAttrs (configContext == "darwin-system") {
  homebrew.casks = ["qobuz"];
}
