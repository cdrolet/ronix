# Quickstart Guide: Dotfiles to Nix Migration

**Feature**: 001-dotfiles-migration\
**Purpose**: Quick reference for common operations after migration

______________________________________________________________________

## Installation

### One-Line Install (No Git Clone) - All Platforms

Install directly from GitHub without cloning first:

```bash
# macOS (nix-darwin)
curl -L https://raw.githubusercontent.com/cdrolet/nix-config/main/install-remote.sh | bash -s -- darwin-dev

# NixOS
curl -L https://raw.githubusercontent.com/cdrolet/nix-config/main/install-remote.sh | bash -s -- nixos-dev

# Kali Linux (Home Manager only)
curl -L https://raw.githubusercontent.com/cdrolet/nix-config/main/install-remote.sh | bash -s -- kali-pentest

# Or specify custom repository
curl -L https://raw.githubusercontent.com/cdrolet/nix-config/main/install-remote.sh | bash -s -- darwin-dev github:cdrolet/nix-config
```

**Available hosts:**

- macOS: `work-macbook`, `home-macmini`, `darwin-dev`
- NixOS: `nixos-dev`
- Kali Linux: `kali-pentest`

**What it does:**

1. Installs Nix via Determinate Systems installer
1. Enables flakes automatically
1. Builds configuration directly from GitHub
1. Activates the appropriate system (nix-darwin/NixOS/Home Manager)
1. Optionally clones repo for future edits

### Traditional Install (With Git Clone) - All Platforms

If you prefer to clone first and inspect the code:

```bash
# Clone repository
git clone https://github.com/cdrolet/nix-config.git ~/.config/nix-config
cd ~/.config/nix-config

# macOS - Use justfile for installation
just install-darwin darwin-dev  # or work-macbook, home-macmini

# NixOS - Use justfile for installation
just install-nixos nixos-dev

# Kali Linux - Use justfile for Home Manager installation
just home-switch charles@kali-pentest

# After installation, restart your shell
exec $SHELL
```

______________________________________________________________________

## Daily Operations

### Update Packages

```bash
# Update flake inputs (nixpkgs, home-manager, etc.)
nix flake update

# Rebuild system
# macOS:
darwin-rebuild switch --flake ~/.config/nix-config

# NixOS:
sudo nixos-rebuild switch --flake /etc/nixos/nix-config
```

### Apply Configuration Changes

```bash
# After editing any .nix file
cd ~/.config/nix-config

# Test build without activating (dry-run)
# macOS:
darwin-rebuild build --flake .

# NixOS:
sudo nixos-rebuild build --flake .

# If successful, activate:
darwin-rebuild switch --flake .
# OR
sudo nixos-rebuild switch --flake .
```

### Add a New Package

Edit `common/users/<username>/packages.nix`:

```nix
{pkgs, ...}: {
  home.packages = with pkgs; [
    # Existing packages
    zoxide
    ripgrep
    
    # Add your new package
    jq  # Example: JSON processor
  ];
}
```

Then rebuild: `darwin-rebuild switch --flake .`

### Configure a Program

Edit `common/users/<username>/programs/<program>.nix`:

```nix
{config, pkgs, ...}: {
  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "your.email@example.com";
    aliases = {
      co = "checkout";
      st = "status";
    };
  };
}
```

Rebuild to apply changes.

______________________________________________________________________

## Rollback

### macOS

```bash
# List generations
darwin-rebuild --list-generations

# Rollback to previous generation
darwin-rebuild --rollback

# Rollback to specific generation
darwin-rebuild --switch-generation <number>
```

### NixOS

```bash
# List generations
nix profile history

# Rollback via boot menu (reboot and select generation)
# OR rollback immediately:
sudo nixos-rebuild --rollback
```

______________________________________________________________________

## Managing Secrets

### Add a New Secret

```bash
# Navigate to secrets directory
cd ~/.config/nix-config/secrets

# Edit secrets.yaml (will be encrypted)
sops secrets.yaml

# Add your secret in YAML format:
# github_token: "ghp_your_token_here"

# Reference in a module:
```

```nix
{config, ...}: {
  sops.secrets."github_token" = {
    sopsFile = ../secrets/secrets.yaml;
    owner = "charles";
    mode = "0400";
  };
  
  # Use secret path: config.sops.secrets."github_token".path
}
```

______________________________________________________________________

## Adding a New Host

```bash
# Create host directory
mkdir -p hosts/new-hostname

# Create default.nix
cat > hosts/new-hostname/default.nix << 'EOF'
{config, pkgs, ...}: {
  imports = [
    ./hardware.nix
    ../../modules/core
    # Add other modules as needed
  ];
  
  networking.hostName = "new-hostname";
  system.stateVersion = "23.11";  # Set to your NixOS version
}
EOF

# For macOS, create darwin-configuration.nix
# For NixOS, generate hardware-configuration.nix:
nixos-generate-config --show-hardware-config > hosts/new-hostname/hardware-configuration.nix

# Add to flake.nix outputs:
# darwinConfigurations.new-hostname = ... (macOS)
# nixosConfigurations.new-hostname = ... (NixOS)

# Build for new host
darwin-rebuild switch --flake .#new-hostname
```

______________________________________________________________________

## Garbage Collection

### Clean Old Generations

```bash
# macOS: Delete generations older than 30 days
nix-collect-garbage --delete-older-than 30d

# NixOS: Delete old generations and optimize
sudo nix-collect-garbage --delete-older-than 30d
sudo nix-store --optimize
```

### Automatic Garbage Collection

Configured in `modules/core/nix.nix`:

```nix
nix.gc = {
  automatic = true;
  options = "--delete-older-than 30d";
  # macOS: interval config
  # NixOS: dates = "weekly";
};
```

______________________________________________________________________

## Troubleshooting

### Shell Startup Issues

```bash
# Check zsh configuration syntax
zsh -n ~/.zshrc

# Verbose shell startup
zsh -xv

# Check Home Manager build
home-manager build --flake ~/.config/nix-config
```

### Build Failures

```bash
# Clean build cache
nix-store --verify --check-contents --repair

# Check flake syntax
nix flake check

# View detailed error output
darwin-rebuild switch --flake . --show-trace
```

### Secret Access Denied

```bash
# Check sops configuration
cat secrets/.sops.yaml

# Verify age key exists
ls -la ~/.config/sops/age/keys.txt

# Test decryption
sops -d secrets/secrets.yaml
```

______________________________________________________________________

## Useful Commands

### Nix Flakes

```bash
nix flake show                  # Show flake outputs
nix flake metadata              # Show flake metadata
nix flake update                # Update all inputs
nix flake lock                  # Update flake.lock
nix flake check                 # Verify flake
```

### Search Packages

```bash
nix search nixpkgs <package>    # Search for packages
nix search nixpkgs zoxide       # Example: search for zoxide
```

### Format Code

```bash
alejandra .                     # Format all Nix files
alejandra <file>.nix            # Format specific file
```

______________________________________________________________________

## Directory Reference

```
~/.config/nix-config/           # Configuration repository
├── flake.nix                   # Main entry point
├── common/users/<name>/        # Your user configuration
├── hosts/<hostname>/           # Host-specific config
├── modules/core/               # Universal modules
├── modules/optional/           # Optional features
└── secrets/                    # Encrypted secrets

/nix/store/                     # Immutable package store
/run/current-system/            # Active configuration (NixOS)
/run/secrets/                   # Decrypted secrets at runtime
```

______________________________________________________________________

## Next Steps

1. Customize `common/users/<username>/packages.nix` with your tools
1. Configure programs in `common/users/<username>/programs/`
1. Add host-specific settings in `hosts/<hostname>/`
1. Set up secrets in `secrets/secrets.yaml`
1. Commit changes and push to git repository

For detailed documentation, see `README.md` and individual module files.

**Note for Kali Linux**: The one-line installer handles everything automatically. It installs Home Manager ONLY - Kali's system configuration and security tools remain managed via apt. Nix provides your terminal environment and additional CLI tools.

### Android/GrapheneOS (Nix-on-Droid)

```bash
# 1. Install Nix-on-Droid from F-Droid
# - Open F-Droid on your Android device
# - Search for "Nix-on-Droid"
# - Install the app (no root required)

# 2. Open Nix-on-Droid terminal

# 3. Clone repository
nix-shell -p git --run "git clone https://github.com/cdrolet/nix-config.git ~/.config/nix-config"

# 4. Build and activate configuration
cd ~/.config/nix-config
nix-on-droid switch --flake .#pixel-phone

# 5. Restart terminal session
exit  # Then reopen Nix-on-Droid app
```

**Note**: Nix-on-Droid provides a Nix environment on Android without root. Your Android system and apps remain unchanged. This gives you a powerful terminal environment for SSH, development, and scripting on the go.

______________________________________________________________________

## Managing Secrets

### Add a New Secret

```bash
# Navigate to secrets directory
cd ~/.config/nix-config/secrets

# 1. First time: Generate age key
nix-shell -p age --run "age-keygen -o ~/.config/sops/age/keys.txt"

# 2. Get your public key
nix-shell -p age --run "age-keygen -y ~/.config/sops/age/keys.txt"

# 3. Add public key to .sops.yaml (replace the example key)

# 4. Create/edit encrypted secrets file
nix-shell -p sops --run "sops personal/secrets.yaml"

# 5. Add secrets in YAML format:
# github_token: ghp_xxxxxxxxxxxx
# api_key: sk_xxxxxxxxxxxx

# 6. Reference in configuration (see secrets/README.md)
```

### Use Secrets in Configuration

```nix
# In a module
sops.secrets.github_token = {
  sopsFile = ../../secrets/personal/secrets.yaml;
  path = "${config.home.homeDirectory}/.config/github/token";
};
```

See [secrets/README.md](../../secrets/README.md) for complete documentation.
