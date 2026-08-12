#!/usr/bin/env bash
# Ubuntuに開発用のCLI一式（+ Google Chrome）を導入する。macos/Brewfile.common のapt版。
#
#   ./ubuntu/install-packages.sh            導入する（何度実行しても安全）
#   ./ubuntu/install-packages.sh --check    導入状況を確認するだけ（sudo不要）
#   ./ubuntu/install-packages.sh --dry-run  実行するコマンドを表示するだけ
#
# GUIアプリはChromeだけ。WezTerm / Zed / VS Code / LibreOffice は入れない
# （Ubuntu側はサーバー・リモート作業用という想定のため）。
#
# アイデアマンズの自社CLIは bin.ideamans.com がdebも配っているので、
# このスクリプトではなく共通の install-all-bin-repo.sh で入れる。
set -euo pipefail

MODE=install
case "${1:-}" in
  --check)   MODE=check ;;
  --dry-run) MODE=dryrun ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "")        ;;
  *)         echo "不明な引数: $1" >&2; exit 1 ;;
esac

[[ "$(uname -s)" == "Linux" ]] || { echo "Linux専用です（現在: $(uname -s)）" >&2; exit 1; }
command -v apt-get >/dev/null || { echo "apt が見つかりません。Ubuntu/Debian系専用です。" >&2; exit 1; }

ARCH="$(dpkg --print-architecture)"          # amd64 / arm64
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
KEYRINGS=/etc/apt/keyrings

run() {
  if [[ "$MODE" == dryrun ]]; then printf '  $ %s\n' "$*"; else "$@"; fi
}

# ---------------------------------------------------------------- 確認モード
if [[ "$MODE" == check ]]; then
  printf '%-26s %s\n' "コマンド" "状態"
  for c in git zsh curl jq unzip make gcc \
           mise starship docker gh glab aws session-manager-plugin \
           duckdb cwebp avifenc magick op gcloud tailscale google-chrome; do
    if command -v "$c" >/dev/null; then
      printf '%-26s \033[32m有\033[0m  %s\n' "$c" "$(command -v "$c")"
    else
      printf '%-26s \033[31m無\033[0m\n' "$c"
    fi
  done
  exit 0
fi

# ------------------------------------------------------- サードパーティのapt鍵
# 公式リポジトリを足すものは、鍵を /etc/apt/keyrings に置いて signed-by で縛る
# （apt-key は非推奨。鍵の効く範囲をそのリポジトリだけに限定する）。
add_repo() {  # add_repo <名前> <鍵URL> <sources.listの1行>
  local name="$1" key_url="$2" line="$3"
  local key="$KEYRINGS/$name.gpg"
  local list="/etc/apt/sources.list.d/$name.list"

  if [[ -f "$key" && -f "$list" ]]; then
    echo "ok      apt repo $name"
    return
  fi
  echo "add     apt repo $name"
  run sudo install -m 0755 -d "$KEYRINGS"
  # 鍵はASCII(.asc)でもバイナリでも来るので dearmor に通す（両方受け付ける）
  run bash -c "curl -fsSL '$key_url' | gpg --dearmor | sudo tee '$key' >/dev/null"
  run sudo chmod a+r "$key"
  run bash -c "echo '$line' | sudo tee '$list' >/dev/null"
}

echo "=== 前提パッケージ ==="
run sudo apt-get update -qq
run sudo apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg lsb-release apt-transport-https

echo
echo "=== 公式aptリポジトリの登録 ==="
add_repo docker https://download.docker.com/linux/ubuntu/gpg \
  "deb [arch=$ARCH signed-by=$KEYRINGS/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable"

add_repo github-cli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  "deb [arch=$ARCH signed-by=$KEYRINGS/github-cli.gpg] https://cli.github.com/packages stable main"

add_repo google-chrome https://dl.google.com/linux/linux_signing_key.pub \
  "deb [arch=amd64 signed-by=$KEYRINGS/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main"

add_repo google-cloud-sdk https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  "deb [signed-by=$KEYRINGS/google-cloud-sdk.gpg] https://packages.cloud.google.com/apt cloud-sdk main"

add_repo 1password https://downloads.1password.com/linux/keys/1password.asc \
  "deb [arch=$ARCH signed-by=$KEYRINGS/1password.gpg] https://downloads.1password.com/linux/debian/$ARCH stable main"

add_repo tailscale "https://pkgs.tailscale.com/stable/ubuntu/$CODENAME.noarmor.gpg" \
  "deb [signed-by=$KEYRINGS/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu $CODENAME main"

add_repo mise https://mise.jdx.dev/gpg-key.pub \
  "deb [arch=$ARCH signed-by=$KEYRINGS/mise.gpg] https://mise.jdx.dev/deb stable main"

echo
echo "=== apt でインストール ==="
run sudo apt-get update -qq

# Ubuntu標準リポジトリのもの
BASE_PKGS=(
  git zsh                      # シェルとバージョン管理
  curl wget jq unzip zip       # 取得・整形・展開
  build-essential              # gcc/make。ネイティブ拡張のビルドに要る
  python3 python3-pip python3-venv
  webp                         # cwebp / dwebp / gif2webp
  libavif-bin                  # avifenc / avifdec（macOSの libavif 相当）
  imagemagick                  # magick コマンド
  zsh-autosuggestions          # 入力中に履歴からの候補をグレー表示
)

# 上で足したサードパーティリポジトリのもの
THIRD_PARTY_PKGS=(
  docker-ce docker-ce-cli containerd.io    # Linuxではcolima不要。Dockerが直接動く
  docker-buildx-plugin docker-compose-plugin
  gh                                       # GitHub CLI
  google-chrome-stable
  google-cloud-cli                         # gcloud / gsutil / bq
  1password-cli                            # op コマンド
  tailscale
  mise                                     # node / go などのランタイム管理
)

run sudo apt-get install -y --no-install-recommends "${BASE_PKGS[@]}"
run sudo apt-get install -y --no-install-recommends "${THIRD_PARTY_PKGS[@]}"

# 現在のユーザーがsudo無しでdockerを使えるようにする（要ログインし直し）
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  echo "add     $USER を docker グループへ（反映にはログインし直しが要る）"
  run sudo usermod -aG docker "$USER"
fi

echo
echo "=== apt に無いもの ==="

# starship: aptのものは古いことが多いので公式インストーラを使う
if command -v starship >/dev/null; then
  echo "ok      starship"
else
  echo "get     starship"
  run bash -c "curl -sS https://starship.rs/install.sh | sh -s -- --yes"
fi

# AWS CLI v2: aptの awscli は v1 なので公式のzipから入れる
if command -v aws >/dev/null && aws --version 2>&1 | grep -q 'aws-cli/2'; then
  echo "ok      aws (v2)"
else
  echo "get     aws-cli v2"
  case "$ARCH" in
    amd64) AWS_ARCH=x86_64 ;;
    arm64) AWS_ARCH=aarch64 ;;
    *)     AWS_ARCH="" ;;
  esac
  if [[ -n "$AWS_ARCH" ]]; then
    run bash -c "tmp=\$(mktemp -d) && \
      curl -fsSL 'https://awscli.amazonaws.com/awscli-exe-linux-$AWS_ARCH.zip' -o \"\$tmp/aws.zip\" && \
      unzip -q \"\$tmp/aws.zip\" -d \"\$tmp\" && sudo \"\$tmp/aws/install\" --update && rm -rf \"\$tmp\""
  else
    echo "warn    $ARCH 版のAWS CLIは配布されていません" >&2
  fi
fi

# session-manager-plugin: AWSが .deb を直接配っている（amd64/arm64）
if command -v session-manager-plugin >/dev/null; then
  echo "ok      session-manager-plugin"
elif [[ "$ARCH" == amd64 || "$ARCH" == arm64 ]]; then
  echo "get     session-manager-plugin"
  smp_dir=$([[ "$ARCH" == amd64 ]] && echo ubuntu_64bit || echo ubuntu_arm64)
  run bash -c "tmp=\$(mktemp -d) && \
    curl -fsSL 'https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$smp_dir/session-manager-plugin.deb' -o \"\$tmp/smp.deb\" && \
    sudo dpkg -i \"\$tmp/smp.deb\" && rm -rf \"\$tmp\""
fi

# zsh-history-substring-search: aptに無いので clone する（zshrcが探す場所に置く）
ZSH_PLUGIN_DIR="$HOME/.zsh/zsh-history-substring-search"
if [[ -d "$ZSH_PLUGIN_DIR" ]]; then
  echo "ok      zsh-history-substring-search"
else
  echo "get     zsh-history-substring-search"
  run git clone --depth 1 https://github.com/zsh-users/zsh-history-substring-search "$ZSH_PLUGIN_DIR"
fi

echo
echo "=== 手動で入れるもの（配布形態がまちまちで自動化していない） ==="
cat <<'EOS'
  glab      GitLab CLI      https://gitlab.com/gitlab-org/cli/-/releases から .deb
  bb        Bitbucket CLI   https://github.com/craftamap/bb/releases から
  gws       Workspace CLI   https://github.com/googleworkspace/cli
  duckdb    分析用DB        https://github.com/duckdb/duckdb/releases から CLI版
  自社CLI   ./install-all-bin-repo.sh（bin.ideamans.com。Ubuntuでもそのまま使える）
EOS

echo
echo "完了。docker グループの反映にはログインし直しが要ります。"
echo "認証が要るもの: gh auth login / aws configure / gcloud init / tailscale up / op signin"
