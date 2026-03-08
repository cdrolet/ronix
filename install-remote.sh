#!/usr/bin/env bash

# Remote installation script for nix-config (multi-platform)
#
# URL=https://raw.githubusercontent.com/cdrolet/nix-config/main/install-remote.sh
#
# Usage:
#   curl -H 'Cache-Control: no-cache' -sL $URL -o install.sh && bash install.sh <user> <host> [options]
#
# Options:
#   init-disk              Partition and format disk using host's disko storage profile
#   github-repo            Override repository (default: github:cdrolet/nix-config)
#   --private-repo <url>   Clone private user/host config repo to ~/.config/nix-private
#
# Examples:
#   curl -H 'Cache-Control: no-cache' -sL https://raw.githubusercontent.com/cdrolet/nix-config/main/install-remote.sh -o install.sh && bash install.sh cdrokar home-macmini-m4
#   curl -H 'Cache-Control: no-cache' -sL https://raw.githubusercontent.com/cdrolet/nix-config/main/install-remote.sh -o install.sh && bash install.sh cdrokar avf-gnome init-disk

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Parse arguments
USER="${1:-}"
HOST="${2:-}"
INIT_DISK=false
GITHUB_REPO="github:cdrolet/nix-config"
PRIVATE_REPO=""

args=("${@:3}")
i=0
while [ $i -lt ${#args[@]} ]; do
  arg="${args[$i]}"
  if [[ $arg == "init-disk" ]]; then
    INIT_DISK=true
  elif [[ $arg == github:* ]] || [[ $arg == http* ]]; then
    GITHUB_REPO="$arg"
  elif [[ $arg == "--private-repo" ]]; then
    i=$((i+1))
    PRIVATE_REPO="${args[$i]:-}"
  fi
  i=$((i+1))
done

if [[ -z $USER ]] || [[ -z $HOST ]]; then
  echo_error "Usage: $0 <user> <host> [init-disk] [github-repo]"
  echo ""
  echo "  init-disk    Partition/format disk using host's disko storage profile"
  echo ""
  echo "Examples:"
  echo "  $0 cdrokar home-macmini-m4"
  echo "  $0 cdrokar avf-gnome init-disk"
  echo ""
  echo "Hosts: Darwin (home-macmini-m4, work) | NixOS (avf-gnome, qemu-niri)"
  exit 1
fi

echo_info "Installing nix-config: $USER@$HOST (repo: $GITHUB_REPO, init-disk: $INIT_DISK)"
echo ""

# ── Detect platform ──────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
Darwin) PLATFORM="darwin" ;;
Linux)
  if [[ -f /etc/NIXOS ]]; then
    PLATFORM="nixos"
  else
    echo_error "Unsupported Linux distribution. Only NixOS and macOS are supported."
    exit 1
  fi
  ;;
*)
  echo_error "Unsupported OS: $OS"
  exit 1
  ;;
esac
echo_info "Detected platform: $PLATFORM"

# ── Install Nix ──────────────────────────────────────────────────────
if command -v nix &>/dev/null; then
  echo_info "Nix already installed: $(nix --version)"
else
  echo_step "Installing Nix..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
  fi
fi

if ! command -v nix &>/dev/null; then
  echo_error "Nix installation failed."
  exit 1
fi

export NIX_CONFIG="experimental-features = nix-command flakes"

# ── Install Homebrew (Darwin only) ───────────────────────────────────
if [[ $PLATFORM == "darwin" ]]; then
  if command -v brew &>/dev/null; then
    echo_info "Homebrew already installed: $(brew --version | head -1)"
  else
    echo_step "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi

# ── Clone repository ─────────────────────────────────────────────────
echo_step "Cloning repository..."
CONFIG_DIR="$HOME/.config/nix-config"

if [[ -d $CONFIG_DIR ]]; then
  echo_warn "$CONFIG_DIR exists. Removing for fresh clone..."
  rm -rf "$CONFIG_DIR"
fi

if [[ $GITHUB_REPO == github:* ]]; then
  REPO_URL="https://github.com/${GITHUB_REPO#github:}.git"
else
  REPO_URL="$GITHUB_REPO"
fi

GIT_CMD=""
if [[ $PLATFORM == "darwin" ]] && ! xcode-select -p &>/dev/null; then
  # macOS without Xcode tools: /usr/bin/git is a shim that triggers an install popup
  echo_info "Xcode tools not installed, using nix to provide git..."
  GIT_CMD="nix run nixpkgs#git --"
elif ! git --version &>/dev/null; then
  echo_info "git not available, using nix to provide it..."
  GIT_CMD="nix run nixpkgs#git --"
else
  GIT_CMD="git"
fi

$GIT_CMD clone "$REPO_URL" "$CONFIG_DIR"

cd "$CONFIG_DIR"
echo_info "Repository ready: $CONFIG_DIR"

# ── Clone private config repo (Feature 047 — mandatory) ─────────────
PRIVATE_CONFIG_DIR="$HOME/.config/nix-private"
if [[ -z $PRIVATE_REPO ]]; then
  echo_error "--private-repo <url> is required (private config repo is mandatory)"
  exit 1
fi
echo_step "Cloning private config repo..."
if [[ -d $PRIVATE_CONFIG_DIR ]]; then
  echo_warn "$PRIVATE_CONFIG_DIR exists. Removing for fresh clone..."
  rm -rf "$PRIVATE_CONFIG_DIR"
fi
$GIT_CMD clone "$PRIVATE_REPO" "$PRIVATE_CONFIG_DIR"
echo_info "Private config ready: $PRIVATE_CONFIG_DIR"

# ── Age key prompt ──────────────────────────────────────────────────
USER_SECRETS_FILE="$PRIVATE_CONFIG_DIR/users/$USER/secrets.age"
AGENIX_KEY_PATH="$HOME/.config/agenix/key.txt"

if [[ -f $USER_SECRETS_FILE ]] && [[ ! -f $AGENIX_KEY_PATH ]]; then
  echo ""
  echo_warn "User '$USER' has encrypted secrets but no private key found."
  echo_info "Key location: $AGENIX_KEY_PATH"
  echo ""

  read -p "$(echo -e "${GREEN}Provide the private key now? (Y/n)${NC} ")" -r </dev/tty
  echo ""

  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    while true; do
      echo_info "Paste the private key (starts with 'AGE-SECRET-KEY-'), then Ctrl+D:"
      echo ""
      private_key=$(cat </dev/tty)
      key_line=$(echo "$private_key" | grep -v '^#' | grep -v '^[[:space:]]*$' | head -n1)

      if [[ ! $key_line =~ ^AGE-SECRET-KEY- ]]; then
        echo_error "Invalid key format."
        read -p "$(echo -e "${YELLOW}Try again? (Y/n)${NC} ")" -r </dev/tty
        [[ $REPLY =~ ^[Nn]$ ]] && {
          echo_error "Cannot continue without key."
          exit 1
        }
      else
        mkdir -p "$(dirname "$AGENIX_KEY_PATH")"
        echo "$private_key" >"$AGENIX_KEY_PATH"
        chmod 600 "$AGENIX_KEY_PATH"
        echo_info "Private key saved to $AGENIX_KEY_PATH"
        break
      fi
    done
  else
    echo_warn "Continuing without private key. Add later: $AGENIX_KEY_PATH"
  fi
fi

# ── Disko disk initialization ───────────────────────────────────────
run_disko() {
  local attr="$CONFIG_DIR#nixosConfigurations.$USER-$HOST.config.system.build.diskoScriptNoDeps"
  echo_info "Building disko script..."
  local script
  script=$(nix build --extra-experimental-features "nix-command flakes" \
    "$attr" --no-link --print-out-paths) || {
    echo_error "Failed to build disko script"
    exit 1
  }
  # nix build --print-out-paths may output multiple lines; take the last one
  script=$(echo "$script" | tail -n1)
  echo_info "Running disko: $script"
  if ! sudo "$script"; then
    echo_error "Disko partitioning failed"
    exit 1
  fi
}

if [[ $INIT_DISK == "true" ]]; then
  echo_step "Initializing disk using disko..."

  # Auto-detect disk device
  DISK_DEVICE=""
  for dev in /dev/vda /dev/sda /dev/nvme0n1; do
    [[ -b $dev ]] && {
      DISK_DEVICE="$dev"
      break
    }
  done
  if [[ -z $DISK_DEVICE ]]; then
    echo_error "No disk found (/dev/vda, /dev/sda, /dev/nvme0n1)"
    exit 1
  fi
  echo_info "Detected disk: $DISK_DEVICE"

  if mountpoint -q /mnt 2>/dev/null; then
    echo_warn "Disk already initialized (/mnt is mounted)"
    df -h /mnt | tail -1
    read -p "$(echo -e "${YELLOW}Skip disk init and continue? (Y/n)${NC} ")" -r </dev/tty
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      sudo umount -R /mnt 2>/dev/null || true
      sudo swapoff --all 2>/dev/null || true
      run_disko
    else
      echo_info "Using existing partitions"
    fi
  else
    echo_warn "This will partition and format $DISK_DEVICE. All data will be lost!"
    run_disko
  fi

  echo_info "Disk initialized successfully"
  echo ""
fi

# ── Installation ─────────────────────────────────────────────────────
echo_step "Entering devShell..."

cat >/tmp/install-inside-shell.sh <<'INSTALL_SCRIPT'
#!/usr/bin/env bash
set -e

USER="$1"; HOST="$2"; PLATFORM="$3"; INIT_DISK="$4"; GITHUB_REPO="$5"; PRIVATE_REPO="${6:-}"

# Feature 047: private config is mandatory
PRIVATE_CONFIG_DIR="$HOME/.config/nix-private"
PRIVATE_OVERRIDE="--override-input user-host-config path:$PRIVATE_CONFIG_DIR"

echo "===> Installing: $USER@$HOST ($PLATFORM, fresh=$INIT_DISK)"

if [[ "$INIT_DISK" == "true" ]] && [[ "$PLATFORM" == "nixos" ]]; then
  # Fresh NixOS install
  if ! mountpoint -q /mnt; then
    echo "ERROR: /mnt is not mounted. Did disko run correctly?"
    exit 1
  fi

  echo "===> Running nixos-install..."
  sudo nixos-install --flake ".#$USER-$HOST" --no-root-passwd \
    --option download-buffer-size 268435456 $PRIVATE_OVERRIDE

  # First-boot marker for automatic home-manager setup
  if [[ "$GITHUB_REPO" == github:* ]]; then
    REPO_GIT_URL="https://github.com/${GITHUB_REPO#github:}.git"
  else
    REPO_GIT_URL="$GITHUB_REPO"
  fi

  sudo mkdir -p "/mnt/home/$USER"
  # Write first-boot marker: user, host, repo URL, optional private repo URL
  printf '%s\n' "$USER" "$HOST" "$REPO_GIT_URL" "${PRIVATE_REPO}" | sudo tee "/mnt/home/$USER/.nix-config-first-boot" > /dev/null

  # Copy agenix key if available
  AGENIX_KEY_PATH="$HOME/.config/agenix/key.txt"
  if [ -f "$AGENIX_KEY_PATH" ]; then
    echo "===> Copying agenix key..."
    sudo mkdir -p "/mnt/home/$USER/.config/agenix"
    sudo cp "$AGENIX_KEY_PATH" "/mnt/home/$USER/.config/agenix/key.txt"
    sudo chmod 600 "/mnt/home/$USER/.config/agenix/key.txt"
  fi

  sudo chown -R 1000:100 "/mnt/home/$USER"

  echo ""
  echo "===> NixOS installation complete!"
  echo "  1. Reboot  2. Log in as $USER  3. Home-manager runs automatically"
  echo ""

  echo "Rebooting in 10 seconds... Press 'y' to reboot now, 'n' to cancel."
  read -t 10 -n 1 -r </dev/tty || REPLY=y
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && echo "Run 'sudo reboot' when ready." || sudo reboot
else
  # Update existing system
  echo "===> Building..."
  just build "$USER" "$HOST" || { echo "ERROR: Build failed"; exit 1; }
  echo "===> Installing..."
  just install "$USER" "$HOST" || { echo "ERROR: Install failed"; exit 1; }

  echo ""
  echo "===> Done! Restart terminal: exec \$SHELL"
  echo "  Apply changes: just install $USER $HOST"
fi
INSTALL_SCRIPT

chmod +x /tmp/install-inside-shell.sh

if ! nix develop --command /tmp/install-inside-shell.sh "$USER" "$HOST" "$PLATFORM" "$INIT_DISK" "$GITHUB_REPO" "$PRIVATE_REPO"; then
  echo_error "Installation failed"
  rm -f /tmp/install-inside-shell.sh
  exit 1
fi

rm -f /tmp/install-inside-shell.sh
echo_info "Installation complete!"
