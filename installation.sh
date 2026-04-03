#!/usr/bin/env bash
# installation.sh — bootstrap a fresh Linux (Debian/Ubuntu) machine
# Run from the repo root: ./installation.sh

set -euo pipefail

sudo apt update

echo "==> Installing system packages"
sudo apt install -y \
    libfontconfig1-dev libfontconfig fontconfig pkg-config cmake \
    rofi zsh python3-pip iw snap feh picom ripgrep tmux luarocks \
    shellcheck clang-format neovim curl wget unzip

echo "==> Installing neovim (latest via snap)"
sudo snap install nvim --classic

echo "==> Installing Rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

echo "==> Installing lsd"
cargo install lsd

echo "==> Installing stylua"
cargo install stylua

echo "==> Installing Ghostty"
echo "NOTE: Install Ghostty manually from https://ghostty.org/docs/install/binary"

echo "==> Installing Mononoki Nerd Font"
FONT_VERSION=$(curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
mkdir -p ~/Downloads/mononoki && cd ~/Downloads/mononoki
wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v${FONT_VERSION}/Mononoki.zip"
unzip -o Mononoki.zip
mkdir -p ~/.fonts && mv ./*.ttf ~/.fonts/
fc-cache -fv
cd ~

echo "==> Installing Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "==> Installing pure prompt"
mkdir -p "$HOME/.zsh/pure"
curl -fsSL https://raw.githubusercontent.com/sindresorhus/pure/main/pure.zsh -o "$HOME/.zsh/pure/pure.zsh"
curl -fsSL https://raw.githubusercontent.com/sindresorhus/pure/main/async.zsh -o "$HOME/.zsh/pure/async.zsh"
# Add fpath for pure on Linux (no brew prefix)
grep -q 'fpath+=.*pure' "$HOME/.zshrc" || \
    sed -i '/autoload -U promptinit/i fpath+=("$HOME/.zsh/pure")' "$HOME/.zshrc"

echo "==> Installing fzf"
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all

echo "==> Installing i3"
/usr/lib/apt/apt-helper download-file \
    https://debian.sur5r.net/i3/pool/main/s/sur5r-keyring/sur5r-keyring_2024.03.04_all.deb \
    keyring.deb \
    SHA256:f9bb4340b5ce0ded29b7e014ee9ce788006e9bbfe31e96c09b2118ab91fca734
sudo apt install -y ./keyring.deb
echo "deb http://debian.sur5r.net/i3/ $(grep '^DISTRIB_CODENAME=' /etc/lsb-release | cut -f2 -d=) universe" \
    | sudo tee /etc/apt/sources.list.d/sur5r-i3.list
sudo apt update && sudo apt install -y i3
rm keyring.deb
pip3 install psutil
git clone https://github.com/tobi-wan-kenobi/bumblebee-status.git ~/.config/i3/bumblebee-status

echo "==> Installing nvm"
NVM_VERSION=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts && nvm use --lts

echo "==> Installing pnpm"
curl -fsSL https://get.pnpm.io/install.sh | sh -

echo "==> Installing lazygit"
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit lazygit.tar.gz

echo "==> Installing Docker"
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd docker || true
sudo usermod -aG docker "$USER"

echo "==> Installing neovim tooling"
python3 -m pip install flake8 black cpplint
npm install -g fixjson
go install mvdan.cc/sh/v3/cmd/shfmt@latest

HADOLINT_VERSION=$(curl -s "https://api.github.com/repos/hadolint/hadolint/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
wget -q "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64"
chmod +x hadolint-Linux-x86_64
sudo mv hadolint-Linux-x86_64 /usr/bin/hadolint

echo "==> Installing TPM (tmux plugin manager)"
if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
fi

echo "==> Installing foundry"
curl -L https://foundry.paradigm.xyz | bash
"$HOME/.foundry/bin/foundryup"

echo ""
echo "Done! Log out and back in for docker group changes to take effect."
echo "Run ./setup.sh to symlink dotfiles, then restart your shell."
