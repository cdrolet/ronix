# Justfile for nix-config repository
# Provides convenient commands for building and installing configurations

# Feature 047: Nix config flake location (mandatory)
# Set NIX_CONFIG_DIR or place config at ~/.config/nix-config
nix_config_dir := env("NIX_CONFIG_DIR", env("HOME") + "/.config/nix-config")

# Feature 048: When running from the nix config flake (inverted arch), it IS the
# root flake — no --override-input needed (it has no user-host-config input).
# The nix config flake's justfile sets RONIX_ROOT_IS_PRIVATE=1 when delegating here.
_config_override := if env("RONIX_ROOT_IS_PRIVATE", "") == "1" { "" } else { "--override-input user-host-config path:" + nix_config_dir }

# Default recipe - show available commands
default:
    @just --list

# Discover users from nix config flake
_discover-users:
    #!/usr/bin/env bash
    for dir in "{{ nix_config_dir }}/users"/*/; do
        if [ -d "$dir" ]; then
            basename "$dir"
        fi
    done | sort

# Discover hosts for a specific system from nix config flake
_discover-hosts system:
    #!/usr/bin/env bash
    for dir in "{{ nix_config_dir }}/hosts/{{ system }}"/*/; do
        if [ -d "$dir" ]; then
            basename "$dir"
        fi
    done | sort

# Validate user against discovered users
_validate-user user:
    #!/usr/bin/env bash
    valid_users=$(just _discover-users | tr '\n' ' ')
    if [[ ! " $valid_users " =~ " {{ user }} " ]]; then
        echo "Error: Invalid user '{{ user }}'"
        echo "Valid users: $valid_users"
        exit 1
    fi

# Get user configuration directory (nix config flake — Feature 047)
_user-config-dir user:
    @echo "{{ nix_config_dir }}/users/{{ user }}"

# Validate system exists (discovered from filesystem)
_validate-system system:
    #!/usr/bin/env bash
    if [ ! -d "{{ nix_config_dir }}/hosts/{{ system }}" ]; then
        echo "Error: System '{{ system }}' not found"
        echo "Available systems:"
        for dir in "{{ nix_config_dir }}/hosts"/*/; do
            [ -d "$dir" ] && basename "$dir"
        done
        exit 1
    fi

# Validate host exists for the given system
_validate-host-for-system system host:
    #!/usr/bin/env bash
    valid_hosts=$(just _discover-hosts {{ system }} | tr '\n' ' ')
    if [[ ! " $valid_hosts " =~ " {{ host }} " ]]; then
        echo "Error: Invalid host '{{ host }}' for system '{{ system }}'"
        echo "Valid hosts for {{ system }}: $valid_hosts"
        exit 1
    fi

# Common validation for all operations
_validate-all user system host:
    @just _validate-user {{ user }}
    @just _validate-system {{ system }}
    @just _validate-host-for-system {{ system }} {{ host }}

# Get the flake output path for a system configuration
# Returns the nix build target path for the given system

# To add a new system: Add a case here with the system's flake output path
_flake-output-path system user host:
    #!/usr/bin/env bash
    if [ "{{ system }}" = "darwin" ]; then
        echo "darwinConfigurations.{{ user }}-{{ host }}.system"
    else
        echo "nixosConfigurations.{{ user }}-{{ host }}.config.system.build.toplevel"
    fi

# Get the activation script path for a system
# Returns the path to the activation script within the build result

# To add a new system: Add a case here with the activation script location
_activation-script-path system:
    #!/usr/bin/env bash
    if [ "{{ system }}" = "darwin" ]; then
        echo "result/sw/bin/darwin-rebuild"
    else
        echo "result/bin/switch-to-configuration"
    fi

# Execute a system-specific rebuild command
# Usage: _rebuild-command <system> <command-type> <user> <host>

# command-type: "build", "switch", etc.
_rebuild-command system command_type user host:
    #!/usr/bin/env bash
    if [ "{{ command_type }}" = "build" ]; then
        # Use system-agnostic nix build command
        output_path=$(just _flake-output-path {{ system }} {{ user }} {{ host }})
        nix build ".#${output_path}" {{ _config_override }} --show-trace
    else
        # Use activation script from build result
        if [ ! -L "result" ]; then
            echo "Error: Build result not found. Run 'just build {{ user }} {{ system }} {{ host }}' first."
            exit 1
        fi

        # Get system-specific activation script path
        script=$(just _activation-script-path {{ system }})

        # Execute activation script with system-specific arguments
        # Both darwin and nixos now require sudo for system activation
        if [ "{{ system }}" = "darwin" ]; then
            # Darwin activation script requires flake reference
            sudo "$script" {{ command_type }} --flake ".#{{ user }}-{{ host }}" --show-trace
        else
            # NixOS activation script only needs command type
            sudo "$script" {{ command_type }}
        fi
    fi

# Detect current system
_detect-system:
    #!/usr/bin/env bash
    case "$(uname -s)" in
        Darwin) echo "darwin" ;;
        Linux)  echo "linux" ;;
        *)      echo "Error: Unsupported system $(uname -s)" >&2; exit 1 ;;
    esac

# List all valid users (discovered from filesystem)
list-users:
    @echo "Valid users:"
    @just _discover-users

# List all hosts organized by system (from nix config flake)
list-hosts:
    #!/usr/bin/env bash
    echo "Available hosts by system:"
    echo "=========================="
    for system_dir in "{{ nix_config_dir }}/hosts"/*/; do
        if [ -d "$system_dir" ]; then
            sys=$(basename "$system_dir")
            echo ""
            echo "$sys:"
            for host_dir in "$system_dir"*/; do
                if [ -d "$host_dir" ]; then
                    echo "  - $(basename "$host_dir")"
                fi
            done
        fi
    done

# List all valid combinations of users and hosts
list-combinations:
    #!/usr/bin/env bash
    echo "Available user-host combinations:"
    echo "=================================="
    users=$(just _discover-users)
    for system_dir in "{{ nix_config_dir }}/hosts"/*/; do
        if [ -d "$system_dir" ]; then
            sys=$(basename "$system_dir")
            for host_dir in "$system_dir"*/; do
                if [ -d "$host_dir" ]; then
                    host=$(basename "$host_dir")
                    for user in $users; do
                        echo "  just build $user $host  # $sys (auto-detected)"
                    done
                fi
            done
        fi
    done
    echo ""
    echo "Usage examples:"
    echo "  just build <user> <host>    # System auto-detected from host"
    echo "  just install <user> <host>"
    echo "  just diff <user> <host>"

# Run flake check to validate configuration
check:
    @echo "Running flake check..."
    @nix flake check

# Format all files using treefmt (nix, markdown, shell, json, yaml, toml)
fmt:
    @echo "Formatting all files..."
    @nix fmt
    @echo "Formatting complete!"

# Check formatting without modifying files (useful for CI)
fmt-check:
    @echo "Checking formatting..."
    @nix fmt -- --fail-on-change
    @echo "All files are properly formatted!"

# Auto-detect system from host (searches nix config flake)
# Returns: darwin, nixos, or error
_auto-detect-system host:
    #!/usr/bin/env bash
    for system_dir in "{{ nix_config_dir }}/hosts"/*/; do
        if [ -d "${system_dir}{{ host }}" ]; then
            basename "$system_dir"
            exit 0
        fi
    done
    echo "Error: Host '{{ host }}' not found in any system" >&2
    echo "Available hosts:" >&2
    for system_dir in "{{ nix_config_dir }}/hosts"/*/; do
        sys=$(basename "$system_dir")
        for host_dir in "$system_dir"*/; do
            [ -d "$host_dir" ] && echo "  - $(basename "$host_dir") ($sys)" >&2
        done
    done
    exit 1

# Auto-detect user if only one exists
_auto-detect-user:
    #!/usr/bin/env bash
    users=$(just _discover-users)
    count=$(echo "$users" | wc -l | tr -d ' ')
    if [ "$count" = "1" ]; then
        echo "$users"
    else
        echo "Error: Multiple users found. Please specify user." >&2
        echo "Available users: $(echo $users | tr '\n' ' ')" >&2
        exit 1
    fi

# Auto-detect host if only one exists in the detected system
_auto-detect-host system:
    #!/usr/bin/env bash
    hosts=$(just _discover-hosts {{ system }})
    count=$(echo "$hosts" | wc -l | tr -d ' ')
    if [ "$count" = "1" ]; then
        echo "$hosts"
    else
        echo "Error: Multiple hosts found for system {{ system }}. Please specify host." >&2
        echo "Available hosts: $(echo $hosts | tr '\n' ' ')" >&2
        exit 1
    fi

# Build a configuration without installing
# Usage: just build [user] [host]
# If user omitted: auto-detects if only one user exists
# If host omitted: auto-detects if only one host exists for the system
# Example: just build cdrokar home-macmini-m4

# Example: just build (auto-detects both if only one of each)
build user="" host="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Auto-detect user if not provided
    if [ -z "{{ user }}" ]; then
        USER=$(just _auto-detect-user)
        echo "Auto-detected user: $USER"
    else
        USER="{{ user }}"
    fi

    # Auto-detect host if not provided
    if [ -z "{{ host }}" ]; then
        # First need to know which system to check
        # Try to detect from current system
        current_sys=$(just _detect-system)
        HOST=$(just _auto-detect-host "$current_sys")
        echo "Auto-detected host: $HOST (system: $current_sys)"
        system="$current_sys"
    else
        HOST="{{ host }}"
        # Auto-detect system from host
        system=$(just _auto-detect-system "$HOST")
    fi

    # Validate
    just _validate-all "$USER" "$system" "$HOST"

    echo "Building configuration for $USER on $system with host $HOST..."
    echo ""

    # Feature 036: Build both system and user configurations
    # Nix options for large downloads
    NIX_OPTS="{{ _config_override }}"

    # System build
    echo "===> Step 1/2: Building system configuration..."
    if [ "$system" = "darwin" ]; then
        nix build ".#darwinConfigurations.$USER-$HOST.system" --show-trace $NIX_OPTS
    else
        nix build ".#nixosConfigurations.$USER-$HOST.config.system.build.toplevel" --show-trace $NIX_OPTS
    fi
    echo "✓ System build complete"
    echo ""

    # User build (home-manager standalone)
    echo "===> Step 2/2: Building user configuration..."

    # Check for agenix private key before building
    AGENIX_KEY_PATH="$HOME/.config/agenix/key.txt"
    USER_SECRETS_FILE="{{ nix_config_dir }}/users/$USER/secrets.age"

    if [ -f "$USER_SECRETS_FILE" ] && [ ! -f "$AGENIX_KEY_PATH" ]; then
        echo ""
        echo "⚠️  WARNING: User '$USER' has encrypted secrets but no private key found."
        echo "   Private key location: $AGENIX_KEY_PATH"
        echo "   Secret-dependent configurations will fail during activation."
        echo ""
        echo "   To add the key, create the file with:"
        echo "     mkdir -p ~/.config/agenix && nano ~/.config/agenix/key.txt"
        echo ""
    fi

    nix build ".#homeConfigurations.\"$USER@$HOST\".activationPackage" --show-trace $NIX_OPTS
    echo "✓ User build complete"
    echo ""

    echo "Build successful!"
    echo "  System: $system configuration for $HOST"
    echo "  User: home-manager configuration for $USER"

# Install a configuration (Feature 036: dual-mode - system + user)
# Usage: just install [user] [host]
# If user omitted: auto-detects if only one user exists
# If host omitted: auto-detects if only one host exists for the system
# Example: just install cdrokar home-macmini-m4

# Example: just install (auto-detects both if only one of each)
install user="" host="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Auto-detect user if not provided
    if [ -z "{{ user }}" ]; then
        USER=$(just _auto-detect-user)
        echo "Auto-detected user: $USER"
    else
        USER="{{ user }}"
    fi

    # Auto-detect host if not provided
    if [ -z "{{ host }}" ]; then
        # First need to know which system to check
        # Try to detect from current system
        current_sys=$(just _detect-system)
        HOST=$(just _auto-detect-host "$current_sys")
        echo "Auto-detected host: $HOST (system: $current_sys)"
        system="$current_sys"
    else
        HOST="{{ host }}"
        # Auto-detect system from host
        system=$(just _auto-detect-system "$HOST")
    fi

    # Validate
    just _validate-all "$USER" "$system" "$HOST"

    echo "Installing configuration for $USER on $system with host $HOST..."
    echo ""

    # Feature 036: Run both system and user activation
    # Nix options for large downloads
    NIX_OPTS="{{ _config_override }}"

    # Install Homebrew if missing on darwin (required for cask apps)
    if [ "$system" = "darwin" ] && ! command -v brew &>/dev/null; then
        echo "===> Installing Homebrew (required for darwin system activation)..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    # Build configurations
    echo "===> Building configurations..."
    if [ "$system" = "darwin" ]; then
        nix build ".#darwinConfigurations.$USER-$HOST.system" --show-trace $NIX_OPTS -o result-system
    else
        nix build ".#nixosConfigurations.$USER-$HOST.config.system.build.toplevel" --show-trace $NIX_OPTS -o result-system
    fi
    nix build ".#homeConfigurations.\"$USER@$HOST\".activationPackage" --show-trace $NIX_OPTS -o result-user
    echo ""

    # Step 1: System activation
    echo "===> Step 1/2: Activating system configuration..."
    if [ "$system" = "darwin" ]; then
        # nix-darwin needs to manage /etc/zshenv; rename the stock macOS file if present
        if [ -f /etc/zshenv ] && ! grep -q "nix-darwin" /etc/zshenv 2>/dev/null; then
            echo "Moving /etc/zshenv to /etc/zshenv.before-nix-darwin (required by nix-darwin)..."
            sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin
        fi
        sudo ./result-system/sw/bin/darwin-rebuild activate --flake ".#$USER-$HOST"
    else
        sudo ./result-system/bin/switch-to-configuration switch
    fi
    echo "✓ System activation complete"
    echo ""

    # Step 2: User activation (home-manager standalone)
    echo "===> Step 2/2: Activating user configuration..."
    ./result-user/activate
    echo "✓ User activation complete"
    echo ""

    echo "Installation complete!"
    echo "  System: $system configuration for $HOST"
    echo "  User: home-manager configuration for $USER"

# Install only home-manager configuration (user space only)
# Usage: just install-home [user] [host]
# Useful for first-boot setup on NixOS after fresh install

# Example: just install-home cdrokar qemu-gnome-vm
install-home user="" host="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Nix options for large downloads
    NIX_OPTS="{{ _config_override }}"

    # Auto-detect user if not provided
    if [ -z "{{ user }}" ]; then
        USER=$(just _auto-detect-user)
        echo "Auto-detected user: $USER"
    else
        USER="{{ user }}"
    fi

    # Auto-detect host if not provided
    if [ -z "{{ host }}" ]; then
        current_sys=$(just _detect-system)
        HOST=$(just _auto-detect-host "$current_sys")
        echo "Auto-detected host: $HOST"
    else
        HOST="{{ host }}"
    fi

    echo "Installing home-manager configuration for $USER@$HOST..."
    echo ""

    # Build home-manager configuration
    echo "===> Building home-manager configuration..."
    nix build ".#homeConfigurations.\"$USER@$HOST\".activationPackage" --show-trace $NIX_OPTS
    echo "✓ Build complete"
    echo ""

    # Activate home-manager
    echo "===> Activating home-manager..."
    ./result/activate
    echo "✓ Activation complete"
    echo ""

    # Cleanup
    rm -f result

    echo "Home-manager installation complete!"
    echo "You may need to restart your shell: exec $SHELL"

# Update flake inputs
update:
    @echo "Updating flake inputs..."
    @nix flake update
    @echo "Update complete!"

# Update a specific input
update-input input:
    @echo "Updating {{ input }}..."
    @nix flake lock --update-input {{ input }}
    @echo "Update complete!"

# Clean old generations and garbage collect
clean:
    @echo "Cleaning old generations..."
    @sys=$(just _detect-system) && \
        if [ "$sys" = "darwin" ]; then \
            nix-collect-garbage -d; \
            darwin-rebuild --list-generations | head -10; \
        else \
            sudo nix-collect-garbage -d; \
        fi
    @echo "Cleanup complete!"

# Clean all caches (evaluation cache, flake metadata, etc.)
clean-cache:
    @echo "Cleaning Nix caches..."
    @rm -rf ~/.cache/nix/eval-cache-v* || true
    @rm -rf ~/.cache/nix/flake-* || true
    @rm -rf ~/.cache/nix/fetchers || true
    @echo "Cache cleanup complete!"

# Clone or update the nix config flake
# Usage: just private-clone <git-url>
# Example: just private-clone git@github.com:you/private-config
private-clone url:
    #!/usr/bin/env bash
    NIX_CONFIG_DIR_LOCAL="{{ nix_config_dir }}"
    if [ -d "$NIX_CONFIG_DIR_LOCAL" ]; then
        echo "Updating nix config flake at $NIX_CONFIG_DIR_LOCAL..."
        git -C "$NIX_CONFIG_DIR_LOCAL" pull
    else
        echo "Cloning nix config flake to $NIX_CONFIG_DIR_LOCAL..."
        git clone "{{ url }}" "$NIX_CONFIG_DIR_LOCAL"
    fi
    echo "Nix config flake ready at $NIX_CONFIG_DIR_LOCAL"

# Fresh build - clean caches then build
# Usage: just fresh-build [user] [host]

# Clears evaluation cache and flake metadata before building
fresh-build user="" host="":
    @echo "Fresh build: cleaning caches first..."
    @just clean-cache
    @echo ""
    @just build {{ user }} {{ host }}

# Fresh install - pull both repos, clean caches, then install
# Usage: just fresh-install [user] [host]
fresh-install user="" host="":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Pulling framework repo..."
    git pull
    if [ -d "{{ nix_config_dir }}" ]; then
        echo "==> Pulling nix config flake..."
        git -C "{{ nix_config_dir }}" pull
    fi
    just clean-cache
    just install {{ user }} {{ host }}

# Show the diff between current and new configuration
# Usage: just diff [user] [host]
# If user omitted: auto-detects if only one user exists
# If host omitted: auto-detects if only one host exists for the system
# Example: just diff cdrokar home-macmini-m4

# Example: just diff (auto-detects both if only one of each)
diff user="" host="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Auto-detect user if not provided
    if [ -z "{{ user }}" ]; then
        USER=$(just _auto-detect-user)
        echo "Auto-detected user: $USER"
    else
        USER="{{ user }}"
    fi

    # Auto-detect host if not provided
    if [ -z "{{ host }}" ]; then
        # First need to know which system to check
        # Try to detect from current system
        current_sys=$(just _detect-system)
        HOST=$(just _auto-detect-host "$current_sys")
        echo "Auto-detected host: $HOST (system: $current_sys)"
        system="$current_sys"
    else
        HOST="{{ host }}"
        # Auto-detect system from host
        system=$(just _auto-detect-system "$HOST")
    fi

    # Validate
    just _validate-all "$USER" "$system" "$HOST"

    echo "Showing diff for $USER on $system with host $HOST..."
    echo ""

    # Feature 036: Show diffs for both system and user configurations
    # Nix options for large downloads
    NIX_OPTS="{{ _config_override }}"

    # System diff
    echo "===> Step 1/2: System configuration diff..."
    if [ "$system" = "darwin" ]; then
        nix build ".#darwinConfigurations.$USER-$HOST.system" --show-trace $NIX_OPTS
        nix store diff-closures /run/current-system ./result
    else
        nix build ".#nixosConfigurations.$USER-$HOST.config.system.build.toplevel" --show-trace $NIX_OPTS
        nix store diff-closures /run/current-system ./result
    fi
    echo ""

    # User diff
    echo "===> Step 2/2: User configuration diff..."
    nix build ".#homeConfigurations.\"$USER@$HOST\".activationPackage" --show-trace $NIX_OPTS
    # Find current home-manager generation
    current_gen=$(readlink -f ~/.local/state/nix/profiles/home-manager 2>/dev/null || echo "")
    if [ -n "$current_gen" ] && [ -e "$current_gen" ]; then
        nix store diff-closures "$current_gen" ./result
    else
        echo "No previous home-manager generation found - this will be the first activation"
    fi

# Build and push to Cachix in one command (Feature 034: Cachix Integration)
# Usage: just build-and-push [user] [host]
# Only pushes if user has configured user.cachix.authToken

# Example: just build-and-push cdrokar home-macmini-m4
build-and-push user="" host="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Auto-detect user if not provided
    if [ -z "{{ user }}" ]; then
        USER=$(just _auto-detect-user)
        echo "Auto-detected user: $USER"
    else
        USER="{{ user }}"
    fi

    # Auto-detect host if not provided
    if [ -z "{{ host }}" ]; then
        # First need to know which system to check
        # Try to detect from current system
        current_sys=$(just _detect-system)
        HOST=$(just _auto-detect-host "$current_sys")
        echo "Auto-detected host: $HOST (system: $current_sys)"
        system="$current_sys"
    else
        HOST="{{ host }}"
        # Auto-detect system from host
        system=$(just _auto-detect-system "$HOST")
    fi

    # Validate
    just _validate-all "$USER" "$system" "$HOST"

    # Step 1: Build the configuration (Feature 036: dual-mode)
    # Nix options for large downloads
    NIX_OPTS="{{ _config_override }}"

    echo "Building configuration for $USER on $system with host $HOST..."
    echo ""

    echo "===> Step 1/2: Building system configuration..."
    if [ "$system" = "darwin" ]; then
        nix build ".#darwinConfigurations.$USER-$HOST.system" --show-trace $NIX_OPTS
    else
        nix build ".#nixosConfigurations.$USER-$HOST.config.system.build.toplevel" --show-trace $NIX_OPTS
    fi
    echo "✓ System build complete"
    echo ""

    echo "===> Step 2/2: Building user configuration..."
    nix build ".#homeConfigurations.\"$USER@$HOST\".activationPackage" --show-trace $NIX_OPTS
    echo "✓ User build complete"
    echo ""

    echo "Build successful!"

    # Step 2: Check if user has Cachix write access configured
    user_config="{{ nix_config_dir }}/users/$USER/default.nix"

    # Check if user config has security.cachixAuthToken set to "<secret>"
    if grep -q 'cachixAuthToken.*=.*"<secret>"' "$user_config" 2>/dev/null; then
        echo ""
        echo "User has Cachix write access configured, pushing to cache..."

        # Extract cache name from user config (defaults to "default")
        cache_name=$(grep -A 5 'cachix.*{' "$user_config" | grep 'cacheName' | sed 's/.*cacheName.*=.*"\([^"]*\)".*/\1/' || echo "default")

        # Check if netrc file exists (generated by activation)
        netrc_file="$HOME/.config/nix/netrc"
        if [ ! -f "$netrc_file" ]; then
            echo "Warning: $netrc_file not found"
            echo "This should be generated during activation. Did you run 'just install' first?"
            echo "Skipping push..."
        else
            # Push to Cachix using the configured cache name
            echo "Pushing to ${cache_name}.cachix.org..."
            if command -v cachix &> /dev/null; then
                cachix push "$cache_name" ./result
                echo "Push successful!"
            else
                echo "Error: cachix command not found"
                echo "Install with: nix-env -iA nixpkgs.cachix"
                exit 1
            fi
        fi
    else
        echo ""
        echo "User does not have Cachix write access configured."
        echo "Build complete (no push)."
        echo ""
        echo "To enable push access:"
        echo "  1. Get write token from: https://app.cachix.org/personal-auth-tokens"
        echo "  2. Add to user config (user/$USER/default.nix) under security:"
        echo "       security = {"
        echo "         cachixAuthToken = \"<secret>\";"
        echo "       };"
        echo "  3. Store secret: just secrets-set $USER security.cachixAuthToken \"your-token\""
        echo "  4. Activate: just install $USER $HOST"
        echo "  5. Then run: just build-and-push $USER $HOST"
    fi

# ============================================================================
# USER MANAGEMENT (Feature 031: Per-User Secrets)
# ============================================================================
# Create a new user interactively

# Usage: just user-create
user-create:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Creating new user..."
    echo ""

    # Prompt for username
    read -p "Username: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty"
        exit 1
    fi

    # Create user in nix config flake (mandatory — Feature 047)
    user_dir="{{ nix_config_dir }}/users/$username"

    # Check if user already exists
    if [ -d "$user_dir" ]; then
        echo "Error: User '$username' already exists at $user_dir"
        exit 1
    fi

    # Validate username (alphanumeric, underscore, hyphen only)
    if ! echo "$username" | grep -qE '^[a-z0-9_-]+$'; then
        echo "Error: Username must contain only lowercase letters, numbers, underscores, and hyphens"
        exit 1
    fi

    # Prompt for email
    read -p "Email: " email
    if [ -z "$email" ]; then
        echo "Error: Email cannot be empty"
        exit 1
    fi

    # Validate email format
    if ! echo "$email" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
        echo "Error: Invalid email format"
        exit 1
    fi

    # Prompt for full name (optional)
    read -p "Full name (leave empty to use '$username'): " fullname
    if [ -z "$fullname" ]; then
        fullname="$username"
    fi

    # Prompt for password
    echo ""
    read -sp "Password (will be stored encrypted): " password
    echo ""
    read -sp "Confirm password: " password_confirm
    echo ""

    if [ -z "$password" ]; then
        echo "Error: Password cannot be empty"
        rm -rf "$user_dir" 2>/dev/null || true
        exit 1
    fi

    if [ "$password" != "$password_confirm" ]; then
        echo "Error: Passwords do not match"
        rm -rf "$user_dir" 2>/dev/null || true
        exit 1
    fi

    # Select template
    echo ""
    echo "Select template:"
    echo "  1) basic-english (default) - Basic applications for everyday use (English)"
    echo "  2) basic-french - Basic applications for everyday use (French)"
    echo "  3) developer - Comprehensive development toolset"
    read -p "Template [1]: " template_choice
    template_choice=${template_choice:-1}

    case "$template_choice" in
        1) template="basic-english" ;;
        2) template="basic-french" ;;
        3) template="developer" ;;
        *) echo "Invalid choice, using basic-english"; template="basic-english" ;;
    esac

    template_file="user/template/${template}.nix"
    if [ ! -f "$template_file" ]; then
        echo "Error: Template file not found: $template_file"
        exit 1
    fi

    # Create user directory
    mkdir -p "$user_dir"

    # Generate config from template
    echo ""
    echo "Generating user configuration from $template template..."

    # Read template and substitute placeholders
    # Define placeholder strings (avoiding just variable syntax conflicts)
    USERNAME_PH="{{ "{{" }}USERNAME{{ "}}" }}"
    EMAIL_PH="{{ "{{" }}EMAIL{{ "}}" }}"
    FULLNAME_PH="{{ "{{" }}FULLNAME{{ "}}" }}"

    # Using a simple approach: read line by line and do string replacement
    while IFS= read -r line; do
        # Check if line contains any placeholders
        if [[ "$line" == *"$USERNAME_PH"* ]] || [[ "$line" == *"$EMAIL_PH"* ]] || [[ "$line" == *"$FULLNAME_PH"* ]]; then
            # Replace USERNAME
            line="${line//$USERNAME_PH/$username}"
            # Replace EMAIL
            line="${line//$EMAIL_PH/$email}"
            # Handle FULLNAME
            if [[ "$line" == *"$FULLNAME_PH"* ]]; then
                if [ "$fullname" = "$username" ]; then
                    # Skip this line
                    continue
                else
                    # Replace with actual fullName
                    line="${line//$FULLNAME_PH/fullName = \"$fullname\";}"
                fi
            fi
        fi
        echo "$line"
    done < "$template_file" > "$user_dir/default.nix"

    echo ""
    echo "User configuration created!"
    echo "  Username: $username"
    echo "  Email: $email"
    [ "$fullname" != "$username" ] && echo "  Full name: $fullname"
    echo "  Template: $template"
    echo "  Config: $user_dir/default.nix"
    echo ""

    # Initialize encryption keypair
    echo "Initializing encryption keypair..."
    if ! just secrets-init-user "$username"; then
        echo "Error: Failed to initialize encryption keypair"
        rm -rf "$user_dir"
        exit 1
    fi
    echo ""

    # Store secrets
    echo "Storing secrets..."
    just secrets-set "$username" email "$email"
    just _hash-and-store-password "$username" "$password"

    if [ "$fullname" != "$username" ]; then
        just secrets-set "$username" fullName "$fullname"
    fi

    echo ""
    echo "User created successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Review and customize: $user_dir/default.nix"
    echo "  2. Build configuration: just build $username <host>"
    echo ""
    echo "Secrets have been initialized and stored in:"
    echo "  Public key: $user_dir/public.age"
    echo "  Encrypted secrets: $user_dir/secrets.age"
    echo "  Private key: ~/.config/agenix/key.txt (KEEP SECURE!)"

# ============================================================================
# SECRET MANAGEMENT (Feature 031: Per-User Secrets)
# ============================================================================
#
# Design: Per-user key model
#   - user/{name}/public.age (committed)
#   - ~/.config/agenix/key.txt (private, not committed)
#   - user/{name}/secrets.age (colocated with user config)
#
# Benefits:
#   - Each user has their own encryption keypair
#   - Per-user key rotation and revocation
#   - Better security isolation between users
# Hash a password and store it in user secrets (private helper)
# Bypasses secrets-set to avoid just mangling $6$ hash with template interpolation

# Usage: just _hash-and-store-password <user> <plaintext-password>
_hash-and-store-password user password:
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v openssl &>/dev/null; then
        echo "Error: openssl not found"
        exit 1
    fi

    user_dir=$(just _user-config-dir {{ user }})
    pub_path="$user_dir/public.age"
    key_path="$HOME/.config/agenix/key.txt"
    secret_file="$user_dir/secrets.age"

    if [ ! -f "$pub_path" ]; then
        echo "Error: $pub_path not found. Run 'just secrets-init-user {{ user }}' first"
        exit 1
    fi
    if [ ! -f "$key_path" ]; then
        echo "Error: Private key not found at $key_path"
        exit 1
    fi

    pubkey=$(cat "$pub_path")

    # Auto-create empty secrets file if missing
    if [ ! -f "$secret_file" ]; then
        echo '{}' | nix shell nixpkgs#age -c age -r "$pubkey" -o "$secret_file"
    fi

    # Hash password (stays as shell variable — never passed through just)
    password_hash=$(openssl passwd -6 "{{ password }}")

    # Decrypt, update password field, re-encrypt
    decrypted=$(nix shell nixpkgs#age -c age -d -i "$key_path" "$secret_file")
    updated=$(echo "$decrypted" | nix shell nixpkgs#jq -c jq --arg v "$password_hash" '.security.password = $v')
    echo "$updated" | nix shell nixpkgs#age -c age -r "$pubkey" -o "$secret_file"

    echo "Password hash stored in $secret_file"

# Initialize age keypair for a user
# Creates user/{name}/public.age and private key at ~/.config/agenix/key.txt

# Usage: just secrets-init-user <user>
secrets-init-user user:
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate user exists (nix config flake — Feature 047)
    user_dir=$(just _user-config-dir {{ user }})
    if [ ! -d "$user_dir" ]; then
        echo "Error: User '{{ user }}' not found at $user_dir"
        echo "Create user first: just user-create"
        exit 1
    fi
    key_path="$HOME/.config/agenix/key.txt"
    pub_path="$user_dir/public.age"

    # Check if already initialized
    if [ -f "$pub_path" ]; then
        echo "User {{ user }} already has a keypair."
        echo "Public key (user/{{ user }}/public.age):"
        cat "$pub_path"
        echo ""
        if [ -f "$key_path" ]; then
            echo "Private key exists at: $key_path"
        else
            echo "Warning: Private key not found at $key_path"
            echo "Restore it from backup or run 'just secrets-rotate-user {{ user }}' to generate a new one."
        fi
        exit 0
    fi

    # Generate new keypair
    echo "Initializing keypair for user {{ user }}..."
    mkdir -p "$(dirname "$key_path")"
    # Generate key and extract public key
    nix shell nixpkgs#age -c age-keygen -o "$key_path" 2>&1 | grep "Public key:" | cut -d: -f2 | tr -d ' ' > "$pub_path"
    echo ""
    echo "Keypair generated successfully!"
    echo ""
    echo "  Public key:  $pub_path (commit this)"
    echo "  Private key: $key_path (keep secret)"
    echo ""
    echo "Distribution options:"
    echo ""
    echo "  Option 1 - Bitwarden CLI (recommended):"
    echo "    # Login to Bitwarden"
    echo "    bw login"
    echo "    export BW_SESSION=\$(bw unlock --raw)"
    echo ""
    echo "    # Save private key as secure note"
    echo "    bw get template item | jq '"
    echo "      .type = 2 |"
    echo "      .secureNote.type = 0 |"
    echo "      .name = \"{{ user }} - nix-config age key\" |"
    echo "      .notes = \"'\$(cat $key_path)'\" |"
    echo "      .fields = [{name: \"username\", value: \"{{ user }}\", type: 0}]"
    echo "    ' | bw encode | bw create item"
    echo ""
    echo "  Option 2 - Manual distribution:"
    echo "    # Copy to other machines (macOS example):"
    echo "    scp $key_path other-machine:~/.config/agenix/"
    echo ""
    echo "  Option 3 - Environment variable (CI/CD):"
    echo "    # Store in secure environment variable"
    echo "    export AGENIX_KEY=\$(cat $key_path)"
    echo ""
    echo "Next steps:"
    echo "  1. Commit users/{{ user }}/public.age to the nix config flake"
    echo "  2. Distribute private key using one of the options above"
    echo "  3. Add secrets: just secrets-set {{ user }} <field> <value>"

# Show a user's public key

# Usage: just secrets-show-pubkey <user>
secrets-show-pubkey user:
    #!/usr/bin/env bash
    set -euo pipefail

    user_dir=$(just _user-config-dir {{ user }})
    pub_path="$user_dir/public.age"
    if [ -f "$pub_path" ]; then
        cat "$pub_path"
    else
        echo "Error: $pub_path not found"
        echo "Run 'just secrets-init-user {{ user }}' to create the keypair"
        exit 1
    fi

# Rotate a user's encryption key (generates new keypair, re-encrypts secrets)

# Usage: just secrets-rotate-user <user>
secrets-rotate-user user:
    #!/usr/bin/env bash
    set -euo pipefail

    user_dir=$(just _user-config-dir {{ user }})
    if [ ! -d "$user_dir" ]; then
        echo "Error: User '{{ user }}' not found at $user_dir"
        exit 1
    fi

    key_path="$HOME/.config/agenix/key.txt"
    pub_path="$user_dir/public.age"
    secret_path="$user_dir/secrets.age"
    backup_key="$key_path.backup-$(date +%s)"
    backup_pub="$pub_path.backup-$(date +%s)"

    echo "Rotating encryption key for user {{ user }}..."
    echo ""
    echo "WARNING: This will generate a new keypair and re-encrypt all secrets."
    echo "Make sure you have backed up the current key!"
    echo ""
    read -p "Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Backup old keys if they exist
    if [ -f "$key_path" ]; then
        cp "$key_path" "$backup_key"
        echo "Backed up private key: $backup_key"
    fi

    if [ -f "$pub_path" ]; then
        cp "$pub_path" "$backup_pub"
        echo "Backed up public key: $backup_pub"
    fi

    # Decrypt existing secrets if they exist
    decrypted_secrets=""
    if [ -f "$secret_path" ] && [ -f "$key_path" ]; then
        echo "Decrypting existing secrets..."
        decrypted_secrets=$(nix shell nixpkgs#age -c age -d -i "$key_path" "$secret_path" 2>/dev/null || echo "{}")
    else
        decrypted_secrets="{}"
    fi

    # Generate new keypair
    echo "Generating new keypair..."
    mkdir -p "$(dirname "$key_path")"
    nix shell nixpkgs#age -c age-keygen -o "$key_path" 2>&1 | grep "Public key:" | cut -d: -f2 | tr -d ' ' > "$pub_path"

    # Re-encrypt secrets with new key
    if [ "$decrypted_secrets" != "{}" ] && [ -n "$decrypted_secrets" ]; then
        echo "Re-encrypting secrets with new key..."
        new_pubkey=$(cat "$pub_path")
        echo "$decrypted_secrets" | nix shell nixpkgs#age -c age -r "$new_pubkey" -o "$secret_path"
    fi

    echo ""
    echo "Key rotation complete!"
    echo ""
    echo "  New public key:  $pub_path"
    echo "  New private key: $key_path"
    echo "  Backups:"
    [ -f "$backup_key" ] && echo "    - $backup_key"
    [ -f "$backup_pub" ] && echo "    - $backup_pub"
    echo ""
    echo "Distribution options:"
    echo ""
    echo "  Option 1 - Bitwarden CLI (recommended):"
    echo "    # Login to Bitwarden"
    echo "    bw login"
    echo "    export BW_SESSION=\$(bw unlock --raw)"
    echo ""
    echo "    # Update existing item or create new"
    echo "    bw get template item | jq '"
    echo "      .type = 2 |"
    echo "      .secureNote.type = 0 |"
    echo "      .name = \"{{ user }} - nix-config age key\" |"
    echo "      .notes = \"'\$(cat $key_path)'\" |"
    echo "      .fields = [{name: \"username\", value: \"{{ user }}\", type: 0}]"
    echo "    ' | bw encode | bw create item"
    echo ""
    echo "  Option 2 - Manual distribution:"
    echo "    scp $key_path other-machine:~/.config/agenix/"
    echo ""
    echo "Next steps:"
    echo "  1. Commit updated users/{{ user }}/public.age in the nix config flake"
    echo "  2. Distribute new private key to all machines"
    echo "  3. Test decryption: just secrets-list"

# Set a secret value (one-command mode)
# Usage: just secrets-set <user> <field> <value>
# Example: just secrets-set cdrokar email "me@example.com"

# Example: just secrets-set cdrokar tokens.github "ghp_xxx"
secrets-set user field value:
    #!/usr/bin/env bash
    set -eo pipefail
    # Note: Not using -u (nounset) to allow password hashes with $6, $5, etc.

    # Validate user exists
    user_dir=$(just _user-config-dir {{ user }})
    if [ ! -d "$user_dir" ]; then
        echo "Error: User '{{ user }}' not found at $user_dir"
        echo "Available users: $(just _discover-users | tr '\n' ' ')"
        exit 1
    fi

    # Password requires hashing — always use set-password
    if [ "{{ field }}" = "password" ] || [ "{{ field }}" = "security.password" ]; then
        echo "Use 'just set-password {{ user }}' to set passwords (handles hashing automatically)"
        exit 1
    fi

    # Check user's public key exists
    pub_path="$user_dir/public.age"
    if [ ! -f "$pub_path" ]; then
        echo "Error: $pub_path not found"
        echo "Run 'just secrets-init-user {{ user }}' first to create the keypair"
        exit 1
    fi

    # Check private key exists
    key_path="$HOME/.config/agenix/key.txt"
    if [ ! -f "$key_path" ]; then
        echo "Error: Private key not found at $key_path"
        echo "Restore it from backup or run 'just secrets-init-user {{ user }}' to create a new one"
        exit 1
    fi

    secret_file="$user_dir/secrets.age"
    config_file="{{ nix_config_dir }}/users/{{ user }}/default.nix"
    pubkey=$(cat "$pub_path")

    # Auto-create empty secrets file if missing
    if [ ! -f "$secret_file" ]; then
        echo "Creating $secret_file with empty JSON..."
        echo '{}' | nix shell nixpkgs#age -c age -r "$pubkey" -o "$secret_file"
    fi

    echo "Setting secret: {{ field }}"

    # 1. Decrypt current secrets
    decrypted=$(nix shell nixpkgs#age -c age -d -i "$key_path" "$secret_file")

    # 2. Update JSON with new field/value (supports nested paths like tokens.github)
    updated=$(echo "$decrypted" | nix shell nixpkgs#jq -c jq --arg f "{{ field }}" --arg v "{{ value }}" \
        'setpath($f | split("."); $v)')

    # 3. Re-encrypt secrets
    echo "$updated" | nix shell nixpkgs#age -c age -r "$pubkey" -o "$secret_file"

    # 4. Update default.nix with placeholder
    # Convert field path to Nix attribute syntax
    field_nix="{{ field }}"
    placeholder_line="${field_nix} = \"<secret>\";"

    # Check if field already exists in config
    if grep -q "^\s*${field_nix}\s*=" "$config_file" 2>/dev/null; then
        echo "Field '{{ field }}' already exists in config, updating to <secret> placeholder"
        # Use sed to replace the value with <secret>
        # This is a simplified approach - complex Nix expressions may need manual editing
        sed -i '' "s/\(${field_nix}\s*=\s*\)\"[^\"]*\";/\1\"<secret>\";/" "$config_file" 2>/dev/null || \
        sed -i "s/\(${field_nix}\s*=\s*\)\"[^\"]*\";/\1\"<secret>\";/" "$config_file"
    else
        echo "Note: Add '${placeholder_line}' to your user config if not already present"
        echo "Location: $config_file (inside the user = { ... } block)"
    fi

    echo ""
    echo "Secret set successfully!"
    echo "  Secrets file: $secret_file"
    echo "  Field: {{ field }}"
    echo ""
    echo "If this is a new field, add to $config_file:"
    echo "  ${placeholder_line}"

# Generate a deploy key and store it in user secrets
# Usage: just deploy-key-create <user> <target>
# Example: just deploy-key-create cdrokar fonts
#
# Creates ~/.ssh/id_<target>, stores the private key in security.sshKeys.<target>,

# and prints the public key with instructions to add it as a GitHub deploy key.
deploy-key-create user target:
    #!/usr/bin/env bash
    set -euo pipefail

    key_path="$HOME/.ssh/id_{{ target }}"
    pub_path="${key_path}.pub"

    user_dir=$(just _user-config-dir {{ user }})
    if [ ! -d "$user_dir" ]; then
        echo "Error: User '{{ user }}' not found at $user_dir"
        exit 1
    fi

    # Check if key already exists
    if [ -f "$key_path" ]; then
        echo "Key already exists at $key_path"
        read -p "Overwrite? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
    fi

    # Generate keypair
    ssh-keygen -t ed25519 -f "$key_path" -N "" -C "{{ target }} deploy key"
    echo ""

    # Store private key in secrets and commit
    just secrets-set {{ user }} security.sshKeys.{{ target }} "$(cat "$key_path")"
    git -C "{{ nix_config_dir }}" add users/{{ user }}/secrets.age
    git commit -m "chore(secrets): update {{ user }} {{ target }} deploy key"
    echo ""

    # Output public key with instructions
    echo "============================================================"
    echo "  Deploy key created: $key_path"
    echo "============================================================"
    echo ""
    echo "Add the following public key as a deploy key on GitHub:"
    echo "  1. Go to the target repository → Settings → Deploy keys"
    echo "  2. Click 'Add deploy key'"
    echo "  3. Paste the key below"
    echo "  4. Leave 'Allow write access' unchecked"
    echo "  5. Click 'Add key'"
    echo ""
    echo "--- Public key ---"
    cat "$pub_path"
    echo "--- End ---"
    echo ""
    echo "Make sure users/{{ user }}/default.nix (nix config flake) has:"
    echo "  security.sshKeys.{{ target }} = \"<secret>\";"
    echo ""

# Set a user's password (hashes and stores in secrets)
# Usage: just set-password <user>

# Prompts for new password interactively (input hidden)
set-password user:
    #!/usr/bin/env bash
    set -euo pipefail

    user_dir=$(just _user-config-dir {{ user }})
    if [ ! -d "$user_dir" ]; then
        echo "Error: User '{{ user }}' not found at $user_dir"
        exit 1
    fi

    # Prompt for password (hidden input)
    read -sp "New password for {{ user }}: " password
    echo ""
    read -sp "Confirm password: " password_confirm
    echo ""

    if [ -z "$password" ]; then
        echo "Error: Password cannot be empty"
        exit 1
    fi

    if [ "$password" != "$password_confirm" ]; then
        echo "Error: Passwords do not match"
        exit 1
    fi

    just _hash-and-store-password "{{ user }}" "$password"

    echo ""
    echo "Password updated for {{ user }}!"
    echo "Run 'just install {{ user }} <host>' to apply."

# Show decrypted value of a secret field
# Usage: just secrets-get <user> [field]
# Without field: shows all decrypted values

# With field: shows a single value (supports nested paths like sshKeys.personal)
secrets-get user field="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate user exists
    user_dir=$(just _user-config-dir {{ user }})
    if [ ! -d "$user_dir" ]; then
        echo "Error: User '{{ user }}' not found at $user_dir"
        exit 1
    fi

    secret_file="$user_dir/secrets.age"
    key_path="$HOME/.config/agenix/key.txt"

    if [ ! -f "$secret_file" ]; then
        echo "Error: $secret_file not found"
        echo "Run 'just secrets-set {{ user }} <field> <value>' first"
        exit 1
    fi

    if [ ! -f "$key_path" ]; then
        echo "Error: Private key not found at $key_path"
        exit 1
    fi

    if [ -z "{{ field }}" ]; then
        nix shell nixpkgs#age nixpkgs#jq -c sh -c "age -d -i '$key_path' '$secret_file' | jq ." </dev/null
    else
        nix shell nixpkgs#age nixpkgs#jq -c sh -c "age -d -i '$key_path' '$secret_file' | jq -r '.{{ field }}'" </dev/null
    fi

# Edit user secrets interactively (opens editor)

# Usage: just secrets-edit <user>
secrets-edit user:
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate user exists
    user_dir=$(just _user-config-dir {{ user }})
    if [ ! -d "$user_dir" ]; then
        echo "Error: User '{{ user }}' not found at $user_dir"
        echo "Available users: $(just _discover-users | tr '\n' ' ')"
        exit 1
    fi

    # Check user's public key exists
    pub_path="$user_dir/public.age"
    if [ ! -f "$pub_path" ]; then
        echo "Error: $pub_path not found"
        echo "Run 'just secrets-init-user {{ user }}' first to create the keypair"
        exit 1
    fi

    # Check private key exists
    key_path="$HOME/.config/agenix/key.txt"
    if [ ! -f "$key_path" ]; then
        echo "Error: Private key not found at $key_path"
        echo "Restore it from backup or run 'just secrets-init-user {{ user }}' to create a new one"
        exit 1
    fi

    secret_file="$user_dir/secrets.age"
    pubkey=$(cat "$pub_path")

    # Auto-create empty secrets file if missing
    if [ ! -f "$secret_file" ]; then
        echo "Creating $secret_file with empty JSON..."
        echo '{}' | nix shell nixpkgs#age -c age -r "$pubkey" -o "$secret_file"
    fi

    echo "Opening secrets editor for {{ user }}..."
    echo "(Decrypting, editing, then re-encrypting)"

    # Create temp file for editing
    tmpfile=$(mktemp)
    trap "rm -f $tmpfile" EXIT

    # Decrypt to temp file
    nix shell nixpkgs#age -c age -d -i "$key_path" "$secret_file" > "$tmpfile"

    # Get file hash before editing
    hash_before=$(shasum "$tmpfile" | cut -d' ' -f1)

    # Open editor
    ${EDITOR:-vim} "$tmpfile"

    # Get file hash after editing
    hash_after=$(shasum "$tmpfile" | cut -d' ' -f1)

    if [ "$hash_before" = "$hash_after" ]; then
        echo "No changes made."
    else
        # Validate JSON
        if ! nix shell nixpkgs#jq -c jq empty "$tmpfile" 2>/dev/null; then
            echo "Error: Invalid JSON. Changes not saved."
            echo "Your edits are in: $tmpfile"
            trap - EXIT  # Don't delete the temp file
            exit 1
        fi

        # Re-encrypt
        nix shell nixpkgs#age -c age -r "$pubkey" -o "$secret_file" < "$tmpfile"
        echo "Secrets updated successfully!"
    fi

# List all user secret files and their status

# Shows nested paths for Feature 029 nested secrets support
secrets-list:
    #!/usr/bin/env bash
    echo "User secrets (per-user encryption keys):"
    echo "========================================="
    echo ""

    key_path="$HOME/.config/agenix/key.txt"
    has_private_key=false
    if [ -f "$key_path" ]; then
        has_private_key=true
        echo "Private key: $key_path (present)"
    else
        echo "Private key: $key_path (NOT FOUND)"
    fi
    echo ""

    for user_dir_entry in "{{ nix_config_dir }}/users"/*/; do
        user=$(basename "$user_dir_entry")

        user_config_dir="{{ nix_config_dir }}/users/$user"
        pub_path="$user_config_dir/public.age"
        secret_path="$user_config_dir/secrets.age"

        # Check if user has keypair
        if [ -f "$pub_path" ]; then
            echo "  $user:"
            echo "    Public key: $pub_path ✓"

            # Check for secrets file
            if [ -f "$secret_path" ]; then
                echo "    Secrets: $secret_path ✓"

                # Show all paths (including nested) if we can decrypt
                if [ "$has_private_key" = true ]; then
                    # Use jq to recursively list all leaf paths
                    paths=$(nix shell nixpkgs#age nixpkgs#jq -c sh -c "age -d -i '$key_path' '$secret_path' 2>/dev/null | jq -r '[paths(scalars)] | .[] | join(\".\")' 2>/dev/null" </dev/null || echo "")
                    if [ -n "$paths" ]; then
                        echo "    Fields:"
                        echo "$paths" | while read -r path; do
                            echo "      - $path: [encrypted]"
                        done
                    else
                        echo "    Fields: (unable to decrypt - wrong key?)"
                    fi
                else
                    echo "    Fields: (private key not available)"
                fi
            else
                echo "    Secrets: no file yet"
            fi
        else
            echo "  $user: no keypair (run 'just secrets-init-user $user')"
        fi
        echo ""
    done
