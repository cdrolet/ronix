# Email Helper Library
#
# Purpose: Shared email detection functions used across modules
# Usage: let email = import ../../../system/shared/lib/email.nix { inherit lib; };
{lib}: {
  # Check if an email address is a Proton address
  # Handles "<secret>" placeholder (treated as potentially valid)
  # Matches: @proton.me, @protonmail.com, @pm.me
  isProtonEmail = emailValue: let
    hasEmail = emailValue != null;
    isSecret = emailValue == "<secret>";
  in
    hasEmail
    && (isSecret || (builtins.match ".*@(proton\\.me|protonmail\\.com|pm\\.me)" emailValue) != null);
}
