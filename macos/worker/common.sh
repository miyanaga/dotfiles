#!/usr/bin/env bash
# worker/common.sh - setup.sh / setdown.sh の共通実体。
# 直接実行せず、MODE=on|off を定義した上で source される。
#
# 「ワーカーモード」= 自宅に据え置き、Tailscale経由でリモート操作するMacの状態。
#   setup.sh  … ワーカーモードにする    (MODE=on)
#   setdown.sh… 普段使いのMacに戻す      (MODE=off)
#
# 設計方針:
#   - 冪等。何度実行しても同じ状態に収束する。
#   - 「適用 → 検証」を必ずセットで行い、期待どおりでなければ終了コード1。
#   - セキュリティ側に倒す項目（FileVault・自動ログイン・即時ロック）は
#     setdown でも元に戻さない。「便利に戻す」ために穴を開けるのは目的ではない。
#   - 戻し先の基準は macOS の工場出荷値ではなく **macos/defaults.sh の値**。
#     2つのスクリプトが同じ項目を取り合わないようにするため。
set -euo pipefail

# --- 引数 -------------------------------------------------------------------
CHECK_ONLY=false
ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
  --check) CHECK_ONLY=true ;;
  --yes | -y) ASSUME_YES=true ;;
  -h | --help)
    cat <<EOF
$(basename "$0") — $([[ "$MODE" == on ]] && echo "Macをワーカーモード（リモート運用）にする" || echo "ワーカーモードを解除して普段使いのMacに戻す")

  $(basename "$0")          適用して検証（何度実行しても安全）
  $(basename "$0") --check  適用せず、現在値が期待どおりかの検証だけ
  $(basename "$0") --yes    確認プロンプトを飛ばす

いずれもroot権限が要るためsudoのパスワードを聞かれる（--check も同じ。
Remote Login や Screen Sharing の状態はrootでないと読めないため）。
EOF
    exit 0
    ;;
  *)
    echo "unknown option: ${arg}（--help を参照）" >&2
    exit 2
    ;;
  esac
done

LOGINWINDOW="/Library/Preferences/com.apple.loginwindow"
SOFTWAREUPDATE="/Library/Preferences/com.apple.SoftwareUpdate"
UNSET="(未設定)"

# --- モードごとの期待値 -----------------------------------------------------
# 空文字ではなく "(未設定)" を期待値に使う。「キーを消して既定に戻す」ことも
# 「ある値を書く」ことと同じ形で検証できるようにするため。
if [[ "$MODE" == "on" ]]; then
  MODE_LABEL="ワーカーモード ON"
  WANT_SSH="on"           # リモートログイン(SSH)。FileVaultのリモート解除にも要る
  WANT_SCREENSHARING="on" # 画面共有
  WANT_FDEAUTOLOGIN="1"   # FileVault解除後に自動ログインしない = ログイン画面で待機
  WANT_IDLETIME="300"     # スクリーンセーバ開始 5分
  WANT_DISPLAYSLEEP="5"   # 画面オフ 5分（席にいないので早めに消す）
  WANT_POWERFAILURE="on"  # 停電復帰後に自動で起動
  WANT_AUTOOSUPDATE="0"   # macOSアップデートの自動インストール(=勝手な再起動)を止める
else
  MODE_LABEL="ワーカーモード OFF（普段使いに戻す）"
  WANT_SSH="off"
  WANT_SCREENSHARING="off"
  WANT_FDEAUTOLOGIN="$UNSET"
  WANT_IDLETIME="$UNSET" # macOS既定（20分）に戻す
  WANT_DISPLAYSLEEP="10" # macos/defaults.sh の値
  WANT_POWERFAILURE="off"
  WANT_AUTOOSUPDATE="1"
fi

# --- 前提チェック -----------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || {
  echo "macOS専用です。" >&2
  exit 2
}

echo "==> $MODE_LABEL"
echo

# 読み取りにもrootが要る項目（systemsetup / launchctl print system）があるため、
# --check でも最初にsudoを取る。ここで一度キャッシュしておくと以降は聞かれない。
echo "システム設定の読み書きにsudoが必要です。"
sudo -v || {
  echo "sudoが使えません（管理者アカウントで実行してください）。" >&2
  exit 2
}

# --- FileVault: 常にON（モードによらず） ------------------------------------
# 盗難・持ち出し時の唯一の防御線なので、ワーカーを解除しても外さない。
fv_state() {
  case "$(fdesetup status 2>/dev/null | head -1)" in
  *"FileVault is On"*) echo on ;;
  *"FileVault is Off"*) echo off ;;
  *) echo unknown ;;
  esac
}

if [[ "$(fv_state)" != "on" ]]; then
  cat <<'EOF' >&2

⚠️  FileVaultがOFFです。このスクリプトは続行しません。

  FileVaultは自動で有効化しません。復旧キーを必ず1Passwordに保管してほしいので、
  意図的に手作業に残しています（`fdesetup enable` はFull Disk Accessも要求します）。

  有効化の手順:
    1. システム設定 > プライバシーとセキュリティ > FileVault > オンにする
    2. 「復旧キーを作成」を選ぶ（iCloudではなく復旧キー。1Passwordに保存する）
    3. 暗号化の完了を待つ（`fdesetup status` で進捗が見られる）
    4. このスクリプトを再実行

EOF
  exit 1
fi

# --- 状態の読み取り ---------------------------------------------------------

# Remote Login (SSH)。
# `systemsetup -getremotelogin` はrootに加えて端末アプリのFull Disk Accessを
# 要求することがある（"Full Disk Access privileges" というエラーになる）。
# その場合は launchdのジョブが積まれているかで判定する。
read_ssh() {
  local out
  out="$(sudo systemsetup -getremotelogin 2>&1 || true)"
  case "$out" in
  *"Remote Login: On"*) echo on ;;
  *"Remote Login: Off"*) echo off ;;
  *) sudo launchctl print system/com.openssh.sshd >/dev/null 2>&1 && echo on || echo off ;;
  esac
}

# 画面共有。launchdにジョブが積まれていれば有効。
read_screensharing() {
  sudo launchctl print system/com.apple.screensharing >/dev/null 2>&1 && echo on || echo off
}

read_default() { # read_default <ドメイン> <キー> [-currentHost]
  local domain="$1" key="$2"
  shift 2
  defaults "$@" read "$domain" "$key" 2>/dev/null || echo "$UNSET"
}

read_powerfailure() {
  case "$(sudo systemsetup -getrestartpowerfailure 2>&1 || true)" in
  *"Power Failure: On"*) echo on ;;
  *"Power Failure: Off"*) echo off ;;
  *) echo "$UNSET" ;;
  esac
}

# `pmset -g custom` の「AC Power:」ブロックだけを見る（バッテリー時の値は対象外）。
read_pmset_ac() { # read_pmset_ac <キー名>
  local got
  got="$(pmset -g custom | awk -v key="$1" '
    /^AC Power:/ { in_ac = 1; next }
    /^[^ ]/      { in_ac = 0 }
    in_ac && $1 == key { print $2; exit }
  ')"
  printf '%s\n' "${got:-$UNSET}"
}

# 停電復帰後の自動起動は Apple Silicon では非対応のことがある（電源復帰で勝手に
# 起動するのがハード側の既定のため）。pmsetの対応キー一覧で判定して、無ければ触らない。
supports_powerfailure() { pmset -g cap 2>/dev/null | grep -q autorestart; }

# --- 適用 -------------------------------------------------------------------
apply_all() {
  # 1) 自動ログインOFF（常に）。
  #    FileVaultがONなら事実上不可能だが、将来FileVaultを外したときに
  #    「無防備なまま起動する」状態に落ちないよう、鍵そのものを消しておく。
  sudo defaults delete "$LOGINWINDOW" autoLoginUser 2>/dev/null || true
  sudo rm -f /etc/kcpassword

  # 2) FileVault解除後の自動ログインを無効化（= ログイン画面で待機）。
  #    既定ではFileVaultのパスワードを入れるとそのままデスクトップまで入ってしまう。
  #    SSHでリモート解除したときに、誰も座っていないMacでセッションが開くのを防ぐ。
  if [[ "$WANT_FDEAUTOLOGIN" == "$UNSET" ]]; then
    sudo defaults delete "$LOGINWINDOW" DisableFDEAutoLogin 2>/dev/null || true
  else
    sudo defaults write "$LOGINWINDOW" DisableFDEAutoLogin -bool true
  fi

  # 3) Remote Login (SSH)
  set_ssh "$WANT_SSH"

  # 4) 画面共有
  set_screensharing "$WANT_SCREENSHARING"

  # 5) スクリーンセーバ開始までの時間。
  #    ロックまでの猶予（即時かどうか）は後段の検証で見る。sysadminctlが
  #    パスワードを要求するため自動では変えない。
  if [[ "$WANT_IDLETIME" == "$UNSET" ]]; then
    defaults -currentHost delete com.apple.screensaver idleTime 2>/dev/null || true
  else
    defaults -currentHost write com.apple.screensaver idleTime -int "$WANT_IDLETIME"
  fi

  # 6) 電源（電源アダプタ接続時のみ。バッテリー時は既定のまま）。
  #    画面は消えてよいが本体はスリープさせない。スリープするとTailscaleが応答せず
  #    「繋がらないから帰宅するまで何もできない」になる。
  sudo pmset -c sleep 0     # システムスリープしない
  sudo pmset -c disksleep 0 # ディスクもスリープさせない
  sudo pmset -c displaysleep "$WANT_DISPLAYSLEEP"
  sudo pmset -c womp 1 # ネットワークアクセスでスリープ解除

  # 7) 停電から復帰したら自動で起動（対応機種のみ）
  if supports_powerfailure; then
    sudo systemsetup -setrestartpowerfailure "$WANT_POWERFAILURE" >/dev/null 2>&1 || true
  fi

  # 8) macOSアップデートの自動インストール。
  #    自動で再起動されるとFileVaultのロック画面で止まり、リモートから触れなくなる。
  #    ダウンロードとセキュリティ対応(XProtect等)は止めない。更新は fdesetup authrestart で計画的に行う。
  sudo defaults write "$SOFTWAREUPDATE" AutomaticallyInstallMacOSUpdates -bool \
    "$([[ "$WANT_AUTOOSUPDATE" == 1 ]] && echo true || echo false)"
}

set_ssh() { # set_ssh <on|off>
  local want="$1" out
  out="$(sudo systemsetup -setremotelogin -f "$want" 2>&1 || true)"
  if [[ "$out" == *"Full Disk Access"* || "$out" == *"Error"* ]]; then
    # 端末にFull Disk Accessが無いケース。launchdを直接操作して同じ結果にする。
    if [[ "$want" == on ]]; then
      sudo launchctl enable system/com.openssh.sshd
      sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
    else
      sudo launchctl bootout system/com.openssh.sshd 2>/dev/null || true
      sudo launchctl disable system/com.openssh.sshd
    fi
  fi
}

set_screensharing() { # set_screensharing <on|off>
  if [[ "$1" == on ]]; then
    sudo launchctl enable system/com.apple.screensharing
    sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
  else
    sudo launchctl bootout system/com.apple.screensharing 2>/dev/null || true
    sudo launchctl disable system/com.apple.screensharing
  fi
}

# --- 検証 -------------------------------------------------------------------
FAILED=0
WARNED=0

judge() { # judge <説明> <期待値> <実際の値> [期待値の表示文字列]
  local label="$1" want="$2" got="$3" show="${4:-$2}"
  if [[ "$got" == "$want" ]]; then
    printf '  ok    %s: %s\n' "$label" "$got"
  else
    printf '  NG    %s: %s (期待: %s)\n' "$label" "$got" "$show"
    FAILED=$((FAILED + 1))
  fi
}

warn() {
  printf '  警告  %s\n' "$*"
  WARNED=$((WARNED + 1))
}

verify_all() {
  echo "現在値の検証:"
  judge "FileVault"                       "on"  "$(fv_state)"
  judge "自動ログイン(=$UNSET でOFF)"     "$UNSET" "$(read_default "$LOGINWINDOW" autoLoginUser)"
  judge "FileVault解除後の自動ログイン抑止" "$WANT_FDEAUTOLOGIN" "$(read_default "$LOGINWINDOW" DisableFDEAutoLogin)"
  judge "リモートログイン(SSH)"           "$WANT_SSH" "$(read_ssh)"
  judge "画面共有"                        "$WANT_SCREENSHARING" "$(read_screensharing)"
  judge "スクリーンセーバ開始(秒)"        "$WANT_IDLETIME" "$(read_default com.apple.screensaver idleTime -currentHost)"
  judge "電源時: システムスリープ(=0でしない)" "0" "$(read_pmset_ac sleep)"
  judge "電源時: ディスクスリープ(=0でしない)" "0" "$(read_pmset_ac disksleep)"
  judge "電源時: 画面オフまでの分"        "$WANT_DISPLAYSLEEP" "$(read_pmset_ac displaysleep)"
  judge "電源時: ネットワークでスリープ解除(=1)" "1" "$(read_pmset_ac womp)"
  judge "macOS自動アップデート(=0で無効)" "$WANT_AUTOOSUPDATE" "$(read_default "$SOFTWAREUPDATE" AutomaticallyInstallMacOSUpdates)"

  if supports_powerfailure; then
    judge "停電復帰後の自動起動" "$WANT_POWERFAILURE" "$(read_powerfailure)"
  else
    printf '  skip  停電復帰後の自動起動: この機種は非対応（Apple Siliconは電源復帰で自動起動する）\n'
  fi

  # ロックまでの猶予は sysadminctl の管轄で、変更にパスワード入力が要るため検証のみ。
  local screenlock
  screenlock="$(sysadminctl -screenLock status 2>&1 | sed -n 's/.*screenLock delay is //p')"
  if [[ "$screenlock" == "immediate" ]]; then
    printf '  ok    スクリーンセーバ後のロック: 即時\n'
  else
    printf '  NG    スクリーンセーバ後のロック: %s (期待: immediate)\n' "${screenlock:-不明}"
    printf '        直すには: sysadminctl -screenLock immediate -password\n'
    FAILED=$((FAILED + 1))
  fi

  # リモート管理(ARD)は画面共有と排他。両方入れると画面共有が無効化される。
  if [[ -e /Library/Preferences/com.apple.RemoteManagement.plist ]]; then
    warn "リモート管理(Apple Remote Desktop)が有効です。画面共有と競合します。"
    printf '        止めるには: sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off\n'
  fi

  # Tailscaleは「Mac App Store版」だとログイン画面でつながらない（ユーザーセッションが
  # 立ち上がるまで動かないため）。/Library/Tailscale があればシステムデーモン版。
  if [[ "$MODE" == "on" ]]; then
    if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
      printf '  ok    Tailscale: 稼働中 (%s / %s)\n' \
        "$(tailscale ip -4 2>/dev/null | head -1)" "$(scutil --get LocalHostName 2>/dev/null || hostname)"
      [[ -d /Library/Tailscale ]] ||
        warn "システムデーモン版(/Library/Tailscale)ではないため、ログイン画面では接続できない可能性があります。"
    else
      warn "Tailscaleが稼働していません（リモートから到達できません）。"
    fi
  fi
}

# --- 実行 -------------------------------------------------------------------
if [[ "$CHECK_ONLY" == false ]]; then
  # 画面共有・SSHを切ると、その経路で入っているセッション自体が切れる。
  # screensharingd はクライアントが接続している間だけ動くので、それで判定する。
  REMOTE_SESSION=""
  [[ -n "${SSH_CONNECTION:-}" ]] && REMOTE_SESSION="SSH"
  pgrep -x screensharingd >/dev/null 2>&1 && REMOTE_SESSION="${REMOTE_SESSION:+$REMOTE_SESSION / }画面共有"

  if [[ "$WANT_SCREENSHARING" == "off" && -n "$REMOTE_SESSION" ]]; then
    echo
    echo "⚠️  いま $REMOTE_SESSION で接続中です。無効化するとこの接続は切れます。"
    echo "    切れた後は、物理的にこのMacの前に座らないと元に戻せません。"
    if [[ "$ASSUME_YES" == false ]]; then
      printf "続行するには yes と入力: "
      read -r answer
      [[ "$answer" == "yes" ]] || {
        echo "中止しました。"
        exit 1
      }
    fi
  fi

  apply_all
  echo "適用しました。"
  echo "※ スクリーンセーバの時間は、システム設定を開いている場合は閉じて開き直すと反映されます。"
  echo
fi

verify_all

# 呼び出し元（setup.sh / setdown.sh）が定義していれば、運用メモを表示する。
# 検証に失敗していても出す。「どう使うか」は失敗時こそ知りたいため。
if declare -F epilogue >/dev/null; then
  echo
  epilogue
fi

if [[ "$FAILED" -gt 0 ]]; then
  echo
  echo "$FAILED 件が期待値と違います。--check で確認、引数なしの実行で適用し直せます。" >&2
  echo "画面共有・SSHが変わらない場合は、端末アプリに「フルディスクアクセス」を与えて再実行してください。" >&2
  exit 1
fi

echo
if [[ "$WARNED" -gt 0 ]]; then
  echo "すべて期待どおりです（警告 $WARNED 件は上記を確認）。"
else
  echo "すべて期待どおりです。"
fi
