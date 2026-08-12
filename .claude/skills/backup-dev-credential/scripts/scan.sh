#!/usr/bin/env bash
# 開発ツリーを走査して「gitに入っていないクレデンシャルファイル」を列挙する。
#
# gitに追跡されているファイルは対象外（既にリポジトリに入っている＝失っても復元できる）。
# .gitignore で除外されているもの・未追跡のものだけを拾う。
#
# 使い方:
#   ./scan.sh                      # ~/dev と ~/m4pro/dev を走査
#   ./scan.sh ~/dev                # ルートを指定
#   ./scan.sh --format json        # JSONで出力
#
# 出力(TSV): キー \t リポジトリroot \t 相対パス \t 状態 \t サイズ \t sha256
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

FORMAT=tsv
ROOTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2;;
    -h|--help) usage "$0"; exit 0;;
    *) ROOTS+=("$1"); shift;;
  esac
done
[ ${#ROOTS[@]} -eq 0 ] && ROOTS=("${DEFAULT_ROOTS[@]}")

IGNORE_FILE="$SKILL_DIR/ignore.txt"

# 走査から丸ごと外すディレクトリ名（依存物・ビルド生成物・テスト用に落としてくるもの）
PRUNE_DIRS=(node_modules .git vendor dist build .next .nuxt .venv venv __pycache__
            .terraform Pods deps _build target coverage .cache .vscode-test
            worktrees .worktrees .pnpm-store .yarn Carthage DerivedData)

prune_expr=()
for d in "${PRUNE_DIRS[@]}"; do prune_expr+=(-name "$d" -o); done
unset 'prune_expr[${#prune_expr[@]}-1]'

# クレデンシャルらしいファイル名のパターン
name_expr=(
  -name '.env' -o -name '.env.*' -o -name '*.env' -o
  -iname '*service-account*.json' -o -iname '*serviceaccount*.json' -o
  -iname '*firebase-admin*.json' -o -iname '*-adminsdk-*.json' -o
  -iname '*credential*.json' -o -iname '*secret*.json' -o -iname '*secrets*.yml' -o
  -iname '*secrets*.yaml' -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o
  -name '*.pfx' -o -name '*.p8' -o -name '*.jks' -o -name '*.keystore' -o
  -name '.npmrc' -o -name '.netrc' -o -name '.pypirc' -o -name 'key.json' -o
  -name 'gcp*.json' -o -name '*.mobileprovision' -o -name 'terraform.tfvars'
)

# ignore.txt のパターンに当たるか（シェルのグロブで判定）
matches_ignore() {
  local path="$1" pat
  [ -f "$IGNORE_FILE" ] || return 1
  while IFS= read -r pat; do
    case "$pat" in ''|'#'*) continue;; esac
    # shellcheck disable=SC2254
    case "$path" in $pat) return 0;; esac
  done < "$IGNORE_FILE"
  return 1
}

for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || { echo "警告: $root がありません" >&2; continue; }
  find "$root" \( "${prune_expr[@]}" \) -prune -o -type f \( "${name_expr[@]}" \) -print 2>/dev/null
done | while IFS= read -r f; do
  base="$(basename "$f")"
  # 雛形は中身が無いので対象外
  case "$base" in
    *.example|*.sample|*.dist|*.template|example*|sample*) continue;;
  esac

  dir="$(dirname "$f")"
  repo="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || continue
  [ -n "$repo" ] || continue

  rel="${f#$repo/}"
  matches_ignore "$rel" && continue
  matches_ignore "$f" && continue

  # gitに追跡済みなら対象外。ignoreされているか未追跡のものだけ拾う。
  if git -C "$repo" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    continue
  elif git -C "$repo" check-ignore -q "$f" 2>/dev/null; then
    state=ignored
  else
    state=untracked
  fi

  [ -s "$f" ] || continue   # 空ファイルは保存しても意味がない

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(repo_key "$repo")" "$repo" "$rel" "$state" \
    "$(file_size "$f")" "$(file_sha256 "$f")"
done | sort -u > "${TMPDIR:-/tmp}/devcred-scan.$$"

# 同じリポジトリを複数箇所にcloneしている場合、(キー, 相対パス) が重複する。
# 中身が同じなら1件に畳み、違うなら新しい方を採用して警告する。
python3 "$LIB_DIR/group.py" "${TMPDIR:-/tmp}/devcred-scan.$$" "$FORMAT"
rc=$?
rm -f "${TMPDIR:-/tmp}/devcred-scan.$$"
exit $rc
