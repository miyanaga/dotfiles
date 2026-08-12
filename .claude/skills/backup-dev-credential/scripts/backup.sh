#!/usr/bin/env bash
# 走査で見つかったクレデンシャルを1Passwordにバックアップする。
#
# リポジトリ1件 = アイテム1件。タイトルはGitHubのパス（例 ideamans/lightfile6）。
# 各ファイルは添付として保存し、元の相対パスは meta.manifest に持つ。
#
# 1Passwordの承認（Touch ID）はopコマンドを叩くたびに求められるため、
# 全リポジトリの処理を必ずこの1プロセスの中で終わらせる。
#
# 使い方:
#   ./backup.sh                    # 何が保存されるかを表示するだけ（既定）
#   ./backup.sh --apply            # 実際に1Passwordへ保存する
#   ./backup.sh --apply --only ideamans/lightfile6
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

APPLY=0
ROOTS=()
PYARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; PYARGS+=(--apply); shift;;
    --only) PYARGS+=(--only "$2"); shift 2;;
    -h|--help) usage "$0"; exit 0;;
    *) ROOTS+=("$1"); shift;;
  esac
done

echo "走査中..." >&2
SCAN="$(mktemp)"
trap 'rm -f "$SCAN"' EXIT
# macOSのbashは3.2で、set -u のもとでは空配列の "${arr[@]}" が
# unbound variable になる。${arr[@]+...} で空のときは展開ごと消す。
"$SKILL_DIR/scripts/scan.sh" --format json ${ROOTS[@]+"${ROOTS[@]}"} > "$SCAN" || exit 1

[ "$APPLY" = 1 ] && require_op

python3 "$LIB_DIR/backup.py" \
  --scan "$SCAN" --vault "$VAULT" --tag "$TAG" ${PYARGS[@]+"${PYARGS[@]}"}
