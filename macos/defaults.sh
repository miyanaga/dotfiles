#!/usr/bin/env bash
# macOSのシステム設定をコマンド一発で「適用 → 即時反映 → 検証」する。
#
#   ./macos/defaults.sh          適用して検証（何度実行しても安全）
#   ./macos/defaults.sh --check  適用せず、現在値が期待どおりかの検証だけ
#
# 注意: キーボードのリピート速度はGUIスライダーの最速値を超えているため、
#       システム設定のキーボード画面でスライダーを動かすと上書きされる。
#       上書きされたらこのスクリプトを再実行すれば戻る（--check で検知できる）。
set -euo pipefail

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

# --- 設定の定義 -------------------------------------------------------------
# 「説明 | defaults書き込み引数 | 期待値の読み出し先」を1行にまとめる。
# 検証は write した値がそのまま read で返るかで行う（boolは 0/1 で返る）。

apply_all() {
  # キーボード: リピート速度（旧マシン実測 1.6/12 より一段速く）
  defaults write -g KeyRepeat -float 1.3        # リピート間隔（小さいほど速い、GUI最速=2）
  defaults write -g InitialKeyRepeat -int 10    # リピート開始までの待ち（GUI最速=15）
  defaults write -g ApplePressAndHoldEnabled -bool false  # 長押しでアクセント文字を出さず全キーをリピート

  # ポインタ速度（旧マシンの実測値をそのまま移植）
  defaults write -g com.apple.mouse.scaling -float 2.5
  defaults write -g com.apple.trackpad.scaling -float 3

  # アプリ内のウィンドウ切り替え（次のウィンドウを操作対象にする）を ⌘@ に割り当て。
  # macOSの初期値は ⌘` (バッククォート/キーコード50) だが、JISキーボードにはそのキーが無い
  # （` は Shift+@ で入力する）ため、初期値のままだと事実上使えない。
  # パラメータ = [文字コード, キーコード, 修飾キー]: '@'=64, JISの@キー=33, ⌘=1048576
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 27 \
    '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>64</integer><integer>33</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>'
}

# --- 検証 -------------------------------------------------------------------
FAILED=0

expect() {  # expect <説明> <期待値> <defaults read の引数...>
  local label="$1" want="$2"; shift 2
  local got
  got="$(defaults read "$@" 2>/dev/null || echo '(未設定)')"
  if [[ "$got" == "$want" ]]; then
    printf '  ok    %s: %s\n' "$label" "$got"
  else
    printf '  NG    %s: %s (期待: %s)\n' "$label" "$got" "$want"
    FAILED=$((FAILED + 1))
  fi
}

verify_all() {
  echo "現在値の検証:"
  expect "キーリピート間隔"        "1.3" -g KeyRepeat
  expect "リピート開始までの待ち"  "10"  -g InitialKeyRepeat
  expect "長押しリピート(=1で有効)" "0"   -g ApplePressAndHoldEnabled
  expect "マウス速度"              "2.5" -g com.apple.mouse.scaling
  expect "トラックパッド速度"      "3"   -g com.apple.trackpad.scaling

  # ⌘@ のウィンドウ切り替え（キーコード33 = JISの@キーが入っていること）
  local hotkey
  hotkey="$(/usr/libexec/PlistBuddy -c 'Print :AppleSymbolicHotKeys:27:value:parameters:1' \
    ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || echo '(未設定)')"
  if [[ "$hotkey" == "33" ]]; then
    printf '  ok    ⌘@ でウィンドウ切り替え: keycode %s\n' "$hotkey"
  else
    printf '  NG    ⌘@ でウィンドウ切り替え: %s (期待: keycode 33)\n' "$hotkey"
    FAILED=$((FAILED + 1))
  fi
}

# --- 実行 -------------------------------------------------------------------
if [[ "$CHECK_ONLY" == false ]]; then
  apply_all
  # 再ログインせずに反映させる（ショートカット等はこれで即時有効になる）
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  echo "適用しました。"
fi

verify_all

if [[ "$FAILED" -gt 0 ]]; then
  echo
  echo "$FAILED 件が期待値と違います。--check で確認、引数なしの実行で適用し直せます。" >&2
  exit 1
fi

echo
echo "すべて期待どおりです。"
echo "※ ポインタ速度など一部の設定は、起動済みアプリには再ログインまで効かないことがあります。"
