#!/usr/bin/env bash
# backup-dev-credential の共通処理。単体では実行しない。
# scan.sh / backup.sh / restore.sh から source される。

VAULT="${DEV_CRED_VAULT:-dev-credentials}"
TAG="${DEV_CRED_TAG:-dev-credential}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_DIR="$SKILL_DIR/scripts/lib"
DEFAULT_ROOTS=("$HOME/dev" "$HOME/m4pro/dev")

# --- OS差の吸収 -------------------------------------------------------------
# macOSはBSD由来、UbuntuはGNU/coreutilsで、statもハッシュも引数が違う。
case "$(uname -s)" in
  Darwin)
    file_size() { stat -f%z "$1"; }
    file_mode() { stat -f%Lp "$1"; }
    file_sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
    ;;
  *)
    file_size() { stat -c%s "$1"; }
    file_mode() { stat -c%a "$1"; }
    file_sha256() { sha256sum "$1" | cut -d' ' -f1; }
    ;;
esac

# --help 用。スクリプト冒頭のコメントブロック（shebangの次から）をそのまま出す。
usage() {
  awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$1"
}

# 1Password CLI が使える状態かを確認する。
# op whoami はデスクトップアプリ連携のみの環境だと「not signed in」を返すことがあるため、
# 実際に vault を引けるかどうかで判定する。
require_op() {
  command -v op >/dev/null || {
    echo "opコマンドがありません。" >&2
    case "$(uname -s)" in
      Darwin) echo "  brew install --cask 1password-cli" >&2 ;;
      *)      echo "  ./ubuntu/install-packages.sh で入ります（1password-cli）" >&2 ;;
    esac
    exit 1
  }
  if ! op vault get "$VAULT" >/dev/null 2>&1; then
    echo "1Passwordのvault「$VAULT」を開けません。" >&2
    echo "  - 1Passwordアプリ > 設定 > 開発者 > 「1Password CLIと連携」がONか確認" >&2
    echo "  - vaultが無ければ: op vault create $VAULT" >&2
    exit 1
  fi
}

# リポジトリのバックアップキーを決める。
#   origin があれば   ideamans/lightfile6
#   origin が無ければ local:m4pro/dev/study/my-first-volt
repo_key() {
  local repo="$1" remote key
  remote="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
  if [ -n "$remote" ]; then
    key="$(printf '%s' "$remote" | sed -E 's#^git\+ssh://##; s#^ssh://##; s#^git@[^:/]+[:/]##; s#^https?://([^@]*@)?[^/]+/##; s#\.git$##')"
    printf '%s' "$key"
  else
    printf 'local:%s' "${repo#$HOME/}"
  fi
}
