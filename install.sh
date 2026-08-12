#!/usr/bin/env bash
# dotfiles をホームディレクトリにシンボリックリンクとして配置する。
# 既存のファイル/リンクがあれば ~/.dotfiles.backup/<日時>/ に退避してから置き換える。
# 何度実行しても安全（すでに正しいリンクならスキップ）。
#
# ここで扱うのはOSを問わない共通設定だけ。OS固有の処理は
# macos/install.sh と ubuntu/install.sh に分けてあり、最後に呼び出す。
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles.backup/$(date +%Y%m%d-%H%M%S)"
export DOTFILES_DIR BACKUP_DIR

source "$DOTFILES_DIR/lib/install-common.sh"

# OSを問わない設定。"リポジトリ内のパス:ホームでのパス"
COMMON_LINKS=(
  "zsh/zshrc:.zshrc"
  "zsh/zprofile:.zprofile"
  "zsh/functions.zsh:.zsh_functions"
  "git/gitconfig:.gitconfig"
  "wezterm/wezterm.lua:.config/wezterm/wezterm.lua"
  "starship/starship.toml:.config/starship.toml"
  "zed/settings.json:.config/zed/settings.json"
  "zed/keymap.json:.config/zed/keymap.json"
  ".claude/skills/backup-dev-credential:.claude/skills/backup-dev-credential"
)

link_all "${COMMON_LINKS[@]}"

case "$(uname -s)" in
  Darwin) "$DOTFILES_DIR/macos/install.sh" ;;
  Linux)  "$DOTFILES_DIR/ubuntu/install.sh" ;;
  *)      echo "warn    OS固有の処理はスキップします: $(uname -s)" >&2 ;;
esac

echo
echo "完了。新しいターミナルを開くか 'exec zsh' で反映されます。"
if [[ -d "$BACKUP_DIR" ]]; then
  echo "退避したファイル: $BACKUP_DIR"
fi
