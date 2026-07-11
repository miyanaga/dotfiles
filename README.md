# dotfiles

macの開発環境設定（zsh・git・WezTerm・macOSシステム設定・Homebrewパッケージ）を1つのリポジトリで管理し、複数のマシンで同じ環境を再現するためのリポジトリ。

## dotfilesの仕組み（初めての人向け）

ホームディレクトリの `.zshrc` や `.gitconfig` のような設定ファイル（ドットファイル）を、直接ホームに置くのではなく **このリポジトリに実体を置き、ホームにはシンボリックリンクを張る** のが基本的な考え方です。

```
~/.zshrc      → ~/dev/dotfiles/zsh/zshrc      （リンク）
~/.gitconfig  → ~/dev/dotfiles/git/gitconfig  （リンク）
```

こうすると:

- 設定の変更がすべてgitの履歴に残る（いつ何を変えたか追える、壊したら戻せる）
- 新しいマシンでは `git clone` + `./install.sh` だけで同じ環境になる
- 複数マシンで設定を変えたら `git push` / `git pull` で同期できる

リンクを張る作業は `install.sh` が自動でやります。既存のファイルは上書きせず `~/.dotfiles.backup/日時/` に退避するので、何度実行しても安全です。

## 構成

```
dotfiles/
├── install.sh          # シンボリックリンクを張るインストーラ
├── Brewfile            # Homebrewパッケージ一覧（brew bundleで一括導入）
├── zsh/
│   ├── zshrc           # → ~/.zshrc      対話シェル設定（履歴・補完・alias・プラグイン）
│   └── zprofile        # → ~/.zprofile   ログイン時のPATH設定（Homebrew等）
├── git/
│   └── gitconfig       # → ~/.gitconfig
├── wezterm/
│   └── wezterm.lua     # → ~/.config/wezterm/wezterm.lua
├── macos/
│   └── defaults.sh     # キーボード・マウス等のシステム設定を適用するスクリプト
└── ssh/
    ├── export.sh       # 旧マシンで実行: ~/.ssh を暗号化アーカイブに
    └── import.sh       # 新マシンで実行: アーカイブから ~/.ssh を復元
```

## 新しいマシンでの導入手順

前提: Homebrewインストール済み（`~/dev/my-mac-setup/SETUP.md` のフェーズ2まで完了）。

```bash
# 1. クローン（リポジトリをGitHub等に置いた場合。まだならAirDrop等でコピーでも可）
mkdir -p ~/dev && cd ~/dev
git clone <このリポジトリのURL> dotfiles

# 2. シンボリックリンクを張る
cd ~/dev/dotfiles
./install.sh

# 3. Homebrewパッケージを一括インストール
brew bundle --file ~/dev/dotfiles/Brewfile

# 4. macOSシステム設定を適用（キーボード・マウス速度。要再ログイン）
./macos/defaults.sh

# 5. シェルを再起動
exec zsh
```

## 日常の使い方

**設定を変えたいとき** は、ホームのファイルを直接編集して構いません（リンクなので実体はリポジトリ内のファイルです）。変えたらコミット:

```bash
cd ~/dev/dotfiles
git add -A && git commit -m "zshrcにaliasを追加"
git push   # リモートを設定している場合
```

**別のマシンに反映するとき**:

```bash
cd ~/dev/dotfiles && git pull
# リンク済みなのでpullだけで反映される（Brewfileを変えたときは brew bundle も）
```

**新しいアプリを入れたとき** は Brewfile にも追記しておくと、次のマシンでも自動で入ります。現在の全インストール済みパッケージから生成し直すこともできます:

```bash
brew bundle dump --force --file ~/dev/dotfiles/Brewfile
```

## マシン固有・秘密の設定（.zshrc.local）

APIキーや特定マシンだけのPATHなど、**リポジトリに入れたくない設定は `~/.zshrc.local` に書きます**。zshrcの最後で自動的に読み込まれ、gitでは追跡されません（.gitignoreの `*.local`）。

```bash
# 例: ~/.zshrc.local
export OPENAI_API_KEY="sk-..."
```

## SSHの移行（重要: gitに入れない）

`~/.ssh` は **このリポジトリでは管理しません**。理由:

- 秘密鍵は絶対にgitに入れてはいけない（リモートにpushした瞬間に漏洩リスク。履歴から消すのも困難）
- `~/.ssh/config` にも接続先ホスト名など秘匿すべき情報が多く含まれる

代わりに、パスフレーズ付き暗号化アーカイブで直接運びます:

```bash
# 旧マシンで
~/dev/dotfiles/ssh/export.sh
# → デスクトップに ssh-backup-YYYYMMDD.tar.gz.enc ができるので AirDrop で新マシンへ

# 新マシンで
~/dev/dotfiles/ssh/import.sh ~/Downloads/ssh-backup-YYYYMMDD.tar.gz.enc
# → ~/.ssh が復元され、パーミッションも自動調整される

# 動作確認後、アーカイブは両マシンから削除
```

export.sh は古い退役鍵の置き場（`.archives/`）と `~/.ssh` 内に残っている古いgitリポジトリ（`.git/`）を除外し、現役の鍵とconfigだけを持っていきます。

### さらにセキュアにするなら（任意・今後の改善候補）

- **1Password SSH Agent**: 秘密鍵を1Passwordに保管し、ファイルとしてディスクに置かない。複数マシン同期も自動
- **マシンごとに鍵を分ける**: 新マシンで `ssh-keygen -t ed25519` して公開鍵を各サーバーに登録。マシン紛失時にその鍵だけ無効化できる

## 注意事項

- **このリポジトリをGitHubに置く場合はprivateリポジトリにする**こと。gitconfigのメールアドレス等が含まれるため
- 旧マシンの `~/.ssh` 内には秘密鍵をコミットした古いgitリポジトリ（`~/.ssh/.git`、2021年から未更新・リモートなし）が残っている。**絶対にリモートを追加してpushしないこと**。不要なら `rm -rf ~/.ssh/.git ~/.ssh/.archives` で撤去してよい（撤去前に必要な鍵が現役ディレクトリにあるか確認）
- `macos/defaults.sh` のキーリピート速度はGUIの最速値を超えた設定のため、システム設定のキーボード画面でスライダーを触ると上書きされる。その場合は再度スクリプトを実行

## 今後追加するとよいもの

- `zed/settings.json`（Zedの設定。`~/.config/zed/settings.json` をリンク対象に追加）
- `mise/config.toml`（グローバルのランタイムバージョン固定。`~/.config/mise/config.toml`）
- Claude Code の `~/.claude/CLAUDE.md` やsettings.json
