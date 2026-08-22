#!/usr/bin/env bash
# One-step bootstrap for a fresh machine.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/duskoide/dotfiles/main/bootstrap.sh)
set -euo pipefail

DOTFILES_REPO="https://github.com/duskoide/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# --- 0. Load nix into PATH if already installed -----------------------------
# The guard below relies on `command -v nix`, but the Nix profile dir is only
# added to PATH by sourcing a profile script (login-shell .bash_profile isn't
# sourced in every context). Support both single-user and daemon installs.
load_nix_profile() {
  if command -v nix &>/dev/null; then
    return 0
  fi

  for profile in \
    "$HOME/.nix-profile/etc/profile.d/nix.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; do
    if [[ -r "$profile" ]]; then
      # shellcheck disable=SC1090
      . "$profile"
    fi
  done
}

load_nix_profile

# --- 1. Precheck required commands ------------------------------------------
missing=()
for cmd in curl git; do
  command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if ((${#missing[@]})); then
  echo "!! Missing required command(s): ${missing[*]}" >&2
  echo "   Install them first, e.g.:" >&2
  echo "     Fedora: sudo dnf install -y ${missing[*]}" >&2
  echo "     Debian: sudo apt install -y ${missing[*]}" >&2
  exit 1
fi

# --- 2. Install Nix (single-user) -------------------------------------------
if ! command -v nix &>/dev/null; then
  echo "==> Installing Nix..."
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
  load_nix_profile
else
  echo "==> Nix already installed."
fi

if ! command -v nix &>/dev/null; then
  echo "!! Nix installation completed, but the nix command is not available." >&2
  echo "   Start a new shell and rerun this script." >&2
  exit 1
fi

# --- 3. Enable flakes --------------------------------------------------------
mkdir -p "$HOME/.config/nix"
if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
  echo "==> Enabled flakes in nix.conf."
fi

# --- 4. Install home-manager -------------------------------------------------
if ! command -v home-manager &>/dev/null; then
  echo "==> Installing home-manager..."
  # Priority 6: `home-manager switch` (flake mode) installs its own
  # `home-manager-path` into the default profile at priority 5 during
  # activation, and two same-name packages at the same priority conflict
  # ("profile ... is incompatible" / "conflicting packages"). Different
  # priorities coexist, and the flake-input home-manager wins on PATH.
  nix profile install nixpkgs#home-manager --priority 6
else
  echo "==> home-manager already installed."
fi

# --- 5. Clone dotfiles -------------------------------------------------------
if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "==> Cloning dotfiles..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "==> Dotfiles already present, pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only
fi

# --- 6. Link home-manager config into place ----------------------------------
mkdir -p "$HOME/.config"
ln -sfn "$DOTFILES_DIR/home-manager" "$HOME/.config/home-manager"
echo "==> Symlinked ~/.config/home-manager -> $DOTFILES_DIR/home-manager"

# --- 7. Prepare local secrets ------------------------------------------------
# secrets.zsh is intentionally ignored and therefore absent after a fresh
# clone. Home Manager links it into ~/.zsh, so ensure the source exists before
# activation without overwriting an existing private file.
SECRETS_FILE="$DOTFILES_DIR/shell/.zsh/secrets.zsh"
if [[ ! -e "$SECRETS_FILE" && ! -L "$SECRETS_FILE" ]]; then
  cat > "$SECRETS_FILE" <<'EOF'
# Put private tokens / API keys here.
# This file is ignored by Git and sourced by Zsh.
EOF
  chmod 600 "$SECRETS_FILE"
  echo "==> Created private secrets template at $SECRETS_FILE"
else
  echo "==> Keeping existing secrets file at $SECRETS_FILE"
fi

# --- 8. Link Bash startup files ----------------------------------------------
# Keep existing files by moving them aside before creating the repository link.
link_with_backup() {
  local source="$1"
  local destination="$2"

  if [[ -L "$destination" && "$(readlink "$destination")" == "$source" ]]; then
    echo "==> Already linked $destination"
    return 0
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    local backup
    backup="${destination}.backup.$(date +%Y%m%d%H%M%S)"
    local suffix=1
    while [[ -e "$backup" || -L "$backup" ]]; do
      backup="${destination}.backup.$(date +%Y%m%d%H%M%S).${suffix}"
      suffix=$((suffix + 1))
    done
    mv "$destination" "$backup"
    echo "==> Backed up $destination to $backup"
  fi

  ln -s "$source" "$destination"
  echo "==> Linked $destination -> $source"
}

link_with_backup "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"
link_with_backup "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"

# --- 9. Build ----------------------------------------------------------------
echo "==> Running home-manager switch..."
home-manager switch --flake "$HOME/.config/home-manager#pn" --show-trace

echo ""
echo "========================================="
echo " Done! Open a new shell to get started."
echo ""
echo " Next steps:"
echo "   1. Edit secrets:  nvim ~/dotfiles/shell/.zsh/secrets.zsh"
echo "   2. Set default Rust toolchain:  rustup default stable"
echo "   3. Authenticate GitHub:  gh auth login"
echo "   4. Set up Flatpak / Zen browser if needed:"
echo "      flatpak install flathub app.zen_browser.zen"
echo "========================================="
