#!/usr/bin/env bash
# Ubuntu固有のインストール処理。ルートの install.sh から呼ばれる。
# 単体で実行してもよい（Linux部分だけをやり直したいとき）。
#
# 常用はMacで、Ubuntuは開発サーバー等で使う想定。そのためここで扱うのは
# 「共通設定をLinuxでも通す」ための最小限の補正だけにしてある。
# パッケージの一括導入（Brewfile相当のapt版）はまだ用意していない。
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles.backup/$(date +%Y%m%d-%H%M%S)}"
source "$DOTFILES_DIR/lib/install-common.sh"

[[ "$(uname -s)" == "Linux" ]] || {
  echo "Linux専用です（現在: $(uname -s)）" >&2
  exit 1
}

# Linuxでのみ意味のあるリンク。
#   - VS Codeの設定パスが ~/.config/Code/ になる（macOSは ~/Library/... ）
LINUX_LINKS=(
  "vscode/keybindings.json:.config/Code/User/keybindings.json"
)

link_all "${LINUX_LINKS[@]}"

# 共通設定がLinuxで前提にしているものを確認して、足りなければ知らせる。
# 導入はしない（aptを勝手に叩かない）。
for cmd in zsh git starship; do
  command -v "$cmd" >/dev/null || echo "warn    $cmd がありません: sudo apt install $cmd" >&2
done

# zshrc/zprofile は Homebrew が無ければその行を読み飛ばすようになっている。
# mise は apt には無いので、必要なら公式手順で入れる。
command -v mise >/dev/null || \
  echo "note    mise が未導入です: https://mise.jdx.dev/getting-started.html" >&2
