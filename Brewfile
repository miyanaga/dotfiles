# brew bundle で一括インストールするパッケージ定義（普段使いのMac用）
# 使い方: brew bundle --file ~/dev/dotfiles/Brewfile
#
# 構成:
#   Brewfile.common … どのMacにも入れるCLI・開発・インフラ系（このファイルから読み込む）
#   Brewfile        … 普段使い機。common + 趣味・制作・日常のGUIアプリ
#   Brewfile.worker … ワーカー機（リモートデスクトップ運用）。common + 最小限の追加
#
# 注意: `brew bundle dump --force --file Brewfile` を実行すると、この分割ごと
# 上書きされてinstance_evalの行も消える。dumpする場合は別ファイルに出して差分を見ること。

instance_eval(File.read("#{__dir__}/Brewfile.common"))

# --- ここから普段使い機だけに入れるもの ---

# GUIアプリ
cask "chatgpt"                  # ChatGPTデスクトップアプリ（要手動ログイン）
cask "claude"                   # Claudeデスクトップアプリ（要手動ログイン）
cask "firefox"
cask "chromium"                 # 自動更新なし（brew upgradeで更新）
cask "arduino-ide"
cask "android-studio"           # Android開発IDE（初回起動時にSDK等のセットアップウィザードあり）
cask "blender"
cask "rekordbox"                # Pioneer DJの楽曲管理・DJアプリ（自動更新あり。要AlphaThetaアカウントでログイン）
cask "aqua-voice"               # 音声入力（要ログイン）
cask "balenaetcher"
cask "raspberry-pi-imager"
cask "cleanshot"                # CleanShot X（要ライセンスキー入力）
cask "windows-app"              # Windowsへのリモートデスクトップ（旧microsoft-remote-desktop）。
                                # 接続先PCの登録やAzure Virtual Desktopへのサインインは初回起動後に手動
# cask "microsoft-office"       # Word/Excel/PowerPoint一式（要Microsoftアカウントでライセンス認証）。
                                # 巨大（約2GB）でDLに時間がかかるので、必要になったら有効化する

# App Store アプリ（mas経由。先にApp StoreでApple IDにサインインしておくこと）
brew "mas"
mas "Pixelmator Pro", id: 1289583905
mas "djay Pro", id: 450527929
mas "UTM", id: 1538878817       # App Store版は¥1,500（購入済みなら無料で再DL）。無料版は cask "utm"
# Xcode (id: 497799835) は巨大なので new-mac.md フェーズ0で先行DLする
