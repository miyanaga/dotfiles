#!/usr/bin/env bash
# colima-fsck - colima のデータディスク(ext4)の健全性を確認し、必要なら修復する
#
# なぜ必要か:
#   colima のイメージ・レイヤーは VM 内の専用データディスク（ext4, /dev/vdb1）に載っている。
#   `colima stop` を経ずに Mac が落ちるとここが壊れ、containerd が
#     panic: freepages: failed to get all reachable pages
#   で起動しなくなる。しかも壊れたまま使い続けると被害が累積する（2026-07-26 の事例では
#   2回の異常終了を経て multiply-claimed block が1万件に達し、イメージを全ロストした）。
#   colima-graceful-stop で異常終了自体は防いでいるが、電源断やカーネルパニックは
#   捕まえられないので、起動時に「壊れていないか」を早期に検知する。
#
# 使い方:
#   colima-fsck                 健全性チェックのみ（読み取りのみ・無害）
#   colima-fsck --quiet         問題がなければ何も出力しない（zsh の colima ラッパー用）
#   colima-fsck --repair        e2fsck -fy で修復を試みる（サービス停止と colima 再起動を伴う）
#   colima-fsck --reformat      データディスクを作り直す（最終手段・イメージは全消失）
#   colima-fsck --help          このヘルプ
#
# オプション:
#   -p, --profile <name>        対象の colima プロファイル（既定: default）
#   -y, --yes                   --repair / --reformat の確認プロンプトを省略
#
# 終了コード:
#   0  健全（--repair / --reformat では成功）
#   1  破損を検出（または修復に失敗）
#   2  チェックできなかった（colima が起動していない等）
set -uo pipefail

PROFILE="default"
MODE="check"
QUIET=0
ASSUME_YES=0

usage() {
  sed -n '2,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//; $d'
}

die() {
  printf 'colima-fsck: %s\n' "$*" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --check) MODE="check" ;;
  --repair) MODE="repair" ;;
  --reformat) MODE="reformat" ;;
  --quiet | -q) QUIET=1 ;;
  -y | --yes) ASSUME_YES=1 ;;
  -p | --profile)
    [[ $# -ge 2 ]] || die "--profile には値が必要"
    PROFILE="$2"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *) die "不明な引数: $1（--help を参照）" ;;
  esac
  shift
done

say() { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }

command -v colima >/dev/null 2>&1 || die "colima が見つからない"

# VM 内で bash スクリプトを実行する（スクリプトは stdin から渡す）
vm() { colima ssh --profile "$PROFILE" -- bash -s; }

if ! colima status --profile "$PROFILE" >/dev/null 2>&1; then
  # --quiet（colima ラッパーからの自動実行）では、起動していないだけの状態は黙って諦める。
  # 異常ではないので警告を出すとノイズになる。
  [[ $QUIET -eq 1 ]] && exit 2
  die "colima (profile=$PROFILE) が起動していないためチェックできない"
fi

# --- 健全性チェック（読み取りのみ） ---------------------------------------
probe() {
  vm <<'REMOTE'
set -uo pipefail
dev=$(findmnt -no SOURCE /var/lib/docker 2>/dev/null)
dev=${dev%%[*}   # バインドマウントの "[/docker]" を落とす
printf 'DEV=%s\n' "$dev"
[ -n "$dev" ] || exit 0
sudo tune2fs -l "$dev" 2>/dev/null | sed -n \
  -e 's/^Filesystem state: *\(.*\)$/STATE=\1/p' \
  -e 's/^FS Error count: *\(.*\)$/ERRORS=\1/p' \
  -e 's/^First error time: *\(.*\)$/FIRST=\1/p' \
  -e 's/^Last error time: *\(.*\)$/LAST=\1/p'
printf 'CONTAINERD=%s\n' "$(systemctl is-active containerd.service 2>/dev/null)"
printf 'DOCKER=%s\n' "$(systemctl is-active docker.service 2>/dev/null)"

# サービスが落ちているときは原因の手がかりも拾う（bbolt の panic 等）。
# grep が何も見つけないと pipefail で全体が失敗扱いになるので || true で吸収する。
if [ "$(systemctl is-active containerd.service 2>/dev/null)" != "active" ]; then
  { sudo journalctl -u containerd.service --no-pager -n 300 2>/dev/null |
    grep -E 'panic:|level=error|Failed to start' | tail -3 |
    sed 's/^/CERR=/'; } || true
fi
exit 0
REMOTE
}

field() { printf '%s\n' "$PROBE" | sed -n "s/^$1=//p" | head -1; }

run_check() {
  PROBE="$(probe)" || die "VM 内のチェックに失敗した"

  local dev state errors first last containerd docker
  dev="$(field DEV)"
  state="$(field STATE)"
  errors="$(field ERRORS)"
  first="$(field FIRST)"
  last="$(field LAST)"
  containerd="$(field CONTAINERD)"
  docker="$(field DOCKER)"

  [[ -n "$dev" ]] || die "データディスクを特定できなかった（/var/lib/docker が未マウント）"

  # ファイルシステム自体の異常と、サービスが落ちているだけの状態は区別する。
  # （FS が clean なのに --repair を勧めると、無意味な e2fsck や再作成に誘導してしまう）
  local fs_bad=0 svc_bad=0
  [[ "$state" == "clean" ]] || fs_bad=1
  [[ -z "$errors" || "$errors" == "0" ]] || fs_bad=1
  [[ "$containerd" == "active" && "$docker" == "active" ]] || svc_bad=1

  if [[ $fs_bad -eq 0 && $svc_bad -eq 0 ]]; then
    say "colima データディスク ($dev) は健全: state=$state / containerd=$containerd / docker=$docker"
    return 0
  fi

  local cerr
  cerr="$(printf '%s\n' "$PROBE" | sed -n 's/^CERR=//p')"

  # 問題があるときは --quiet でも必ず出す
  warn ""
  if [[ $fs_bad -eq 1 ]]; then
    warn "⚠️  colima のデータディスク(ext4)が壊れています (profile=$PROFILE, device=$dev)"
    warn "    Filesystem state : ${state:-unknown}"
    [[ -n "$errors" ]] && warn "    FS Error count   : $errors"
    [[ -n "$first" ]] && warn "    First error      : $first"
    [[ -n "$last" ]] && warn "    Last error       : $last"
  else
    warn "⚠️  docker / containerd が起動していません (profile=$PROFILE, device=$dev)"
    warn "    ファイルシステム自体は clean です（state=${state}）"
  fi
  warn "    containerd       : ${containerd:-unknown}"
  warn "    docker           : ${docker:-unknown}"

  if [[ -n "$cerr" ]]; then
    warn ""
    warn "    containerd のログ:"
    printf '      %s\n' "$cerr" >&2
  fi

  warn ""
  if [[ "$cerr" == *freepages* || "$cerr" == *bbolt* ]]; then
    # メタデータDB(bbolt)の内部破損。ファイルの中身が壊れているので e2fsck では直らない。
    warn "    containerd のメタデータDB(bbolt)が壊れています。これは e2fsck では直りません。"
    warn "    データディスクを作り直してください（イメージは再 pull / 再ビルドで戻ります）:"
    warn "      colima-fsck --reformat"
  elif [[ $fs_bad -eq 1 ]]; then
    warn "    放置すると被害が累積します（異常終了を重ねるほど悪化する）。早めに修復してください:"
    warn "      colima-fsck --repair"
  else
    warn "    まずは起動を試してください:"
    warn "      colima ssh -- sudo systemctl start containerd.service docker.socket docker.service"
    warn "    直らない場合は原因を確認:"
    warn "      colima ssh -- sudo journalctl -u containerd.service --no-pager -n 50"
  fi
  warn ""
  return 1
}

# --- 確認プロンプト -------------------------------------------------------
confirm() {
  local prompt="$1" answer
  [[ $ASSUME_YES -eq 1 ]] && return 0
  if [[ ! -t 0 ]]; then
    die "確認が必要な操作です。対話端末から実行するか --yes を付けてください"
  fi
  printf '%s\n' "$prompt"
  printf "続行するには yes と入力: "
  read -r answer
  [[ "$answer" == "yes" ]]
}

# --- 修復 (e2fsck -fy) ----------------------------------------------------
run_repair() {
  confirm "
これから以下を実行します (profile=$PROFILE):
  1. VM 内の docker / containerd を停止
  2. データディスクの全マウントを解除
  3. e2fsck -fy で修復（破損が大きいと数十分かかることがあります）
  4. colima を再起動してマウントを復元

実行中のコンテナは停止します。" || {
    say "中止しました"
    return 2
  }

  say "==> VM 内で修復を実行中..."
  local out rc
  out="$(vm <<'REMOTE'
set -uo pipefail
dev=$(findmnt -no SOURCE /var/lib/docker 2>/dev/null)
dev=${dev%%[*}
[ -n "$dev" ] || { echo "データディスクを特定できない" >&2; exit 1; }
echo "device: $dev"

sudo systemctl stop docker.socket docker.service containerd.service 2>/dev/null
sudo systemctl reset-failed containerd.service 2>/dev/null

# バインドマウントを深い方（/var/lib/*）から先に外す
mount | awk -v d="$dev" '$1 == d {print $3}' | sort -r | while read -r m; do
  if sudo umount "$m"; then echo "umount ok: $m"; else echo "umount 失敗: $m" >&2; fi
done

if mount | awk -v d="$dev" '$1 == d {found=1} END {exit !found}'; then
  echo "マウントを解除しきれなかったため中止" >&2
  exit 1
fi

sudo e2fsck -fy "$dev"
echo "E2FSCK_EXIT=$?"
REMOTE
  )"
  rc=$?
  printf '%s\n' "$out"

  local fsck_exit
  fsck_exit="$(printf '%s\n' "$out" | sed -n 's/^E2FSCK_EXIT=//p' | head -1)"

  say ""
  say "==> colima を再起動してマウントを復元..."
  colima restart --profile "$PROFILE" || die "colima restart に失敗した"

  if [[ $rc -ne 0 || -z "$fsck_exit" ]]; then
    warn "修復処理が途中で失敗しました。上の出力を確認してください"
    return 1
  fi

  # e2fsck の終了コードはビットフラグ: 1=修正した, 2=修正+要再起動, 4=未修正の破損が残る, 8=実行エラー
  if ((fsck_exit & 4)) || ((fsck_exit & 8)); then
    warn ""
    warn "⚠️  e2fsck が修復しきれませんでした (exit=$fsck_exit)"
    warn "    データディスクを作り直すのが確実です（イメージは全消失しますが再 pull / 再ビルドで戻ります）:"
    warn "      colima-fsck --reformat"
    warn ""
    return 1
  fi

  say ""
  say "==> 修復後の状態を再確認..."
  QUIET=0 run_check
}

# --- 作り直し (mkfs.ext4) -------------------------------------------------
run_reformat() {
  confirm "
⚠️  データディスクを作り直します (profile=$PROFILE)。

  docker イメージ・ビルドキャッシュ・named volume は すべて消えます。
  （ラベルと UUID は維持するので colima 側の設定変更は不要です）

  e2fsck で直らないほど壊れている場合の最終手段です。" || {
    say "中止しました"
    return 2
  }

  say "==> VM 内でデータディスクを作り直し中..."
  vm <<'REMOTE' || die "作り直しに失敗した"
set -uo pipefail
dev=$(findmnt -no SOURCE /var/lib/docker 2>/dev/null)
dev=${dev%%[*}
[ -n "$dev" ] || { echo "データディスクを特定できない" >&2; exit 1; }

label=$(sudo blkid -o value -s LABEL "$dev" 2>/dev/null)
uuid=$(sudo blkid -o value -s UUID "$dev" 2>/dev/null)
echo "device=$dev label=${label:-none} uuid=${uuid:-none}"

sudo systemctl stop docker.socket docker.service containerd.service 2>/dev/null
sudo systemctl reset-failed containerd.service 2>/dev/null

mount | awk -v d="$dev" '$1 == d {print $3}' | sort -r | while read -r m; do
  if sudo umount "$m"; then echo "umount ok: $m"; else echo "umount 失敗: $m" >&2; fi
done

if mount | awk -v d="$dev" '$1 == d {found=1} END {exit !found}'; then
  echo "マウントを解除しきれなかったため中止" >&2
  exit 1
fi

# 元のラベルと UUID を維持する（lima のマウント設定を変えずに済ませるため）
opts=(-F)
[ -n "$label" ] && opts+=(-L "$label")
[ -n "$uuid" ] && opts+=(-U "$uuid")
sudo mkfs.ext4 "${opts[@]}" "$dev"
REMOTE

  say ""
  say "==> colima を再起動してマウントを復元..."
  colima restart --profile "$PROFILE" || die "colima restart に失敗した"

  say ""
  say "==> 作り直し後の状態を確認..."
  QUIET=0 run_check
}

case "$MODE" in
check) run_check ;;
repair) run_repair ;;
reformat) run_reformat ;;
esac
