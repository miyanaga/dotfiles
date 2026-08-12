#!/usr/bin/env bash
# macOS固有のインストール処理。ルートの install.sh から呼ばれる。
# 単体で実行してもよい（macOS部分だけをやり直したいとき）。
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles.backup/$(date +%Y%m%d-%H%M%S)}"
source "$DOTFILES_DIR/lib/install-common.sh"

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "macOS専用です（現在: $(uname -s)）" >&2
  exit 1
}

# macOSでしか意味のないリンク。
#   - VS Codeの設定パスがmacOSだけ ~/Library/Application Support/ になる
#   - colima は LaunchAgent 前提の常駐スクリプト
MACOS_LINKS=(
  "vscode/keybindings.json:Library/Application Support/Code/User/keybindings.json"
  "macos/colima/graceful-stop.sh:.local/bin/colima-graceful-stop"
  "macos/colima/fsck.sh:.local/bin/colima-fsck"
  "macos/colima/com.miyanaga.colima-graceful-stop.plist:Library/LaunchAgents/com.miyanaga.colima-graceful-stop.plist"
)

# launchd に登録する LaunchAgent のラベル（上の MACOS_LINKS でplistをリンクしたもの）
AGENTS=(
  "com.miyanaga.colima-graceful-stop"
)

bootstrap_agent() {
  local label="$1"
  local plist="$HOME/Library/LaunchAgents/$label.plist"
  local domain="gui/$(id -u)"

  if [[ ! -e "$plist" ]]; then
    echo "skip    launchd $label (plistがない)"
    return
  fi

  # すでに登録済みなら触らない。
  # bootout すると常駐スクリプトに SIGTERM が飛んで colima が停止してしまうので、
  # install.sh を再実行しただけで作業中のVMが落ちる、という事故を避ける。
  if launchctl print "$domain/$label" >/dev/null 2>&1; then
    echo "ok      launchd $label (登録済み)"
    return
  fi

  if launchctl bootstrap "$domain" "$plist" 2>/dev/null; then
    echo "load    launchd $label"
  else
    echo "warn    launchd $label の登録に失敗: launchctl bootstrap $domain \"$plist\"" >&2
  fi
}

link_all "${MACOS_LINKS[@]}"

for label in "${AGENTS[@]}"; do
  bootstrap_agent "$label"
done
