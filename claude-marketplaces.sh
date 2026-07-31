#!/usr/bin/env bash
# Claude Code に アイデアマンズのプラグインマーケットプレイスを登録する。
#
#   ./claude-marketplaces.sh            登録（未登録のものだけ追加。何度実行しても安全）
#   ./claude-marketplaces.sh --update   登録に加えて、登録済みのものを最新に更新する
#   ./claude-marketplaces.sh --list     現在の登録状況を表示するだけ
#
# 登録先は user スコープ（~/.claude/settings.json）なので、全プロジェクトで使える。
# `claude plugin marketplace add` は登録済みでもエラーにならない（"already on disk" と出て終了）。
#
# ■ 登録後にプラグインを入れる
#   マーケットプレイスの登録は「どこから探すか」の設定でしかなく、プラグイン自体は入らない。
#   使いたいものを個別に入れる:
#
#     claude plugin marketplace list        # 登録済みマーケットプレイス
#     claude plugin install <プラグイン名>   # 例: claude plugin install web-g6
#
# ■ private のほうはGitHubの認証が要る
#   ideamans/claude-private-plugins は非公開リポジトリなので、gitがGitHubに
#   アクセスできる状態でないと失敗する。失敗したら:
#
#     gh auth login                          # または ~/.ssh の鍵をGitHubに登録
#     git ls-remote https://github.com/ideamans/claude-private-plugins  # 疎通確認
#
#   新しいMacではSSH鍵の移行（ssh/import.sh）が先。
set -euo pipefail

# 登録するマーケットプレイス（GitHubの owner/repo 形式）
# マーケットプレイス名（ideamans-plugins 等）はリポジトリ側のmarketplace.jsonが決めるので、
# ここでは指定しない。
MARKETPLACES=(
  "ideamans/claude-public-plugins"    # 公開プラグイン → ideamans-plugins
  "ideamans/claude-private-plugins"   # 非公開プラグイン → ideamans-private（要GitHub認証）
)

MODE="add"
case "${1:-}" in
  --update) MODE="update" ;;
  --list)   MODE="list" ;;
  "")       ;;
  *) echo "不明なオプション: $1（--update / --list）" >&2; exit 1 ;;
esac

if ! command -v claude >/dev/null 2>&1; then
  echo "エラー: claude コマンドが見つかりません（Claude Codeを先に導入すること）" >&2
  exit 1
fi

if [[ "$MODE" == "list" ]]; then
  claude plugin marketplace list
  exit 0
fi

failed=()
for repo in "${MARKETPLACES[@]}"; do
  echo "==> $repo"
  if claude plugin marketplace add "$repo"; then
    :
  else
    echo "    追加に失敗: $repo" >&2
    failed+=("$repo")
  fi
done

if [[ "$MODE" == "update" ]]; then
  echo "==> 登録済みマーケットプレイスを更新"
  claude plugin marketplace update || echo "    更新に失敗（認証切れの可能性）" >&2
fi

echo
claude plugin marketplace list

if [[ ${#failed[@]} -gt 0 ]]; then
  echo >&2
  echo "失敗したマーケットプレイス:" >&2
  for repo in "${failed[@]}"; do
    echo "  - $repo" >&2
  done
  echo "非公開リポジトリならGitHubの認証を確認する（gh auth login / SSH鍵）" >&2
  exit 1
fi
