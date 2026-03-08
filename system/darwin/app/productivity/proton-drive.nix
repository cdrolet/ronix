# Proton Drive - Encrypted cloud storage
#
# Purpose: Secure cloud storage with end-to-end encryption
# Platform: macOS only (Linux app not available yet as of 2026)
# Website: https://proton.me/drive
#
# Features:
#   - End-to-end encrypted file storage
#   - Desktop sync client
#   - Up to 2x faster upload/download speeds (Drive 2.0)
#   - Offline access to synced files
#
# Note: Requires Proton account
# Linux support: Coming in 2026 via SDK
#
# Installation: Via Homebrew cask
#
# Sources:
#   - https://proton.me/drive/download
#   - https://proton.me/blog/proton-drive-macos-app-update
# Homebrew-only app: cask installed via darwin.nix extraction
# No home-manager configuration needed
{
  lib,
  configContext ? "home-manager",
  ...
}:
lib.optionalAttrs (configContext == "darwin-system") {
  homebrew.casks = ["proton-drive"];
}
