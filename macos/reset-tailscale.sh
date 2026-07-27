#!/usr/bin/env bash
# Tailscale (macOS Standalone / macsys版) の「デバイス身元」を完全リセットする。
#
#   ./macos/reset-tailscale.sh            リセット実行（確認あり）
#   ./macos/reset-tailscale.sh --list     何を削除するか一覧するだけ（削除しない）
#   ./macos/reset-tailscale.sh --yes       確認プロンプトを飛ばして実行
#
# ■ いつ使うか
#   Time Machine で旧Macから移行したり、ディスクをクローンしたりすると、
#   Tailscale の「machine key（=デバイスの永続的な身元）」まで一緒にコピーされる。
#   その結果、旧Macと新Macが admin コンソール上で同じデバイス扱いになり、
#   同じ 100.x.x.x を奪い合って名前が入れ替わる（"Duplicate node key" バッジが付く）。
#   このスクリプトは、そのローカル身元を全消しして、ログインし直したときに
#   新しい machine key・新しい IP で「別デバイス」として登録され直すようにする。
#
# ■ 決定打はどこにあったか（ハマりどころ）
#   身元は /Library/Tailscale ではなく、**System keychain の generic-password**
#   （tailscale-current-profile / tailscale-profiles / tailscale-id-profile-* /
#     tailscale-logdata など）に保存されている。
#   だから `brew uninstall` や `rm -rf /Library/Tailscale` を何度やっても、
#   起動のたびにここから旧身元が復元されて元の m4pro に戻ってしまう。
#   → keychain のこれらを消すのが本丸。
#
# ■ 前提 / 注意
#   - macsys版（tailscale.com か Homebrew cask `tailscale-app` の GUI アプリ）向け。
#     App Store版(io.tailscale.ipn.macos)の項目名にも対応させてある。
#   - keychain と /Library/Tailscale の削除に root が要るので sudo パスワードを聞かれる。
#   - 実行後は **再起動 → Tailscale アプリを起動 → ログイン** が必要（下に手順を表示する）。
#   - 旧Mac側はそのまま。分離したいのは「移行してきた新Mac」の身元。
#
# 公式リファレンス:
#   https://tailscale.com/docs/reference/troubleshooting/network-configuration/multiple-devices-same-100.x-ip-address
#   https://tailscale.com/docs/features/client/uninstall
set -euo pipefail

LIST_ONLY=false
ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --list) LIST_ONLY=true ;;
    --yes|-y) ASSUME_YES=true ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

SYSTEM_KEYCHAIN="/Library/Keychains/System.keychain"
LOGIN_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# 削除対象のファイル / コンテナ（macsys と macos の両方をカバー）。
USER_PATHS=(
  "/Library/Tailscale"
  "$HOME/Library/Preferences/io.tailscale.ipn.macsys.plist"
  "$HOME/Library/Preferences/io.tailscale.ipn.macos.plist"
  "$HOME/Library/Caches/io.tailscale.ipn.macsys"
  "$HOME/Library/Caches/io.tailscale.ipn.macos"
  "$HOME/Library/HTTPStorages/io.tailscale.ipn.macsys"
  "$HOME/Library/HTTPStorages/io.tailscale.ipn.macos"
)
# glob で広がるもの（存在しなくてもよい）。
USER_GLOBS=(
  "$HOME/Library/Containers/"*io.tailscale.ipn.mac*
  "$HOME/Library/Application Scripts/"*io.tailscale.ipn.mac*
  "$HOME/Library/Group Containers/"*io.tailscale.ipn.mac*
)

# System keychain 内の tailscale-* generic-password のアカウント名を列挙する。
# （dump-keychain は root でないと中身まで見えないため sudo を使う）
list_keychain_accounts() {
  sudo security dump-keychain "$SYSTEM_KEYCHAIN" 2>/dev/null \
    | grep -oE 'tailscale-[A-Za-z0-9._-]+' | sort -u || true
}

echo "==> Tailscale reset (macsys) — デバイス身元の完全リセット"
echo

# --- 削除対象のプレビュー ---------------------------------------------------
echo "[1] System keychain の項目（← これが本丸）:"
ACCOUNTS="$(list_keychain_accounts)"
if [[ -n "$ACCOUNTS" ]]; then
  echo "$ACCOUNTS" | sed 's/^/    - /'
else
  echo "    (なし)"
fi

echo "[2] ファイル / コンテナ:"
for p in "${USER_PATHS[@]}"; do
  [[ -e "$p" ]] && echo "    - $p"
done
for p in "${USER_GLOBS[@]}"; do
  [[ -e "$p" ]] && echo "    - $p"
done

echo

if $LIST_ONLY; then
  echo "--list 指定のため、ここまで（何も削除していません）。"
  exit 0
fi

if ! $ASSUME_YES; then
  printf "上記をすべて削除します。よろしいですか? [y/N] "
  read -r reply
  [[ "$reply" == "y" || "$reply" == "Y" ]] || { echo "中止しました。"; exit 1; }
fi

# --- 1) アプリと拡張を止める（動いていると keychain / 状態を書き戻すため）-------
echo "==> Tailscale アプリを終了..."
osascript -e 'tell application "Tailscale" to quit' >/dev/null 2>&1 || true
# systemextension のデーモンプロセスも念のため止める（best-effort。再起動で確実化）。
sudo pkill -f 'io.tailscale.ipn.mac.*network-extension' 2>/dev/null || true
sleep 2

# --- 2) System keychain の tailscale-* を全削除 -----------------------------
echo "==> System keychain の tailscale-* を削除..."
for acct in $(list_keychain_accounts); do
  echo "    - $acct"
  # 同名が複数あることがあるので、消えるまで繰り返す。
  while sudo security delete-generic-password -a "$acct" "$SYSTEM_KEYCHAIN" >/dev/null 2>&1; do :; done
done
# ログイン keychain 側にも念のため（App Store版など）。
if [[ -f "$LOGIN_KEYCHAIN" ]]; then
  for acct in $(security dump-keychain "$LOGIN_KEYCHAIN" 2>/dev/null \
                | grep -oE 'tailscale-[A-Za-z0-9._-]+' | sort -u); do
    echo "    - (login) $acct"
    while security delete-generic-password -a "$acct" "$LOGIN_KEYCHAIN" >/dev/null 2>&1; do :; done
  done
fi

# --- 3) ファイル / コンテナを削除 -------------------------------------------
echo "==> 状態ファイル / コンテナを削除..."
for p in "${USER_PATHS[@]}"; do
  if [[ -e "$p" ]]; then
    echo "    - $p"
    sudo rm -rf "$p"
  fi
done
for p in "${USER_GLOBS[@]}"; do
  if [[ -e "$p" ]]; then
    echo "    - $p"
    rm -rf "$p"
  fi
done

# --- 4) 検証 ----------------------------------------------------------------
echo "==> 検証: System keychain に tailscale-* が残っていないか..."
REMAIN="$(list_keychain_accounts)"
if [[ -n "$REMAIN" ]]; then
  echo "    ⚠️  まだ残っています:"
  echo "$REMAIN" | sed 's/^/       - /'
  echo "    アプリ/拡張がまだ動いて書き戻している可能性大。一度再起動してから再実行してください。"
else
  echo "    OK（空）"
fi

cat <<EOF

============================================================
リセット完了。あとは次の順で新しい身元として登録し直す:

  1. Mac を再起動        ← keychainキャッシュと拡張を確実にクリア（重要）
  2. Tailscale アプリを起動してログイン
  3. 確認:  tailscale status
       - 自分の行の IP が以前と違う新しいアドレスになっていること
       - 名前が このMacのホスト名 ($(scutil --get LocalHostName 2>/dev/null || hostname)) になっていること
  4. admin コンソールで古い重複デバイスを削除:
       https://login.tailscale.com/admin/machines
       （"Duplicate node key" バッジが付いた古い方を削除）
============================================================
EOF
