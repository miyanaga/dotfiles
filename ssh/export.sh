#!/usr/bin/env bash
# 旧マシンで実行: ~/.ssh をパスフレーズ付きで暗号化したアーカイブを作る。
# できたファイルを AirDrop などで新マシンに送り、ssh/import.sh で復元する。
#
# 除外するもの:
#   .git / .archives : ~/.ssh 内に残っている古いgitリポジトリと退役鍵（新マシンに持ち込まない）
#   .DS_Store
#
# 使い方: ./export.sh [出力先ファイル]   （省略時はデスクトップ）
set -euo pipefail

OUT="${1:-$HOME/Desktop/ssh-backup-$(date +%Y%m%d).tar.gz.enc}"

echo "パスフレーズを設定します（復元時に同じものを入力します）"
tar czf - -C "$HOME" \
  --exclude '.ssh/.git' --exclude '.ssh/.git/*' \
  --exclude '.ssh/.archives' --exclude '.ssh/.archives/*' \
  --exclude '*.DS_Store' \
  .ssh \
  | openssl enc -aes-256-cbc -pbkdf2 -salt -out "$OUT"

echo
echo "作成しました: $OUT"
echo "これを AirDrop 等で新マシンに送り、ssh/import.sh で復元してください。"
echo "復元を確認したら、このファイルは両方のマシンから削除してください。"
