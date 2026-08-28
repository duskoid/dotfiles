#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# Load single-user Nix into PATH. Home Manager's zsh files do this via
# hm-session-vars, but bash needs it explicitly since bootstrap links this
# file over the copy the Nix installer patched.
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

. "$HOME/.local/share/../bin/env"


# Added by Antigravity CLI installer
export PATH="/home/pn/.local/bin:$PATH"
