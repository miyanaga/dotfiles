#!/usr/bin/env bash
# Macを「ワーカーモード」にする。自宅に据え置いて、Tailscale経由でリモート操作する状態。
#
#   ./worker/setup.sh          適用して検証（何度実行しても安全）
#   ./worker/setup.sh --check  適用せず、現在値が期待どおりかの検証だけ
#
# root権限が要るため、--check でもsudoのパスワードを聞かれる
# （Remote Login や 画面共有 の状態はrootでないと読めない）。
#
# ■ 目指す状態
#
#     電源ON / 再起動
#         ↓
#     FileVaultのロック画面（← ここだけ物理 or LAN内SSHでの解除が要る）
#         ↓
#     ログイン画面で待機（自動ログインしない）
#         ↓
#     Tailscale経由で画面共有 → アカウントのパスワードで認証
#         ↓
#     5分放置すればスクリーンセーバ → 即ロック
#
#   本体はスリープしない（画面だけ消える）ので、席を外している間もSSH・同期・
#   長時間のビルドが止まらず、Tailscaleも応答し続ける。
#
# ■ このスクリプトが変えるもの
#
#   常にON（setdown.sh でも戻さない = セキュリティ側に倒す）
#     - FileVault …………………… ONであることの確認のみ（自動で有効化はしない）
#     - 自動ログイン ……………… OFF（autoLoginUser と /etc/kcpassword を削除）
#     - ロックまでの猶予 ………… 即時であることの確認のみ
#
#   ワーカー時ON / setdown.sh でOFF
#     - リモートログイン(SSH) …… ON
#     - 画面共有 …………………… ON
#     - FileVault解除後の自動ログイン抑止 … ON（ログイン画面で待機させる）
#     - スクリーンセーバ ………… 5分
#     - 画面オフ …………………… 5分／本体スリープなし／ネットワークで復帰
#     - 停電復帰後の自動起動 …… ON（対応機種のみ。Apple Siliconは既定で起動する）
#     - macOS自動アップデート …… OFF（勝手に再起動されるとロック画面で詰むため）
#
# ■ FileVaultと再起動（ここが唯一の制約）
#
#   FileVaultがONだと、起動直後のデータボリューム解除までは
#   Tailscaleも通常のSSHセッションも使えない（設定がデータボリューム側にあるため）。
#   対処は3つ。詳しくは README.md の「ワーカーモード」節。
#
#     1. 計画的な再起動は  sudo fdesetup authrestart  を使う（解除済み状態で再起動する）
#     2. 不意の再起動後は、同じLAN内から  ssh <ユーザー名>@<LAN内のIP>  でパスワード認証
#        → データボリュームが解除され、その後Tailscaleも上がってくる（macOS標準の機能。
#          `man fdesetup` の REMOTE UNLOCKING VIA SSH。Remote Loginが有効なことが前提）
#     3. 外出先からその経路を使うには、家に常時起動のTailscaleノード（別のMac・
#        Raspberry Pi・サブネットルーター）が要る。Tailscale経由では解除できない
set -euo pipefail

MODE=on

epilogue() {
  cat <<EOF
============================================================
ワーカーモードの運用メモ

  接続:
    ssh $(whoami)@$(scutil --get LocalHostName 2>/dev/null || hostname)
    画面共有.app または  open vnc://$(scutil --get LocalHostName 2>/dev/null || hostname)

  計画的な再起動（アップデート等）— FileVaultを解除済みのまま再起動する:
    sudo fdesetup authrestart

  停電・強制再起動のあと（FileVaultのロック画面で止まっている）:
    同じLAN内から  ssh $(whoami)@<このMacのLAN内IP>  でパスワード認証すると
    データボリュームが解除される。SSHは一度切れるが、その後Tailscaleも上がる。
    ※ Tailscale経由ではできない（解除前はTailscaleが動いていないため）

  役割を終えたら:
    ./worker/setdown.sh
============================================================
EOF
}

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
