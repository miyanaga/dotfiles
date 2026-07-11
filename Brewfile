# brew bundle で一括インストールするパッケージ定義
# 使い方: brew bundle --file ~/dev/dotfiles/Brewfile

# CLIツール
brew "git"
brew "mise"                     # node / go などのランタイム管理
brew "starship"                       # プロンプト（調整は starship/starship.toml）
brew "zsh-autosuggestions"            # 入力中に履歴からの候補をグレー表示
brew "zsh-history-substring-search"   # ↑/↓で部分一致の履歴検索
# brew "zsh-syntax-highlighting"      # コマンドラインの色付け（欲しければ）

# GUIアプリ
cask "google-chrome"            # Googleアカウントのログインに早期に必要
cask "wezterm"
cask "zed"
cask "orbstack"                 # Docker互換ランタイム（商用利用は有料ライセンス）
cask "chatgpt"                  # ChatGPTデスクトップアプリ（要手動ログイン）
cask "claude"                   # Claudeデスクトップアプリ（要手動ログイン）
cask "1password"                # インストール後に手動ログイン（Emergency KitのSecret Keyが必要）
cask "1password-cli"            # op コマンド（SSH Agent連携やスクリプトからの秘密情報参照に使う）
cask "tailscale-app"            # GUI版（旧cask名: tailscale）。インストール後に手動ログイン
cask "firefox"
cask "chromium"                 # 自動更新なし（brew upgradeで更新）
cask "visual-studio-code"
cask "android-studio"
cask "arduino-ide"
cask "blender"
cask "aqua-voice"               # 音声入力（要ログイン）
cask "balenaetcher"
cask "raspberry-pi-imager"
cask "cleanshot"                # CleanShot X（要ライセンスキー入力）
cask "microsoft-office"         # Word/Excel/PowerPoint一式（要Microsoftアカウントでライセンス認証）

# App Store アプリ（mas経由。先にApp StoreでApple IDにサインインしておくこと）
brew "mas"
mas "Pixelmator Pro", id: 1289583905
mas "djay Pro", id: 450527929
mas "UTM", id: 1538878817       # App Store版は¥1,500（購入済みなら無料で再DL）。無料版は cask "utm"
# Xcode (id: 497799835) は巨大なので new-mac.md フェーズ0で先行DLする

# 代替・オプション（必要ならコメントを外す）
# cask "claude-code"            # curl版インストーラを使わない場合
# brew "colima"                 # OrbStackの代わりの無料OSSランタイム
# brew "docker"
# brew "docker-compose"
