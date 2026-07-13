# brew bundle で一括インストールするパッケージ定義
# 使い方: brew bundle --file ~/dev/dotfiles/Brewfile

# 独自タップ
tap "miyanaga/tap"

# CLIツール
brew "git"
brew "mise"                     # node / go などのランタイム管理
brew "starship"                       # プロンプト（調整は starship/starship.toml）
brew "colima"                   # Docker互換ランタイム（CLI専用・無料OSS。`colima start` でVM起動）
brew "docker"                   # docker CLI本体（デーモンはColimaのVM側）
brew "docker-compose"           # docker compose サブコマンド
brew "gh"                       # GitHub CLI（gh auth login で認証）
brew "awscli"                   # AWS CLI v2（aws configure で認証）
brew "zsh-autosuggestions"            # 入力中に履歴からの候補をグレー表示
brew "zsh-history-substring-search"   # ↑/↓で部分一致の履歴検索
# brew "zsh-syntax-highlighting"      # コマンドラインの色付け（欲しければ）

# GUIアプリ
cask "google-chrome"            # Googleアカウントのログインに早期に必要
cask "wezterm"
cask "zed"
cask "gcloud-cli"               # Google Cloud CLI（旧cask名: google-cloud-sdk）。gcloud init で認証
cask "chatgpt"                  # ChatGPTデスクトップアプリ（要手動ログイン）
cask "claude"                   # Claudeデスクトップアプリ（要手動ログイン）
cask "1password"                # インストール後に手動ログイン（Emergency KitのSecret Keyが必要）
cask "1password-cli"            # op コマンド（SSH Agent連携やスクリプトからの秘密情報参照に使う）
cask "tailscale-app"            # GUI版（旧cask名: tailscale）。インストール後に手動ログイン
cask "firefox"
cask "chromium"                 # 自動更新なし（brew upgradeで更新）
cask "visual-studio-code"
cask "arduino-ide"
cask "blender"
cask "aqua-voice"               # 音声入力（要ログイン）
cask "balenaetcher"
cask "raspberry-pi-imager"
cask "cleanshot"                # CleanShot X（要ライセンスキー入力）
# cask "microsoft-office"       # Word/Excel/PowerPoint一式（要Microsoftアカウントでライセンス認証）。
                                # 巨大（約2GB）でDLに時間がかかるので、必要になったら有効化する

# クリップボード履歴（自前フォーク版）。公証していないビルドなので、
# 起動前に検疫属性を外す必要がある（現在のHomebrewは --no-quarantine を廃止済み）。
# postinstall は brew bundle でのインストール/アップグレード時に自動実行される。
cask "miyanaga/tap/clipy", postinstall: "/usr/bin/xattr -dr com.apple.quarantine /Applications/Clipy.app"

# フォント
cask "font-ibm-plex-mono"       # WezTermのフォント。Zed内蔵のZed Plex Mono（IBM Plex Mono派生）と揃えるため

# App Store アプリ（mas経由。先にApp StoreでApple IDにサインインしておくこと）
brew "mas"
mas "Pixelmator Pro", id: 1289583905
mas "djay Pro", id: 450527929
mas "UTM", id: 1538878817       # App Store版は¥1,500（購入済みなら無料で再DL）。無料版は cask "utm"
# Xcode (id: 497799835) は巨大なので new-mac.md フェーズ0で先行DLする

# 代替・オプション（必要ならコメントを外す）
# cask "claude-code"            # curl版インストーラを使わない場合
# cask "orbstack"               # Colimaより高速だが商用利用は有料ライセンス
