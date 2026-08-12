#!/usr/bin/env bash
# install.sh と macos/install.sh / ubuntu/install.sh が共有する処理。単体では実行しない。
#
# 呼び出し側では DOTFILES_DIR と BACKUP_DIR を定義しておくこと。

# リポジトリ内のパスをホームのパスにシンボリックリンクする。
# 既存のファイル・リンクは $BACKUP_DIR に退避してから置き換える。
link_one() {
  local src="$DOTFILES_DIR/$1"
  local dst="$HOME/$2"

  if [[ ! -e "$src" ]]; then
    echo "skip    $1 (リポジトリに存在しない)" >&2
    return
  fi

  # すでに正しいリンクなら何もしない
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok      $dst"
    return
  fi

  # 既存のファイル・リンクは退避
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$2")"
    mv "$dst" "$BACKUP_DIR/$2"
    echo "backup  $dst -> $BACKUP_DIR/$2"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link    $dst -> $src"
}

# "リポジトリ内のパス:ホームでのパス" の配列をまとめてリンクする。
link_all() {
  local pair
  for pair in "$@"; do
    link_one "${pair%%:*}" "${pair##*:}"
  done
}
