# Bitwarden CLI - Command-line password manager
#
# Purpose: Command-line interface for Bitwarden password manager
# Platform: Cross-platform (macOS, Linux, Windows)
# Website: https://bitwarden.com/help/cli/
#
# Features:
#   - Access Bitwarden vault from terminal
#   - Automation and scripting support
#   - Secure password retrieval for scripts
#   - Vault management (create, update, delete items)
#   - Session management with BW_SESSION
#
# Common Commands:
#   - bw login                    # Log in to your vault
#   - bw unlock                   # Unlock vault (get session key)
#   - bw list items               # List all vault items
#   - bw get item <name>          # Get specific item
#   - bw generate                 # Generate password
#
# Usage with Secrets:
#   Used in justfile for storing age keys in Bitwarden
#   See: just secrets-init-user (uses BW_SESSION)
#
# Installation: Via nixpkgs (cross-platform)
#
# Sources:
#   - https://bitwarden.com/download/
#   - https://formulae.brew.sh/formula/bitwarden-cli
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.bitwarden-cli];

  # Shell aliases for common operations
  home.shellAliases = {
    bw-unlock = "export BW_SESSION=$(bw unlock --raw)";
    bw-login = "bw login";
    bw-sync = "bw sync";
    bw-list = "bw list items";
  };

  # Environment variable hints
  # Users should set BW_SESSION after unlocking:
  #   export BW_SESSION=$(bw unlock --raw)
  # or use the bw-unlock alias
}
