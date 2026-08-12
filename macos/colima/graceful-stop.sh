#!/usr/bin/env bash
# colima-graceful-stop - ログアウト/シャットダウン時に colima を安全に停止する常駐スクリプト
#
# なぜ必要か:
#   `colima stop` を経ずに Mac を落とすと、VM のデータディスク(ext4)が書き込み途中で
#   切られて壊れる。実際に multiply-claimed block が1万件出て、docker イメージを
#   全ロストしたことがある（2026-07-26）。毎回手で stop するのを忘れないのは無理なので
#   機械にやらせる。
#
# 仕組み:
#   LaunchAgent (com.miyanaga.colima-graceful-stop) として常駐し、普段は寝ているだけ。
#   ログアウト/シャットダウン時に launchd が SIGTERM を送ってくるので、それを trap して
#   `colima stop` を実行してから終了する。
#
# ログ: ~/Library/Logs/colima-graceful-stop.log
#
# 限界:
#   電源断・カーネルパニック・電源ボタン長押しは、どんな仕組みでも捕まえられない。
#   その保険として colima-fsck（同ディレクトリの fsck.sh）で健全性を確認する。
set -uo pipefail

LOG="$HOME/Library/Logs/colima-graceful-stop.log"

log() {
  printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$*" >>"$LOG"
}

# launchd から起動されると PATH が最小限（/usr/bin:/bin:/usr/sbin:/sbin）なので
# Homebrew の colima を明示的に探す。Apple Silicon / Intel の両方に対応。
find_colima() {
  local candidate
  for candidate in /opt/homebrew/bin/colima /usr/local/bin/colima "$HOME/.local/bin/colima"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  command -v colima 2>/dev/null
}

# プロファイル一覧は ~/.colima/<profile>/ から得る。
# `colima list` を叩かないのは、シャットダウン中に外部コマンドが固まると
# 停止処理そのものが間に合わなくなるため（ディレクトリを見るだけなら固まらない）。
list_profiles() {
  local dir name
  for dir in "$HOME/.colima"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue # _lima / _store / _templates は内部用
    printf '%s\n' "$name"
  done
}

on_terminate() {
  trap '' TERM INT HUP # 停止処理中の二重発火を防ぐ

  local profile rc stopped=0
  log "SIGTERM を受信（ログアウト/シャットダウン）。colima を停止する"

  while IFS= read -r profile; do
    [[ -n "$profile" ]] || continue
    # 停止済みプロファイルに対しても 0.2 秒程度で返るので、実行中かの判定は省略。
    # --force は使わない（graceful shutdown を飛ばすと本末転倒）。
    "$COLIMA" stop --profile "$profile"
    rc=$?
    log "  profile=$profile colima stop exit=$rc"
    stopped=$((stopped + 1))
  done < <(list_profiles)

  log "完了（$stopped プロファイルを処理）"
  exit 0
}

mkdir -p "$(dirname "$LOG")"

# launchd 配下では stdout/stderr の行き先がないので、予期しない出力も含めて全部ログに送る。
# （そのため、手で直接叩くと端末には何も出ずログに出る。動作確認は tail -f で見ること）
exec >>"$LOG" 2>&1

COLIMA="$(find_colima)"
if [[ -z "$COLIMA" ]]; then
  log "colima が見つからないので何もせず終了する"
  exit 0
fi

# colima 自身が limactl（と docker）を PATH から探すため、Homebrew の bin を通しておく。
# launchd 配下の PATH は /usr/bin:/bin:/usr/sbin:/sbin だけなので、これを忘れると
#   Error: dependency check failed for VM: lima not found
# で停止に失敗する（ログには出るが、気づかないまま毎回壊れることになる）。
export PATH="$(dirname "$COLIMA"):/opt/homebrew/bin:/usr/local/bin:$PATH"

trap on_terminate TERM INT HUP

log "常駐開始 (pid=$$, colima=$COLIMA)"

# sleep を直接 foreground で実行すると、bash が trap を sleep 終了まで遅延させてしまう。
# バックグラウンドに回して wait することで SIGTERM を即座に処理できる。
while :; do
  sleep 86400 &
  wait $! 2>/dev/null
done
