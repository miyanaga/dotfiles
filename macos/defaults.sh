#!/usr/bin/env bash
# macOSのシステム設定をコマンド一発で「適用 → 即時反映 → 検証」する。
#
#   ./macos/defaults.sh          適用して検証（何度実行しても安全）
#   ./macos/defaults.sh --check  適用せず、現在値が期待どおりかの検証だけ
#
# 注意: キーボードのリピート速度はGUIスライダーの最速値を超えているため、
#       システム設定のキーボード画面でスライダーを動かすと上書きされる。
#       上書きされたらこのスクリプトを再実行すれば戻る（--check で検知できる）。
#
# ここに含めないもの（アプリ側が設定してくれる）:
#   - スクリーンショットショートカット⇧⌘3/4/5の無効化 → CleanShot X
#   - Fnキー単押しのアクション（AppleFnUsageType） → Aqua Voice等
set -euo pipefail

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

# --- 設定の定義 -------------------------------------------------------------
# 検証は write した値がそのまま read で返るかで行う（boolは 0/1 で返る）。

# アプリ内のウィンドウ切り替えを ⌘@ / ⌥⌘@ に割り当てる補助関数。
# macOSの初期値は ⌘` (バッククォート/キーコード50) だが、JISキーボードにはそのキーが無い
# （` は Shift+@ で入力する）ため、初期値のままだと事実上使えない。
# パラメータ = [文字コード, キーコード, 修飾キー]: '@'=64, JISの@キー=33
write_at_hotkey() {  # <ホットキーID> <修飾キーのビット値>
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" \
    "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>64</integer><integer>33</integer><integer>$2</integer></array><key>type</key><string>standard</string></dict></dict>"
}

apply_all() {
  # --- キーボード ---
  # リピート速度（旧マシン実測 1.6/12 より一段速く）
  defaults write -g KeyRepeat -float 1.3        # リピート間隔（小さいほど速い、GUI最速=2）
  defaults write -g InitialKeyRepeat -int 10    # リピート開始までの待ち（GUI最速=15）
  defaults write -g ApplePressAndHoldEnabled -bool false  # 長押しでアクセント文字を出さず全キーをリピート
  defaults write -g com.apple.keyboard.fnState -bool true # F1〜F12を輝度等でなく標準のファンクションキーに
  defaults write -g AppleKeyboardUIMode -int 2             # キーボードナビゲーション（Tabでボタン等にもフォーカス移動）

  # --- 日本語入力 ---
  defaults write com.apple.inputmethod.Kotoeri JIMPrefLiveConversionKey -bool false  # ライブ変換をオフ（スペースキーで変換）

  # --- ポインタ速度（旧マシンの実測値をそのまま移植） ---
  defaults write -g com.apple.mouse.scaling -float 2.5
  defaults write -g com.apple.trackpad.scaling -float 3

  # --- スクロール方向 ---
  # 従来向き（ナチュラルなスクロールをOFF）。指を下に動かすと内容が下に動く。
  # macOSはこの設定をトラックパッドとマウスで分けられない（同じキーを共有している）ため、
  # 「トラックパッドはナチュラル、マウスのホイールだけ反転」にはサードパーティ製アプリが要る。
  defaults write -g com.apple.swipescrolldirection -bool false

  # --- ショートカット ---
  # ID 27 = 次のウィンドウを操作対象にする（⌘@）、ID 51 = その対エントリ（⌥⌘@）。
  # GUIで変更すると両方書き換わるため、ここでも揃えて設定する。⌘=1048576, ⌥=524288
  write_at_hotkey 27 1048576
  write_at_hotkey 51 1572864

  # --- 外観 ---
  # ダークモード。osascript経由なら実行中のアプリにも即時反映される。
  # 初回実行時はターミナルに「System Eventsの制御」の許可ダイアログが出るので許可する。
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' >/dev/null

  # --- Finder ---
  defaults write -g AppleShowAllExtensions -bool true            # すべての拡張子を表示
  defaults write com.apple.finder ShowPathbar -bool true         # パスバーを表示
  defaults write com.apple.finder FXPreferredViewStyle -string Nlsv  # デフォルトをリスト表示に
  defaults write com.apple.finder FXDefaultSearchScope -string SCcf  # 検索範囲を「現在のフォルダ」に

  # --- Dock ---
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock tilesize -int 69

  # --- メニューバー時計 ---
  defaults write com.apple.menuextra.clock ShowDate -int 0  # 日付は「スペースに応じて表示」
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

expect_at_hotkey() {  # expect_at_hotkey <説明> <ホットキーID>
  local label="$1" id="$2" keycode
  keycode="$(/usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:$id:value:parameters:1" \
    ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || echo '(未設定)')"
  if [[ "$keycode" == "33" ]]; then
    printf '  ok    %s: keycode %s\n' "$label" "$keycode"
  else
    printf '  NG    %s: %s (期待: keycode 33)\n' "$label" "$keycode"
    FAILED=$((FAILED + 1))
  fi
}

verify_all() {
  echo "現在値の検証:"
  expect "キーリピート間隔"        "1.3" -g KeyRepeat
  expect "リピート開始までの待ち"  "10"  -g InitialKeyRepeat
  expect "長押しリピート(=1で有効)" "0"   -g ApplePressAndHoldEnabled
  expect "F1〜F12を標準キーに(=1)" "1"   -g com.apple.keyboard.fnState
  expect "Tabでフォーカス移動(=2)" "2"   -g AppleKeyboardUIMode
  expect "ライブ変換(=1で有効)"    "0"   com.apple.inputmethod.Kotoeri JIMPrefLiveConversionKey
  expect "マウス速度"              "2.5" -g com.apple.mouse.scaling
  expect "トラックパッド速度"      "3"   -g com.apple.trackpad.scaling
  expect "スクロール: 従来向き(=0)" "0"   -g com.apple.swipescrolldirection
  expect "ダークモード"            "Dark" -g AppleInterfaceStyle
  expect "拡張子を常に表示(=1)"    "1"   -g AppleShowAllExtensions
  expect "Finder: パスバー(=1)"    "1"   com.apple.finder ShowPathbar
  expect "Finder: リスト表示"      "Nlsv" com.apple.finder FXPreferredViewStyle
  expect "Finder: 検索は現在のフォルダ" "SCcf" com.apple.finder FXDefaultSearchScope
  expect "Dock: 自動的に隠す(=1)"  "1"   com.apple.dock autohide
  expect "Dock: アイコンサイズ"    "69"  com.apple.dock tilesize
  expect "時計: 日付表示モード"    "0"   com.apple.menuextra.clock ShowDate
  expect_at_hotkey "⌘@ でウィンドウ切り替え"    27
  expect_at_hotkey "⌥⌘@ でウィンドウ切り替え" 51
}

# --- 実行 -------------------------------------------------------------------
if [[ "$CHECK_ONLY" == false ]]; then
  apply_all
  # 再ログインせずに反映させる（ショートカット等はこれで即時有効になる）
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  # Finder・Dock・メニューバー時計は再起動して設定を読み直させる
  killall Finder Dock ControlCenter 2>/dev/null || true
  # 日本語IMも再起動して設定を読み直させる（自動で再起動される）
  killall JapaneseIM-RomajiTyping 2>/dev/null || true
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
echo "※ ポインタ速度・キーボードナビゲーション等は、起動済みアプリには再ログインまで効かないことがあります。"
