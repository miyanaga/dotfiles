#!/usr/bin/env bash
# 新マシンで実行: export.sh で作った暗号化アーカイブから
# ~/.ssh（configと使用中の鍵）、~/.zsh_secrets、~/.aws、~/.npmrc を復元する。
# 既存の ~/.ssh があれば退避してから展開し、パーミッションを整える。
#
# 使い方: ./import.sh <ssh-backup-YYYYMMDD.tar.gz.enc>
set -euo pipefail

IN="${1:?使い方: import.sh <ssh-backup.tar.gz.enc>}"

# 既存の ~/.ssh を退避（新マシンでも known_hosts などができていることがある）
if [[ -e "$HOME/.ssh" ]]; then
  BACKUP="$HOME/.ssh.before-import.$(date +%Y%m%d-%H%M%S)"
  mv "$HOME/.ssh" "$BACKUP"
  echo "既存の ~/.ssh を退避: $BACKUP"
fi

openssl enc -d -aes-256-cbc -pbkdf2 -in "$IN" | tar xzf - -C "$HOME"

# SSHが要求するパーミッションに整える
chmod 700 "$HOME/.ssh"
find "$HOME/.ssh" -type f -exec chmod 600 {} +
find "$HOME/.ssh" -type f -name '*.pub' -exec chmod 644 {} +

# APIキー等のシークレット
[[ -f "$HOME/.zsh_secrets" ]] && chmod 600 "$HOME/.zsh_secrets"
[[ -f "$HOME/.npmrc" ]] && chmod 600 "$HOME/.npmrc"
if [[ -d "$HOME/.aws" ]]; then
  chmod 700 "$HOME/.aws"
  find "$HOME/.aws" -type f -exec chmod 600 {} +
fi

echo
echo "復元しました。動作確認:"
echo "  ssh -T git@github.com   などでいくつかの接続先を試してください"
echo "確認できたらアーカイブファイルは削除してください: rm '$IN'"
