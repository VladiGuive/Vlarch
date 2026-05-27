# Vlarch zsh interactive config.

setopt AUTO_CD HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

bindkey -e

autoload -U colors && colors
autoload -Uz compinit && compinit -i
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

export EDITOR="${EDITOR:-nvim}"
export VISUAL="$EDITOR"
export PAGER="${PAGER:-less}"
export LESS="-R"

alias ls='ls --color=auto'
alias ll='ls -alh'
alias la='ls -A'
alias grep='grep --color=auto'
alias g='git'
alias v='nvim'

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
if command -v fzf >/dev/null 2>&1 && [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
  source /usr/share/fzf/completion.zsh 2>/dev/null || true
fi
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init zsh)"
fi

if command -v fastfetch >/dev/null 2>&1 && [[ -z $WAYLAND_DISPLAY && $- == *i* ]]; then
  fastfetch 2>/dev/null || true
fi
