export ZSH="$HOME/.oh-my-zsh"

# Pure prompt requires ZSH_THEME to be empty
ZSH_THEME=""

plugins=(
    git
    colored-man-pages
    colorize
    history
)

source $ZSH/oh-my-zsh.sh

# Pure prompt — macOS: brew install pure / Linux: cloned to ~/.zsh/pure
if command -v brew &>/dev/null; then
    fpath+=("$(brew --prefix)/share/zsh/site-functions")
elif [ -d "$HOME/.zsh/pure" ]; then
    fpath+=("$HOME/.zsh/pure")
fi
autoload -U promptinit; promptinit
prompt pure

# Aliases
alias vim="nvim"
alias ls="lsd"
alias lg="lazygit"

# PATH
export PATH=/opt/homebrew/bin:$PATH
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/.local/bin/scripts"
export PATH="$PATH:$HOME/.foundry/bin"
export PATH="$PATH:$HOME/go/bin"

# brew libraries
export LIBRARY_PATH="$LIBRARY_PATH:$(brew --prefix)/lib"

# gvm (Go version manager)
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"

# nvm (lazy-loaded for shell startup performance)
activate_nvm() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    echo "NVM activated"
}

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# tmux-sessionizer
bindkey -s ^f "tmux-sessionizer\n"

export EXA_API_KEY=""
