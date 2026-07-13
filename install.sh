#!/usr/bin/env bash
# dotfiles をホームディレクトリにシンボリックリンクとして配置する。
# 既存のファイル/リンクがあれば ~/.dotfiles.backup/<日時>/ に退避してから置き換える。
# 何度実行しても安全（すでに正しいリンクならスキップ）。
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles.backup/$(date +%Y%m%d-%H%M%S)"

# リンク対応表: "リポジトリ内のパス:ホームでのパス"
LINKS=(
  "zsh/zshrc:.zshrc"
  "zsh/zprofile:.zprofile"
  "zsh/functions.zsh:.zsh_functions"
  "git/gitconfig:.gitconfig"
  "wezterm/wezterm.lua:.config/wezterm/wezterm.lua"
  "starship/starship.toml:.config/starship.toml"
  "zed/settings.json:.config/zed/settings.json"
  "zed/keymap.json:.config/zed/keymap.json"
)

link_one() {
  local src="$DOTFILES_DIR/$1"
  local dst="$HOME/$2"

  # すでに正しいリンクなら何もしない
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok      $dst"
    return
  fi

  # 既存のファイル・リンクは退避
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$2")"
    mv "$dst" "$BACKUP_DIR/$2"
    echo "backup  $dst -> $BACKUP_DIR/$2"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link    $dst -> $src"
}

for pair in "${LINKS[@]}"; do
  link_one "${pair%%:*}" "${pair##*:}"
done

echo
echo "完了。新しいターミナルを開くか 'exec zsh' で反映されます。"
if [[ -d "$BACKUP_DIR" ]]; then
  echo "退避したファイル: $BACKUP_DIR"
fi
