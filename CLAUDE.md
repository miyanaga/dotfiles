# dotfiles リポジトリの指示

macの開発環境設定を管理するリポジトリ。詳細は README.md を読むこと。

## 大原則: macとUbuntu(server)は同等の開発環境にする

**普段使いはMac、開発サーバーはUbuntu。この2つで同じことができる状態を保つ。**

「Macでできることが、SSHで入ったUbuntuではできない」という状態を作らないこと。
CLIツール・シェル設定・エージェント用のスキルは、どちらのOSでも同じように動くのが既定。

そのため、**インストール系・セットアップ系のスクリプトは常に両OS分を揃える**。

| | macOS | Ubuntu |
| --- | --- | --- |
| パッケージ導入 | `macos/Brewfile.common` | `ubuntu/install-packages.sh` |
| リンク・OS固有処理 | `macos/install.sh` | `ubuntu/install.sh` |
| 自社CLI | `install-all-bin-repo.sh`（共通。bin.ideamans.comがdebも配っている） | 同左 |

**片方だけ変えて終わりにしない。** 例:

- `Brewfile.common` にCLIツールを足した → `ubuntu/install-packages.sh` にも足す
- Ubuntu側で入れられない（配布形態の都合など）なら、スクリプト末尾の
  「手動で入れるもの」に理由付きで書く。黙って落とさない
- 共通スクリプトに `stat -f%z` のようなBSD固有の書き方を入れない
  （GNU coreutilsでは `stat -c%s`。両対応の関数を用意して使う）

GUIアプリはこの限りではない。Ubuntu側はサーバー用途なのでChromeだけ入れている。

## ディレクトリの分け方

```
macos固有   → macos/    Homebrew・launchd・pmset・defaults write・colima・worker
ubuntu固有  → ubuntu/   apt・systemd
共通        → そのまま  zsh/ git/ ssh/ starship/ wezterm/ zed/ vscode/ lib/
```

新しくファイルを足すときは、まず「これはどのOSでも意味があるか」を判断する。
迷ったら共通に置き、OS差はスクリプトの中で吸収する（`uname -s` で分岐）。

`install.sh` はルートが共通リンクを張ってから `uname` を見て
`macos/install.sh` か `ubuntu/install.sh` を呼ぶ。OS固有の処理をルートに書かない。

## シェルスクリプトの作法

- 日本語のコメントで「なぜそうしているか」を書く。何をしているかはコードを読めば分かる
- 冒頭のコメントブロックがそのまま `--help` になる（`usage()` を使う）
- 破壊的な操作を伴うものは **dry-runを既定**にし、実行には `--apply` を要求する
- 状態を変えるものは `--check` で現在値の検証だけできるようにする
  （`macos/defaults.sh` `macos/worker/setup.sh` がその形）
- 何度実行しても安全にする（すでに正しい状態ならスキップして `ok` と出す）
- **macOSのbashは3.2**。`set -u` のもとで空配列の `"${arr[@]}"` は
  unbound variable になるので `${arr[@]+"${arr[@]}"}` と書く

## 変更したらドキュメントも直す

README.md にはディレクトリ構成のツリーと各スクリプトの使い方が書いてある。
ファイルを足す・移す・消すときは README.md のツリーも合わせて直すこと。
新しいMacのセットアップ手順は new-mac.md にあるので、導入手順を変えたらこちらも見る。
