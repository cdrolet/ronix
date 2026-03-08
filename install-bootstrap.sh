#!/usr/bin/env bash

# Generic bootstrap installer for ronix-based configurations.
#
# URL=https://raw.githubusercontent.com/cdrolet/ronix/main/install-bootstrap.sh
#
# Usage:
#   curl -sL $URL | bash -s -- <user> <host> --root-flake <url> [options]
#
# Arguments:
#   <user>              Username to install (e.g. cdrokar)
#   <host>              Host name to install (e.g. avf-gnome)
#   --root-flake <url>  Git URL of the nix config flake (required)
#                       SSH:   git@github.com:you/private-config.git  (needs SSH keys)
#                       HTTPS: https://TOKEN@github.com/you/private-config.git  (fresh machine)
#   init-disk           Partition and format disk using host's disko storage profile
#
# The root flake is the nix config flake (e.g. private-config) that calls ronix.lib.mkOutputs.
# It is cloned to ~/.config/nix-config (canonical location).
# ronix itself is NOT cloned — Nix fetches it automatically via flake inputs.
#
# Examples:
#   # Fresh machine — GitHub PAT embedded in URL:
#   bash install-bootstrap.sh cdrokar avf-gnome --root-flake https://ghp_xxx@github.com/you/private-config.git init-disk
#   # Existing machine with SSH keys:
#   bash install-bootstrap.sh cdrokar home-macmini-m4 --root-flake git@github.com:you/private-config.git

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# ── Parse arguments ───────────────────────────────────────────────────
USER="${1:-}"
HOST="${2:-}"
ROOT_FLAKE=""
INIT_DISK=false

args=("${@:3}")
i=0
while [ $i -lt ${#args[@]} ]; do
  arg="${args[$i]}"
  if [[ $arg == "init-disk" ]]; then
    INIT_DISK=true
  elif [[ $arg == "--root-flake" ]]; then
    i=$((i+1))
    ROOT_FLAKE="${args[$i]:-}"
  fi
  i=$((i+1))
done

if [[ -z $USER ]] || [[ -z $HOST ]]; then
  echo_error "Usage: $0 <user> <host> --root-flake <git-url> [init-disk]"
  echo ""
  echo "  --root-flake <url>  Git URL of the nix config flake (required)"
  echo "  init-disk           Partition/format disk using host's disko storage profile"
  exit 1
fi

if [[ -z $ROOT_FLAKE ]]; then
  echo_error "--root-flake <url> is required (the nix config flake, e.g. git@github.com:you/private-config.git)"
  exit 1
fi

echo_info "Installing: $USER@$HOST (root-flake: $ROOT_FLAKE, init-disk: $INIT_DISK)"
echo ""

# ── Detect platform ───────────────────────────────────────────────────
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

# ── Install Nix ───────────────────────────────────────────────────────
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

# ── Install Homebrew (Darwin only) ────────────────────────────────────
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

# ── Resolve git command ───────────────────────────────────────────────
GIT_CMD=""
if [[ $PLATFORM == "darwin" ]] && ! xcode-select -p &>/dev/null; then
  echo_info "Xcode tools not installed, using nix to provide git..."
  GIT_CMD="nix run nixpkgs#git --"
elif ! git --version &>/dev/null; then
  echo_info "git not available, using nix to provide it..."
  GIT_CMD="nix run nixpkgs#git --"
else
  GIT_CMD="git"
fi

# ── Clone root flake (nix config flake) ───────────────────────────
echo_step "Cloning root flake (nix config flake)..."
NIX_CONFIG_DIR="$HOME/.config/nix-config"

if [[ -d $NIX_CONFIG_DIR ]]; then
  echo_warn "$NIX_CONFIG_DIR exists. Removing for fresh clone..."
  rm -rf "$NIX_CONFIG_DIR"
fi

$GIT_CMD clone "$ROOT_FLAKE" "$NIX_CONFIG_DIR"
echo_info "Root flake ready: $NIX_CONFIG_DIR"

# ── Age key prompt ────────────────────────────────────────────────────
USER_SECRETS_FILE="$NIX_CONFIG_DIR/users/$USER/secrets.age"
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

# ── Disko disk initialization ─────────────────────────────────────────
run_disko() {
  local attr="path:$NIX_CONFIG_DIR#nixosConfigurations.$USER-$HOST.config.system.build.diskoScriptNoDeps"
  echo_info "Building disko script..."
  local script
  script=$(nix build --extra-experimental-features "nix-command flakes" \
    "$attr" --no-link --print-out-paths) || {
    echo_error "Failed to build disko script"
    exit 1
  }
  script=$(echo "$script" | tail -n1)
  echo_info "Running disko: $script"
  if ! sudo "$script"; then
    echo_error "Disko partitioning failed"
    exit 1
  fi
}

if [[ $INIT_DISK == "true" ]]; then
  echo_step "Initializing disk using disko..."

  DISK_DEVICE=""
  for dev in /dev/vda /dev/sda /dev/nvme0n1; do
    [[ -b $dev ]] && { DISK_DEVICE="$dev"; break; }
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

# ── Installation ──────────────────────────────────────────────────────
echo_step "Entering devShell..."

cat >/tmp/install-inside-shell.sh <<'INSTALL_SCRIPT'
#!/usr/bin/env bash
set -e

USER="$1"; HOST="$2"; PLATFORM="$3"; INIT_DISK="$4"; ROOT_FLAKE="$5"
NIX_CONFIG_DIR="$HOME/.config/nix-config"

echo "===> Installing: $USER@$HOST ($PLATFORM, init-disk=$INIT_DISK)"

if [[ "$INIT_DISK" == "true" ]] && [[ "$PLATFORM" == "nixos" ]]; then
  # Fresh NixOS install from ISO
  if ! mountpoint -q /mnt; then
    echo "ERROR: /mnt is not mounted. Did disko run correctly?"
    exit 1
  fi

  echo "===> Running nixos-install..."
  # RONIX_ROOT_IS_PRIVATE=1: nix config flake is the root flake, no --override-input needed
  RONIX_ROOT_IS_PRIVATE=1 sudo nixos-install \
    --flake "path:$NIX_CONFIG_DIR#$USER-$HOST" \
    --no-root-passwd \
    --option download-buffer-size 268435456

  # First-boot marker for automatic home-manager setup
  sudo mkdir -p "/mnt/home/$USER"
  printf '%s\n' "$USER" "$HOST" "$ROOT_FLAKE" | sudo tee "/mnt/home/$USER/.nix-config-first-boot" > /dev/null

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
  # Update or initial install on running system
  echo "===> Building..."
  just build "$USER" "$HOST" || { echo "ERROR: Build failed"; exit 1; }
  echo "===> Installing..."
  just install "$USER" "$HOST" || { echo "ERROR: Install failed"; exit 1; }

  echo ""
  echo "===> Done! Restart terminal: exec \$SHELL"
fi
INSTALL_SCRIPT

chmod +x /tmp/install-inside-shell.sh

# Run inside the root flake's devShell (which inherits ronix's devShell via mkOutputs).
# CWD = NIX_CONFIG_DIR so `just` finds private-config's justfile there.
cd "$NIX_CONFIG_DIR"
if ! RONIX_ROOT_IS_PRIVATE=1 nix develop . --command /tmp/install-inside-shell.sh \
    "$USER" "$HOST" "$PLATFORM" "$INIT_DISK" "$ROOT_FLAKE"; then
  echo_error "Installation failed"
  rm -f /tmp/install-inside-shell.sh
  exit 1
fi

rm -f /tmp/install-inside-shell.sh
echo_info "Installation complete!"
