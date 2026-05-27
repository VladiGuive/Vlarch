export PATH="/usr/local/bin:$HOME/.local/bin:/usr/bin:$PATH"

# agetty autologin may skip .zprofile; fall back for any interactive tty1 shell.
if [[ -z ${WAYLAND_DISPLAY-} ]] \
    && { [[ $(tty 2>/dev/null) == /dev/tty1 ]] || [[ ${XDG_VTNR-0} -eq 1 ]]; } \
    && command -v vlarch-tty-login >/dev/null 2>&1; then
  exec vlarch-tty-login
fi

if [[ -o interactive ]] && [[ -f "$HOME/.local/bin/vlarch-onboarding" ]]; then
  bash "$HOME/.local/bin/vlarch-onboarding" || true
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Keybindings
bindkey -e
bindkey  "^[[1~"   beginning-of-line
bindkey  "^[[4~"   end-of-line
bindkey  "^[[3~"  delete-char

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias ls='ls --color'
alias ll='ls -lah --color'
alias vim='nvim'
alias c='clear'
vu() {
  vlarch update "$@"
}

# Evals
eval "$(oh-my-posh init zsh --config $HOME/.config/ohmyposh/conf.toml)"
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

