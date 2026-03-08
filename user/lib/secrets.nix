# Secrets Library and Module
#
# Purpose:
#   1. Library: Helper functions for detecting and resolving "<secret>" placeholders
#   2. Module: Home-manager module for secrets key validation (no agenix, direct rage)
#
# Usage as library (in apps):
#   let
#     secrets = import ../../../../user/lib/secrets.nix { inherit lib pkgs; };
#   in
#     home.activation.applySecrets = secrets.mkActivationScript {
#       inherit config pkgs lib;
#       name = "myapp";
#       fields = { email = ''myapp config set email "$EMAIL"''; };
#     };
#
# Usage as module (in platform libs):
#   (import ./secrets.nix { inherit user repoRoot lib; }).module
#
# Features:
#   - 027: User Colocated Secrets
#   - 029: Nested Secrets Support (sshKeys.personal)
#   - 031: Per-User Secrets (each user has own keypair)
#   - 047: Private config repo (secrets.age NOT committed to git, runtime search)
#
# Runtime path for secrets.age (Feature 047 — private repo mandatory):
#   $HOME/.config/nix-private/users/<name>/secrets.age
{
  lib,
  pkgs ? null,
  # Module-specific parameters (optional)
  user ? null,
  repoRoot ? null,
}: let
  # ============================================================================
  # CONSTANTS
  # ============================================================================
  # The sentinel value that indicates a field should be resolved from secrets
  # This is the ONLY place this value is defined
  placeholder = "<secret>";

  # ============================================================================
  # BASIC DETECTION
  # ============================================================================

  # Check if a value is the secret placeholder
  # Usage: isSecret config.user.email
  isSecret = value:
    builtins.isString value && value == placeholder;

  # ============================================================================
  # PATH UTILITIES
  # ============================================================================

  # Get the path to a user's secrets file (legacy/framework repo layout)
  # Note: secrets.age is NOT committed to git (Feature 047), so pathExists → false
  # Use this only for justfile tooling that accesses the filesystem directly.
  getUserSecretsPath = username: root:
    root + "/${username}/secrets.age";

  # Check if a user has a secrets file (build-time, only works if committed to store)
  userHasSecrets = username: root:
    builtins.pathExists (getUserSecretsPath username root);

  # Get the path to a user's public key (Feature 031)
  getUserPublicKeyPath = username: root:
    root + "/${username}/public.age";

  # Check if a user has a public key (Feature 031)
  userHasPublicKey = username: root:
    builtins.pathExists (getUserPublicKeyPath username root);

  # ============================================================================
  # SECRET DISCOVERY
  # ============================================================================

  # Recursively find all secret placeholders in an attribute set
  # Returns a list of { path = ["nested" "path"]; } for each "<secret>" value
  findSecretPlaceholders = attrs:
    findSecretPlaceholdersWithPath [] attrs;

  findSecretPlaceholdersWithPath = path: value:
    if isSecret value
    then [{inherit path;}]
    else if builtins.isAttrs value
    then
      lib.flatten (
        lib.mapAttrsToList (
          name: val:
            findSecretPlaceholdersWithPath (path ++ [name]) val
        )
        value
      )
    else [];

  # Convert a path list to a dotted string
  pathToString = path:
    lib.concatStringsSep "." path;

  # Convert a dotted string to a path list
  stringToPath = str:
    lib.splitString "." str;

  # Get a nested value from an attribute set using a path list
  getNestedValue = attrs: path:
    lib.foldl' (acc: key: acc.${key}) attrs path;

  # Get a nested value using a dotted string path
  getNestedValueByString = attrs: pathStr:
    getNestedValue attrs (stringToPath pathStr);

  # ============================================================================
  # NESTED PATH HELPERS (Feature 029)
  # ============================================================================

  # Convert a dotted field path to a shell-safe variable name
  # "sshKeys.personal" -> "SSHKEYS_PERSONAL"
  # "email" -> "EMAIL" (backward compatible)
  fieldToVarName = fieldPath:
    lib.toUpper (builtins.replaceStrings ["."] ["_"] fieldPath);

  # Get a nested value from config.user using a dotted path, with default
  # Usage: getNestedConfigValue config "sshKeys.personal" -> value or null
  getNestedConfigValue = config: fieldPath:
    lib.attrByPath (stringToPath fieldPath) null config.user;

  # ============================================================================
  # ACTIVATION HELPERS (require pkgs)
  # ============================================================================

  # Generate a jq command to extract a field from JSON
  # Supports nested paths using getpath() with split(".")
  # Usage in activation script: VALUE=$(${mkJqExtract pkgs "email"} "$JSON")
  # Nested: VALUE=$(${mkJqExtract pkgs "sshKeys.personal"} "$JSON")
  mkJqExtract = pkgs: jsonPath: "${pkgs.jq}/bin/jq -r 'getpath(\"${jsonPath}\" | split(\".\")) // empty'";

  # Shell snippet that locates secrets.age at runtime (Feature 047)
  # Sets _secrets_file to the path (private repo layout — mandatory).
  mkFindSecretsSnippet = username: ''
    _secrets_file="$HOME/.config/nix-private/users/${username}/secrets.age"
  '';

  # Generate an activation script for resolving secrets
  # This creates a properly structured home.activation entry
  #
  # Uses direct rage decryption at runtime — no agenix required (Feature 047).
  # Reads secrets.age from the private repo runtime location (Feature 047 — mandatory).
  #
  # Arguments:
  #   config: The full config object (used to access user.*)
  #   name: Unique name for this activation (e.g., "git", "gh")
  #   fields: Attrset of { fieldName = "shell command"; }
  #     - fieldName: Must match the JSON key in secrets.age AND config.user.fieldName
  #     - Shell command can use $FIELDNAME (uppercase) for the resolved value
  #
  # Example (flat paths - backward compatible):
  #   mkActivationScript {
  #     inherit config pkgs lib;
  #     name = "git";
  #     fields = {
  #       email = ''${pkgs.git}/bin/git config --global user.email "$EMAIL"'';
  #       fullName = ''${pkgs.git}/bin/git config --global user.name "$FULLNAME"'';
  #     };
  #   }
  #
  # Example (nested paths - Feature 029):
  #   mkActivationScript {
  #     inherit config pkgs lib;
  #     name = "ssh";
  #     fields = {
  #       "sshKeys.personal" = ''echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_ed25519'';
  #       "sshKeys.work" = ''echo "$SSHKEYS_WORK" > ~/.ssh/id_ed25519_work'';
  #     };
  #   }
  #
  # How it works:
  #   1. Checks if config.user.fieldPath == "<secret>" (supports nested paths)
  #   2. Searches for secrets.age at runtime filesystem paths
  #   3. Decrypts using rage -d -i ~/.config/agenix/key.txt
  #   4. Extracts field from JSON using jq getpath()
  #   5. Runs the shell command with $VARNAME set to resolved value
  mkActivationScript = {
    config,
    pkgs,
    lib,
    name,
    fields,
  }: let
    # Filter to only fields that are secrets
    # Supports nested paths: config.user.sshKeys.personal via lib.attrByPath
    secretFields =
      lib.filterAttrs (
        fieldPath: _: let
          # Convert dotted path to attribute list for nested lookup
          pathList = stringToPath fieldPath;
          value = lib.attrByPath pathList null config.user;
        in
          isSecret value
      )
      fields;

    hasSecrets = secretFields != {};
    username = config.user.name;
  in
    lib.mkIf hasSecrets (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        ${mkFindSecretsSnippet username}
        _key="$HOME/.config/agenix/key.txt"

        if [ -z "$_secrets_file" ]; then
          echo "[secrets] No secrets.age found for ${name}, skipping"
        elif [ ! -f "$_key" ]; then
          echo "[secrets] No private key at $_key, skipping ${name}"
        else
          _json=$(${pkgs.rage}/bin/rage -d -i "$_key" "$_secrets_file" 2>/dev/null) || {
            echo "[secrets] Failed to decrypt secrets for ${name}"
            _json=""
          }
          if [ -n "$_json" ]; then
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (fieldPath: applyCmd: let
                varName = fieldToVarName fieldPath;
              in ''
                ${varName}=$(echo "$_json" | ${mkJqExtract pkgs fieldPath})
                if [ -n "''${${varName}}" ]; then
                  ${applyCmd}
                  echo "[secrets] ${name}: applied ${fieldPath}"
                fi
              '')
              secretFields)}
          fi
        fi
      ''
    );

  # ============================================================================
  # ERROR MESSAGES
  # ============================================================================

  missingSecretsError = username: ''
    Secret placeholder "${placeholder}" found but no secrets file exists.

    User: ${username}
    Expected file: user/${username}/secrets.age

    To create secrets:
      just secrets-edit ${username}

    Or to initialize the user's keypair first:
      just secrets-init-user ${username}
  '';

  missingPublicKeyError = username: ''
    User secrets exist but no public key found.

    User: ${username}
    Expected file: user/${username}/public.age

    To initialize the user's keypair:
      just secrets-init-user ${username}
  '';

  missingFieldError = {
    username,
    field,
  }: ''
    Secret field not found: '${field}'

    User: ${username}
    File: user/${username}/secrets.age

    Your secrets file must contain this field.
    Edit with: just secrets-edit ${username}

    Or add directly: just secrets-set ${username} ${field} "your-value"
  '';

  # ============================================================================
  # VALIDATION
  # ============================================================================

  # Feature 047: secrets.age is no longer committed to git, so we can only
  # validate the public key (which IS committed) and warn about missing secrets.
  # The secrets file check is skipped since it's a runtime-only file.
  validateSecrets = {
    username,
    repoRoot,
    secretFields,
  }: let
    hasKey = userHasPublicKey username repoRoot;

    # Only warn if public key is missing when user has secret placeholders
    keyErrors =
      if !hasKey && secretFields != []
      then [(missingPublicKeyError username)]
      else [];
  in {
    valid = keyErrors == [];
    errors = keyErrors;
  };

  # ============================================================================
  # MODULE (when imported with user, repoRoot)
  # ============================================================================

  # Creates a home-manager module for secrets infrastructure.
  # Feature 047: No agenix — uses direct rage decryption at activation time.
  # The module validates public key presence and warns about missing private key.
  mkModule = {
    config,
    pkgs,
    lib,
    ...
  }: let
    # Check if user has public key (committed to repo)
    hasPublicKey = userHasPublicKey user repoRoot;

    # Find all "<secret>" placeholders in user config
    secretFields = findSecretPlaceholders config.user;
    hasAnySecrets = secretFields != [];

    # Validate: warn if secret placeholders exist but no public key
    validation = validateSecrets {
      username = user;
      inherit repoRoot secretFields;
    };
    _ =
      if !validation.valid
      then throw (lib.concatStringsSep "\n" validation.errors)
      else null;
  in {
    # Warn at activation if private key is missing but user has secrets
    home.activation.checkSecretsKey = lib.mkIf hasAnySecrets (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        _key="$HOME/.config/agenix/key.txt"
        if [ ! -f "$_key" ]; then
          echo "[secrets] WARNING: User '${user}' has secret fields but no private key at $_key"
          echo "[secrets] Secret-dependent apps will not be configured until the key is added."
          echo "[secrets] Get your key from your password manager and place it at: $_key"
        fi
      ''
    );
  };
in {
  # ============================================================================
  # LIBRARY EXPORTS
  # ============================================================================

  # Constants
  inherit placeholder;

  # Detection
  inherit isSecret;

  # Paths
  inherit getUserSecretsPath userHasSecrets getUserPublicKeyPath userHasPublicKey;

  # Discovery
  inherit findSecretPlaceholders pathToString stringToPath getNestedValue getNestedValueByString;

  # Nested path helpers (Feature 029)
  inherit fieldToVarName getNestedConfigValue;

  # Activation helpers
  inherit mkJqExtract mkActivationScript mkFindSecretsSnippet;

  # Errors
  inherit missingSecretsError missingPublicKeyError missingFieldError;

  # Validation
  inherit validateSecrets;

  # ============================================================================
  # MODULE EXPORT (only available when imported with user and repoRoot)
  # ============================================================================

  module =
    if user != null && repoRoot != null
    then mkModule
    else throw "secrets.nix module requires user and repoRoot parameters";
}
