#!/usr/bin/env bash
# macos.sh — bootstrap a fresh macOS machine
# Run from the repo root: ./macos.sh

set -euo pipefail

# Homebrew
if ! command -v brew &>/dev/null; then
    echo "==> Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "==> Installing brew packages"
brew install \
    neovim \
    tmux \
    ripgrep \
    fzf \
    lsd \
    lazygit \
    pure \
    nvm \
    pnpm \
    go \
    rust \
    stylua \
    shfmt \
    shellcheck \
    hadolint \
    clang-format

echo "==> Installing brew casks"
brew install --cask \
    ghostty \
    aerospace \
    docker

echo "==> Installing Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "==> Installing foundry"
curl -L https://foundry.paradigm.xyz | bash
"$HOME/.foundry/bin/foundryup"

echo "==> Installing gvm (Go version manager)"
if [ ! -d "$HOME/.gvm" ]; then
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
fi

echo "==> Installing neovim tools"
pip3 install flake8 black cpplint
npm install -g fixjson

echo "==> Installing Mononoki Nerd Font"
brew install --cask font-mononoki-nerd-font

echo ""
echo "Done! Run ./setup.sh to symlink dotfiles, then restart your shell."
