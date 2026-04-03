#!/usr/bin/env bash
# setup.sh — symlink dotfiles into place
# Run from the repo root: ./setup.sh

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname)"

link() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  backup: $dst -> $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "  linked: $dst"
}

echo "==> Linking shell configs"
link "$DOTFILES/.zshrc"    "$HOME/.zshrc"
link "$DOTFILES/.bashrc"   "$HOME/.bashrc"
link "$DOTFILES/.vimrc"    "$HOME/.vimrc"
link "$DOTFILES/.config/tmux" "$HOME/.config/tmux"

echo "==> Linking XDG configs"
link "$DOTFILES/.config/nvim"    "$HOME/.config/nvim"
link "$DOTFILES/.config/ghostty" "$HOME/.config/ghostty"

if [ "$OS" = "Darwin" ]; then
  echo "==> Linking macOS configs"
  link "$DOTFILES/.config/aerospace" "$HOME/.config/aerospace"
else
  echo "==> Linking Linux configs"
  link "$DOTFILES/.config/i3"   "$HOME/.config/i3"
  link "$DOTFILES/.config/rofi" "$HOME/.config/rofi"
  link "$DOTFILES/picom.conf"   "$HOME/.config/picom/picom.conf"
fi

echo "==> Linking MCP config"
link "$DOTFILES/.mcp.json" "$HOME/.mcp.json"

echo "==> Linking Claude Code configs"
link "$DOTFILES/.claude/CLAUDE.md"      "$HOME/.claude/CLAUDE.md"
link "$DOTFILES/.claude/settings.json"  "$HOME/.claude/settings.json"
link "$DOTFILES/.claude/statusline.sh"  "$HOME/.claude/statusline.sh"
link "$DOTFILES/.claude/agents"         "$HOME/.claude/agents"
link "$DOTFILES/.claude/commands"       "$HOME/.claude/commands"
link "$DOTFILES/.claude/skills"         "$HOME/.claude/skills"

echo ""
echo "Done. Restart your shell or source ~/.zshrc"
