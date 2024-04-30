sudo apt update &&

# Install general requirements
sudo apt install libfontconfig1-dev libfontconfig neovim fontconfig pkg-config cmake rofi zsh python-pip iw snap feh picom ripgrep tmux luarocks &&

# Install neovim
sudo snap install nvim --classic &&

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh &&

cargo install alacritty &&

# Install Mononoki font
cd ~/Downloads && wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Mononoki.zip &&
unzip Mononoki.zip && mkdir ~/.fonts && mv *.ttf ~/.fonts && rm -rf ./* &&
fc-cache -fv &&

# Install OMZ
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &&

# Install i3 and requirements
/usr/lib/apt/apt-helper download-file https://debian.sur5r.net/i3/pool/main/s/sur5r-keyring/sur5r-keyring_2024.03.04_all.deb keyring.deb SHA256:f9bb4340b5ce0ded29b7e014ee9ce788006e9bbfe31e96c09b2118ab91fca734 &&
sudo apt install ./keyring.deb &&
echo "deb http://debian.sur5r.net/i3/ $(grep '^DISTRIB_CODENAME=' /etc/lsb-release | cut -f2 -d=) universe" | sudo tee /etc/apt/sources.list.d/sur5r-i3.list &&
sudo apt update &&
sudo apt install i3 &&
rm keyring.deb &&
pip install psutil &&
git clone https://github.com/tobi-wan-kenobi/bumblebee-status.git ~/.config/i3/bumblebee-status &&

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash &&

nvm install stable && nvm use stable &&

# Install lazygit
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin

# Install docker
sudo apt-get update &&
sudo apt-get install ca-certificates curl &&
sudo install -m 0755 -d /etc/apt/keyrings &&
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc &&
sudo chmod a+r /etc/apt/keyrings/docker.asc &&
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null &&
sudo apt-get update &&
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin &&
sudo groupadd docker &&
sudo usermod -aG docker $USER &&

# Nvim & lua
cargo install stylua &&
