# brew bundle で一括インストールするパッケージ定義
# 使い方: brew bundle --file ~/dev/dotfiles/Brewfile

# CLIツール
brew "git"
brew "mise"                     # node / go などのランタイム管理
brew "starship"                 # プロンプト（zshrcが自動検出）
brew "zsh-autosuggestions"      # 履歴からの入力補完サジェスト
brew "zsh-syntax-highlighting"  # コマンドラインのシンタックスハイライト

# GUIアプリ
cask "wezterm"
cask "zed"
cask "orbstack"                 # Docker互換ランタイム（商用利用は有料ライセンス）
cask "1password"                # インストール後に手動ログイン（Emergency KitのSecret Keyが必要）
cask "1password-cli"            # op コマンド（SSH Agent連携やスクリプトからの秘密情報参照に使う）
cask "tailscale-app"            # GUI版（旧cask名: tailscale）。インストール後に手動ログイン

# 代替・オプション（必要ならコメントを外す）
# cask "claude-code"            # curl版インストーラを使わない場合
# brew "colima"                 # OrbStackの代わりの無料OSSランタイム
# brew "docker"
# brew "docker-compose"
