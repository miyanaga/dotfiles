#!/usr/bin/env bash
# 旧マシンで実行: 新マシンへ移行するシークレット類を
# パスフレーズ付き暗号化アーカイブにまとめる。
#
# 含まれるもの:
#   ~/.ssh のうち: config（とそのInclude先）、configで参照している鍵(+.pub)、
#                  デフォルト名の鍵(id_rsa/id_ed25519等)、authorized_keys、known_hosts
#   ~/.zsh_secrets ~/.aws ~/.npmrc（存在すれば）
#   ~/.config 一式（gcloud/gh/firebase等のアプリ認証。キャッシュ類は除外）
# 含まれないもの:
#   configから参照されていない鍵 → 移行しない方針。
#   整理・削除の前に backup-to-1password.sh でフルバックアップを取っておくこと。
#
# 使い方: ./export.sh [出力先ファイル]   （省略時はデスクトップ）
#         ./export.sh --list             （含まれるファイル一覧の確認のみ）
set -euo pipefail

FILES=()
add() {
  local p="$1"
  [[ -e "$HOME/$p" ]] || return 0
  local f
  for f in "${FILES[@]:-}"; do [[ "$f" == "$p" ]] && return 0; done  # 重複排除
  FILES+=("$p")
}

# ホームからの相対パスに正規化（~/ や絶対パスを剥がす）
rel() { local p="$1"; p="${p/#\~\//}"; p="${p/#$HOME\//}"; printf '%s' "$p"; }

add .ssh/config
add .ssh/known_hosts
add .ssh/authorized_keys

# configのInclude先（~/.ssh 内のみ。orbstack等が生成するものは新マシンで再生成される）
while read -r inc; do
  inc="$(rel "$inc")"
  [[ "$inc" == .ssh/* ]] && add "$inc"
done < <(awk 'tolower($1)=="include"{print $2}' "$HOME/.ssh/config" 2>/dev/null)

# configで参照している鍵 + デフォルト名の鍵
while read -r key; do
  key="$(rel "$key")"
  [[ "$key" == .ssh/* ]] || continue   # ~/.ssh 外（orbstack等マシン固有のもの）は対象外
  add "$key"
  add "$key.pub"
done < <(
  { awk 'tolower($1)=="identityfile"{gsub(/"/,""); print $2}' "$HOME/.ssh/config" 2>/dev/null
    printf '%s\n' '~/.ssh/id_rsa' '~/.ssh/id_ed25519' '~/.ssh/id_ecdsa'; } | sort -u
)

# シェル用シークレットとクラウド系クレデンシャル
add .zsh_secrets
add .aws
add .npmrc

# アプリケーション設定・認証（~/.config）。キャッシュ・再生成可能なものは下のtarで除外
add .config

echo "アーカイブに含めるもの:"
printf '  %s\n' "${FILES[@]}"
echo

if [[ "${1:-}" == "--list" ]]; then
  exit 0
fi

OUT="${1:-$HOME/Desktop/secrets-backup-$(date +%Y%m%d).tar.gz.enc}"

echo "パスフレーズを設定します（復元時に同じものを入力します）"
tar czf - -C "$HOME" \
  --exclude '*.DS_Store' \
  --exclude '*/node_modules' \
  --exclude '*/node_modules/*' \
  --exclude '.config/yarn/global' \
  --exclude '.config/gcloud/virtenv' \
  --exclude '.config/gcloud/logs' \
  --exclude '.config/browseruse/extensions' \
  --exclude '.config/browseruse/profiles' \
  --exclude '.config/zed/settings.json' \
  --exclude '.config/wezterm' \
  --exclude '.config/starship.toml' \
  "${FILES[@]}" \
  | openssl enc -aes-256-cbc -pbkdf2 -salt -out "$OUT"

echo
echo "作成しました: $OUT"
echo "これを AirDrop 等で新マシンに送り、ssh/import.sh で復元してください。"
echo "復元を確認したら、このファイルは両方のマシンから削除してください。"
