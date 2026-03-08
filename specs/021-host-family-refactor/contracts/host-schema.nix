# Host Configuration Schema
# Feature: 021-host-family-refactor
# This file documents the expected structure of host configurations

# Host configurations are pure data attribute sets with no imports.
# They reside in: platform/{platform}/host/{name}/default.nix

# Example host configuration:
{ ... }:

{
  # REQUIRED: Host identifier
  # Type: String (non-empty)
  # Purpose: Unique name for this host
  # Example: "home-macmini-m4", "nixos-workstation"
  name = "host-identifier";

  # OPTIONAL: Cross-platform family references
  # Type: Array<String>
  # Purpose: References cross-platform families in platform/shared/family/{name}/
  # Validation: Each family must exist
  # Use case: Share configs across platforms (e.g., ["linux"] for nixos/kali, ["linux", "gnome"] for composition)
  # Note: Darwin hosts typically use [] as macOS configs aren't shared cross-platform
  # Example: ["linux", "gnome"], ["linux"], or []
  family = [];

  # OPTIONAL: Applications to install
  # Type: Array<String>
  # Purpose: List of application names to discover and install
  # Special: ["*"] imports all discovered applications
  # Search order: platform/{platform}/app/ → each family in array → platform/shared/app/
  # Example: ["git", "helix", "zsh"] or ["*"]
  applications = [];

  # OPTIONAL: Settings to apply
  # Type: Array<String>
  # Purpose: List of system settings to apply
  # Special: ["default"] imports all settings from platform/{platform}/settings/
  # Forbidden: ["*"] wildcard is NOT allowed (will throw error)
  # Search order: platform/{platform}/settings/ → each family in array → platform/shared/settings/
  # Example: ["dock", "keyboard", "displays"] or ["default"]
  settings = [];
}

# VALIDATION RULES:
# 1. No imports allowed (pure data only)
# 2. name MUST be non-empty string
# 3. Each family in array MUST exist in platform/shared/family/
# 4. family MAY be empty [] to explicitly disable family resolution
# 5. applications MAY use "*" wildcard
# 6. settings MUST NOT use "*" wildcard (validation error)
# 7. settings MAY use "default" keyword (imports all platform settings)

# EXAMPLES:

# Darwin host (no families - macOS doesn't share cross-platform):
{
  name = "home-macmini-m4";
  family = [];
  applications = ["*"];
  settings = ["default"];
}

# Linux host with single family:
{
  name = "nixos-workstation";
  family = ["linux"];
  applications = ["*"];
  settings = ["default"];
}

# Linux host composing multiple families:
{
  name = "nixos-desktop";
  family = ["linux", "gnome"];  # Compose linux + gnome families
  applications = ["git", "helix", "firefox"];
  settings = ["default"];
}

# Kali host sharing linux family:
{
  name = "kali-pentesting";
  family = ["linux"];  # Shares linux family configs with nixos
  applications = ["*"];
  settings = ["default"];
}

# INVALID EXAMPLES:

# ❌ Has imports (not pure data):
{
  imports = [ ./something.nix ];  # ERROR: No imports allowed
  name = "host";
}

# ❌ Uses "*" for settings:
{
  name = "host";
  settings = ["*"];  # ERROR: Wildcard not allowed for settings
}

# ❌ Empty name:
{
  name = "";  # ERROR: Name cannot be empty
}

# ❌ References non-existent family:
{
  name = "host";
  family = ["nonexistent"];  # ERROR: Family must exist
}

# ❌ Uses family for deployment context (wrong purpose):
{
  name = "host";
  family = ["work", "home"];  # WRONG: Families are for cross-platform sharing (linux, gnome), not deployment contexts
}
