#!/usr/bin/env bash
# macOSのシステム設定をコマンドで適用する。
# 反映には再ログイン（または再起動）が必要。
# 注意: キーボードのリピート速度はGUIスライダーの最速値を超えているため、
#       システム設定のキーボード画面でスライダーを動かすと上書きされる。
set -euo pipefail

# キーボード: リピート速度（旧マシン実測 1.6/12 より一段速く）
defaults write -g KeyRepeat -float 1.3        # リピート間隔（小さいほど速い、GUI最速=2）
defaults write -g InitialKeyRepeat -int 10    # リピート開始までの待ち（GUI最速=15）
defaults write -g ApplePressAndHoldEnabled -bool false  # 長押しでアクセント文字を出さず全キーをリピート

# ポインタ速度（旧マシンの実測値をそのまま移植）
defaults write -g com.apple.mouse.scaling -float 2.5
defaults write -g com.apple.trackpad.scaling -float 3

echo "適用しました。再ログイン後に反映されます。"
