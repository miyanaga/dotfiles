#!/usr/bin/env bash
# bin.ideamans.com（アイデアマンズのCLI配布サイト / bin-repo）の全プログラムを
# インストール／アップグレードする。
#
#   ./install-all-bin-repo.sh                       全パッケージを最新版に
#   ./install-all-bin-repo.sh --yes                 確認プロンプトなし（非対話・CI向け）
#   ./install-all-bin-repo.sh --install-dir ~/bin   インストール先を変える（既定: /usr/local/bin）
#   ./install-all-bin-repo.sh --help                配布中のパッケージ一覧とオプションを表示
#
# 実体は配布元のインストーラで、やっていることは下記と同じ:
#
#   curl -fsSL 'https://bin.ideamans.com/_/install.sh' | bash
#
# このラッパーの役割は、(1) ダウンロード失敗と実行失敗を区別して落とす、
# (2) コマンドをdotfiles側に記録して他のマシンでも同じ手順を踏めるようにする、の2点。
# パッケージ一覧は配布元が持っているので、ここには複製しない（古くなるため）。
#
# ■ 入るもの（2026年7月時点。増減するので --help で確認すること）
#   gg / gplay / loadshow / crux / et / asc / safebackup / static-webshot /
#   lightfile-* / my-ga4 / my-fb / misoca など約28本
#
# ■ 注意: インストール先とPATHの優先順位
#   既定の /usr/local/bin より ~/.local/bin のほうがPATHで先（zsh/zprofile参照）。
#   ~/.local/bin に同名のコマンドがあると、そちらが優先されて
#   「アップグレードしたのに古いまま」に見える。疑わしいときは:
#
#     command -v <コマンド名>        # 実際に使われているパス
#     ls ~/.local/bin                # 先回りしているものがないか
#
# ■ sudo
#   /usr/local/bin に書き込み権限がない場合は、配布元のインストーラが
#   その場でsudoのパスワードを聞く。
set -euo pipefail

INSTALLER_URL='https://bin.ideamans.com/_/install.sh'

if ! command -v curl >/dev/null 2>&1; then
  echo "エラー: curl が見つかりません" >&2
  exit 1
fi

TMP_SCRIPT="$(mktemp -t bin-repo-install)"
trap 'rm -f "$TMP_SCRIPT"' EXIT

echo "取得中: $INSTALLER_URL"
if ! curl -fsSL "$INSTALLER_URL" -o "$TMP_SCRIPT"; then
  echo "エラー: インストーラを取得できませんでした（URL・ネットワーク・VPNを確認）" >&2
  exit 1
fi

bash "$TMP_SCRIPT" "$@"
