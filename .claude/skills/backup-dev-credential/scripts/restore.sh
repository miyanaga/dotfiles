#!/usr/bin/env bash
# 1Passwordに保存したクレデンシャルをローカルに書き戻す。
#
# 使い方:
#   ./restore.sh                                  # 保存済みリポジトリの一覧
#   ./restore.sh ideamans/lightfile6              # 復元内容の確認だけ（既定）
#   ./restore.sh ideamans/lightfile6 --apply      # 実際に書き戻す
#   ./restore.sh ideamans/lightfile6 --apply --to ~/dev/lightfile6
#   ./restore.sh --all --apply                    # 全リポジトリを元の場所へ
#
# 既存ファイルは上書きしない。上書きするなら --force を付ける。
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in -h|--help) usage "$0"; exit 0;; esac

require_op
exec python3 "$LIB_DIR/restore.py" --vault "$VAULT" --tag "$TAG" "$@"
