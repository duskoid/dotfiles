#!/usr/bin/env bash
# One-step bootstrap for a fresh machine.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/duskoide/dotfiles/main/bootstrap.sh)
set -euo pipefail

DOTFILES_REPO="https://github.com/duskoide/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# --- 0. Load nix into PATH if already installed -----------------------------
# The guard below relies on `command -v nix`, but the nix profile dir is only
# added to PATH by sourcing nix.sh (login-shell .bash_profile isn't sourced
# in every context). Without this, re-runs on an existing install would try to
# reinstall Nix and die on the nix-env/nix profile incompatibility. No-op on a
# fresh machine, since the file doesn't exist yet.
if [[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
  # shellcheck disable=SC1091
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

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
  # shellcheck disable=SC1091
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
else
  echo "==> Nix already installed."
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

# --- 7. Build ----------------------------------------------------------------
echo "==> Running home-manager switch..."
home-manager switch --flake "$HOME/.config/home-manager#pn" --show-trace

echo ""
echo "========================================="
echo " Done! Open a new shell to get started."
echo ""
echo " Next steps:"
echo "   1. Recreate secrets:  nvim ~/dotfiles/shell/.zsh/secrets.zsh"
echo "   2. Set a Rust toolchain:  rustup default stable"
echo "   3. Auth GitHub (git credential helper needs it):  gh auth login"
echo "========================================="
