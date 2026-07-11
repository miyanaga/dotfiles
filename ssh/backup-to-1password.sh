#!/usr/bin/env bash
# 現在の ~/.ssh 全体（未使用の鍵・退役鍵の.archivesも含むフルスナップショット）を
# 1Passwordに「書類」として保存する。鍵の整理・移行前のセーフティネット。
#
# 前提:
#   - 1Password CLI: brew install --cask 1password-cli
#   - 1Passwordアプリ > 設定 > 開発者 > 「1Password CLIと連携」をON（Touch IDで認証される）
#
# 使い方: ./backup-to-1password.sh
set -euo pipefail

command -v op >/dev/null || { echo "opコマンドがありません: brew install --cask 1password-cli"; exit 1; }
op whoami >/dev/null 2>&1 || {
  echo "1Passwordにサインインできません。"
  echo "1Passwordアプリ > 設定 > 開発者 > 「1Password CLIと連携」を有効にして再実行してください。"
  exit 1
}

TITLE="ssh-full-backup-$(date +%Y%m%d)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

tar czf "$TMP/$TITLE.tar.gz" -C "$HOME" \
  --exclude '.ssh/.git' --exclude '.ssh/.git/*' \
  --exclude '*.DS_Store' \
  .ssh

op document create "$TMP/$TITLE.tar.gz" --title "$TITLE" --tags ssh,backup >/dev/null

echo "1Passwordに保存しました: $TITLE（タグ: ssh, backup）"
echo
echo "復元するとき:"
echo "  op document get '$TITLE' --out-file ~/$TITLE.tar.gz"
echo "  tar xzf ~/$TITLE.tar.gz -C ~    # ~/.ssh に展開される"
echo "  rm ~/$TITLE.tar.gz"
