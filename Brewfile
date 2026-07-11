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

# 代替・オプション（必要ならコメントを外す）
# cask "claude-code"            # curl版インストーラを使わない場合
# brew "colima"                 # OrbStackの代わりの無料OSSランタイム
# brew "docker"
# brew "docker-compose"
