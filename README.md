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
├── new-mac.md          # 素のMacをセットアップする際の全体手順書
├── install.sh          # シンボリックリンクを張るインストーラ
├── Brewfile            # Homebrewパッケージ一覧・普段使い機用（brew bundleで一括導入）
├── Brewfile.common     # ↑と↓の両方が読み込む共通部分（CLI・開発・インフラ系）
├── Brewfile.worker     # ワーカー機（リモートデスクトップ運用のMac）用
├── install-all-bin-repo.sh  # bin.ideamans.com の自社CLIを全部入れる／更新する
├── claude-marketplaces.sh   # Claude Codeに自社プラグインマーケットプレイスを登録する
├── zsh/
│   ├── zshrc           # → ~/.zshrc      対話シェル設定（履歴・部分一致補完・プラグイン）
│   ├── zprofile        # → ~/.zprofile   ログイン時のPATH設定（Homebrew等）
│   └── functions.zsh   # → ~/.zsh_functions  ユーティリティ関数（scode/scursor/szed/dev/colima）
├── git/
│   └── gitconfig       # → ~/.gitconfig
├── starship/
│   └── starship.toml   # → ~/.config/starship.toml  プロンプトの調整はここ
├── wezterm/
│   └── wezterm.lua     # → ~/.config/wezterm/wezterm.lua
├── zed/
│   └── settings.json   # → ~/.config/zed/settings.json
├── vscode/
│   └── keybindings.json # → ~/Library/Application Support/Code/User/keybindings.json
├── macos/
│   ├── defaults.sh         # キーボード・Finder・Dock・電源等のシステム設定を適用・検証するスクリプト
│   └── reset-tailscale.sh  # Tailscaleのデバイス身元を完全リセット（Time Machine移行後の重複対策）
├── worker/             # ワーカーモードの切り替え（下記「ワーカーモード」参照）
│   ├── setup.sh        # リモート運用向けの設定を一括ON（SSH・画面共有・非スリープ・即ロック等）
│   ├── setdown.sh      # 上記を解除して普段使いのMacに戻す
│   └── common.sh       # 上記2つの共通実体（直接は実行しない）
├── colima/             # ColimaのVMを壊さないための仕掛け（下記「Colimaの保護」参照）
│   ├── graceful-stop.sh  # → ~/.local/bin/colima-graceful-stop  ログアウト時にcolima stopする常駐スクリプト
│   ├── fsck.sh           # → ~/.local/bin/colima-fsck  データディスクの健全性チェック・修復
│   └── com.miyanaga.colima-graceful-stop.plist  # → ~/Library/LaunchAgents/  上記の常駐定義
└── ssh/
    ├── backup-to-1password.sh  # ~/.ssh 全体を1Passwordに書類として保存（整理前のセーフティネット）
    ├── export.sh       # 旧マシンで実行: 使用中の鍵+config+.aws等を暗号化アーカイブに
    └── import.sh       # 新マシンで実行: アーカイブから復元
```

## Brewfileの3分割（普段使い機 / ワーカー機）

マシンの役割が2種類あるので、Brewfileを共通部分と役割ごとの差分に分けています。

| ファイル | 中身 | 使い方 |
| --- | --- | --- |
| `Brewfile.common` | CLI・開発環境・インフラ系（git/mise/colima/docker/gh/aws/画像処理/1Password/Tailscale/エディタ/LibreOffice等） | 単体では使わない。下2つが読み込む |
| `Brewfile` | common + 普段使いのGUIアプリ（djay Pro / rekordbox / Blender / Pixelmator / OBS / Arduino / Android Studio / CleanShot / App Store経由のアプリ等） | `brew bundle --file Brewfile` |
| `Brewfile.worker` | common + ブラウザ2種（Firefox / Chromium） | `brew bundle --file Brewfile.worker` |

**ワーカー機** は普段使いはせず、常時起動してリモートデスクトップ経由で定期的な作業（バッチ・変換・ビルド・検証）を担うMacを想定しています。方針:

- CLI・開発環境は普段使い機と同等（`Brewfile.common` をそのまま使う）
- 趣味・制作系のGUIアプリは入れない
- LibreOfficeは入れる。`soffice --headless --convert-to pdf` でOffice文書をCLIから変換するため
- App Store（mas）は使わない。Apple IDのサインインを前提にしたくないため
- `windows-app`（リモートデスクトップのクライアント）はコメントアウト。ワーカー機は接続「される」側なので、そのMacから別のWindowsへ繋ぐ場合だけ有効化する

読み込みは `instance_eval(File.read("#{__dir__}/Brewfile.common"))` の1行です（Brewfileの実体はRubyのDSLなので、そのままRubyとして評価される）。パスは Brewfile 自身の位置から解決するので、どのディレクトリから `brew bundle` しても動きます。

分割が正しく展開されているかは、パッケージ一覧を出して確認できます:

```bash
brew bundle list --all --file ~/dev/dotfiles/Brewfile.worker
```

## ワーカーモード（自宅据え置きのMacを安全にリモート運用する）

`Brewfile.worker` が「何を入れるか」なら、`worker/setup.sh` は「どう振る舞わせるか」です。
自宅に据え置いてTailscale経由で使うMacに必要なシステム設定を、まとめてON/OFFします。

```bash
./worker/setup.sh            # ワーカーモードにする
./worker/setup.sh --check    # 現在値が期待どおりか検証するだけ
./worker/setdown.sh          # 解除して普段使いのMacに戻す
./worker/setdown.sh --check
```

どれも冪等です。root権限が要るので `--check` でもsudoのパスワードを聞かれます
（リモートログインや画面共有の状態はrootでないと読めないため）。

### 目指す状態

```
電源ON / 再起動
    ↓
FileVaultのロック画面   ← ここだけ物理 or LAN内SSHでの解除が要る（後述）
    ↓
ログイン画面で待機（自動ログインしない）
    ↓
Tailscale経由で画面共有 → アカウントのパスワードで認証
    ↓
5分放置すればスクリーンセーバ → 即ロック
```

本体はスリープせず画面だけ消えるので、席を外している間もSSH・同期・長時間のビルドが止まらず、
Tailscaleも応答し続けます。Amphetamineのような常駐アプリは不要です（`pmset` で足ります）。

### 変える項目

| 項目 | setup.sh | setdown.sh | なぜ |
|---|---|---|---|
| FileVault | ON（確認のみ） | **ONのまま** | 盗難・持ち出し時の唯一の防御線。自動で有効化はしない（復旧キーを1Passwordに保管してほしいので手作業に残している） |
| 自動ログイン | OFF | **OFFのまま** | 利便性のために無防備な起動に戻す意味がない |
| スクリーンセーバ後のロック | 即時（確認のみ） | そのまま | 変更にパスワード入力が要るため検証だけ行い、ズレていたら直すコマンドを表示する |
| リモートログイン(SSH) | ON | OFF | 画面共有だけでなく、FileVaultのリモート解除にも要る |
| 画面共有 | ON | OFF | |
| FileVault解除後の自動ログイン | 抑止する | 既定に戻す | 既定だとFileVaultのパスワードを入れただけでデスクトップまで入ってしまう。SSHでリモート解除したときに、誰も座っていないMacでセッションが開くのを防ぐ |
| スクリーンセーバ開始 | 5分 | 既定（20分） | |
| 画面オフ | 5分 | 10分 | 戻し先は工場出荷値ではなく `macos/defaults.sh` の値 |
| 本体スリープ / ディスクスリープ | しない | しない | 同上。`macos/defaults.sh` と同じ |
| ネットワークでスリープ解除 | ON | ON | 同上 |
| 停電復帰後の自動起動 | ON | OFF | 対応機種のみ。Apple Siliconはハード側で自動起動するため `pmset -g cap` に出ず、skipされる |
| macOS自動アップデート | OFF | ON | 自動で再起動されるとFileVaultのロック画面で止まり、リモートから触れなくなる。ダウンロードとセキュリティ対応(XProtect等)は止めない |

「常にON」の3項目を `setdown.sh` で戻さないのは意図です。**便利に戻すために穴を開けるのは目的ではない**ため。

電源設定の戻し先を工場出荷値ではなく `macos/defaults.sh` の値にしているのは、
2つのスクリプトが同じ項目を取り合って上書きし合うのを避けるためです。

### FileVaultと再起動（唯一の制約）

FileVaultがONだと、起動直後のデータボリューム解除までは **Tailscaleも通常のSSHセッションも使えません**。
どちらも設定の実体がデータボリューム側にあるためです。対処は3つ:

1. **計画的な再起動**（アップデート等）は `sudo fdesetup authrestart`。
   FileVaultを維持したまま、一度だけ認証済みの状態で再起動します
2. **不意の再起動のあと**は、同じLAN内から `ssh <ユーザー名>@<LAN内のIP>` してパスワード認証すると
   データボリュームが解除されます。macOS標準の機能で、`man fdesetup` の
   **REMOTE UNLOCKING VIA SSH** に書かれています。Remote Loginが有効なことが前提（＝`setup.sh` が満たす）。
   認証してもすぐシェルには入れず、SSHが一度切れてからサービスが上がり直します
3. **外出先からその経路を使う**には、家に常時起動のTailscaleノード（別のMac・Raspberry Pi・
   サブネットルーター）が要ります。**Tailscale経由では解除できません**

停電・電源断・強制再起動には `authrestart` は効きません。それが困る運用なら、
無停電電源装置(UPS)を挟むか、家に踏み台ノードを1つ置くのが現実的です。

### うまくいかないとき

- **SSH・画面共有が切り替わらない** → 端末アプリ（WezTerm等）に「フルディスクアクセス」を与えて再実行。
  `systemsetup -setremotelogin` がこの権限を要求します（無い場合は `launchctl` に自動でフォールバックしますが、
  それも弾かれることがあります）
- **画面共有がONにならない** → リモート管理(Apple Remote Desktop)が有効だと競合します。
  スクリプトが検出したら警告と停止コマンドを表示します
- **画面共有・SSH経由で `setdown.sh` を実行しようとしている** → その接続自体が切れます。
  スクリプトが検出して確認を求めます（`--yes` で省略可）。切れた後は物理的にMacの前に座らないと戻せません
- **ヘッドレス（ディスプレイ未接続）で解像度がおかしい** → ダミーHDMIプラグを挿すか `displayplacer` で調整します。
  これはスクリプトの管轄外です

## 自社ツールの導入（bin.ideamans.com / Claude Codeプラグイン）

Homebrewでは配らないアイデアマンズ独自のツール類。どちらのマシンでも入れる。

### `install-all-bin-repo.sh` — bin.ideamans.com のCLIを一括導入

[bin.ideamans.com](https://bin.ideamans.com)（自社のCLI配布サイト / bin-repo）にある全プログラムをインストール／アップグレードする。`gg`・`gplay`・`loadshow`・`crux`・`et`・`asc`・`safebackup`・`lightfile-*` など約28本。

```bash
./install-all-bin-repo.sh              # 全部を最新版に（何度でも実行してよい）
./install-all-bin-repo.sh --yes        # 確認プロンプトなし
./install-all-bin-repo.sh --help       # 配布中のパッケージ一覧を表示
```

中身は配布元のインストーラを叩いているだけで、以下と等価:

```bash
curl -fsSL 'https://bin.ideamans.com/_/install.sh' | bash
```

- 既定のインストール先は `/usr/local/bin`。書き込み権限がなければsudoのパスワードを聞かれる
- 変えたいときは `--install-dir ~/bin`
- **PATHの優先順位に注意**: `~/.local/bin` のほうが先に見つかるので、そこに同名のコマンドがあるとアップグレードしても古いほうが使われ続ける。疑わしいときは `command -v <コマンド名>` で実際のパスを確認する

### `claude-marketplaces.sh` — Claude Codeのプラグインマーケットプレイス登録

自社の[公開](https://github.com/ideamans/claude-public-plugins)／[非公開](https://github.com/ideamans/claude-private-plugins)プラグインマーケットプレイスを、userスコープ（`~/.claude/settings.json`）に登録する。

```bash
./claude-marketplaces.sh            # 登録（登録済みならスキップ。何度でも実行してよい）
./claude-marketplaces.sh --update   # 登録済みのものを最新に更新
./claude-marketplaces.sh --list     # 現在の登録状況を表示するだけ
```

登録するのは「どこから探すか」だけで、**プラグイン自体は入らない**。使いたいものは個別に入れる:

```bash
claude plugin marketplace list       # 登録済みマーケットプレイス
claude plugin install <プラグイン名>   # 例: claude plugin install web-g6
```

非公開のほう（`ideamans/claude-private-plugins`）はGitHubの認証が要るので、**SSH鍵の移行（`ssh/import.sh`）か `gh auth login` を先に済ませておく**。失敗したときの疎通確認:

```bash
git ls-remote https://github.com/ideamans/claude-private-plugins
```

## zshの構成（フレームワーク不使用・プラグイン2つだけ）

以前使っていたprezto等のフレームワークは使わず、素のzsh + 最小限のプラグインで構成しています。

| 欲しい機能 | 実現方法 |
|---|---|
| Tab補完の部分一致 | zsh標準機能（zshrcの `matcher-list` 設定。単語の途中でもマッチ） |
| 入力中のサジェスト | `zsh-autosuggestions`（履歴＋補完候補をグレー表示、→キーで確定） |
| ↑キーで部分一致の履歴検索 | `zsh-history-substring-search`（例: `docker` と打って↑） |
| プロンプト | `starship`（調整は `starship/starship.toml`、保存すると即反映） |

プラグインのインストールは `brew bundle` に含まれていますが、単体で入れる場合:

```bash
brew install zsh-autosuggestions zsh-history-substring-search starship
```

インストールするだけでOKです（zshrcが存在チェック付きで読み込むので、未インストールでも壊れない）。

## 新しいマシンでの導入手順

素のMacを最初からセットアップする場合は **[new-mac.md](new-mac.md)** に全体の段取り（Xcode並行DL、Claude Code、Homebrew、手動ログインToDo等）がある。以下はdotfiles部分のみの手順（前提: Homebrewインストール済み）。

```bash
# 1. クローン（リポジトリをGitHub等に置いた場合。まだならAirDrop等でコピーでも可）
mkdir -p ~/dev && cd ~/dev
git clone <このリポジトリのURL> dotfiles

# 2. シンボリックリンクを張る（LaunchAgentの登録もここで行われる）
cd ~/dev/dotfiles
./install.sh

# 3. Homebrewパッケージを一括インストール
# --verbose 必須級: 付けないと先読みダウンロード中の出力が抑制され、無言のまま数十分固まったように見える
brew bundle --file ~/dev/dotfiles/Brewfile --verbose
# ワーカー機（普段使いしないMac）の場合は代わりに:
# brew bundle --file ~/dev/dotfiles/Brewfile.worker --verbose

# 4. macOSシステム設定を適用（キーボード・Finder・Dock・電源等。一部は要再ログイン）
#    電源設定(pmset)の変更でsudoのパスワードを聞かれる
./macos/defaults.sh

# 5. 自社ツール（Homebrewでは配っていないもの）
./install-all-bin-repo.sh                     # bin.ideamans.com のCLI一式
./claude-marketplaces.sh                      # Claude Codeのプラグインマーケットプレイス登録
                                              # ※非公開のほうはGitHub認証が要るのでSSH鍵移行の後に

# 6. シェルを再起動
exec zsh

# 7. （ワーカー機の場合のみ）リモート運用向けの設定を入れる
#    SSH・画面共有・非スリープ・即ロック等。詳細は上の「ワーカーモード」
./worker/setup.sh
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

**新しいアプリを入れたとき** は Brewfile にも追記しておくと、次のマシンでも自動で入ります。追記先は用途で選びます:

| 入れるもの | 追記先 |
| --- | --- |
| CLI・開発環境・どのMacにも欲しいもの | `Brewfile.common` |
| 普段使い機だけのGUIアプリ（趣味・制作系、App Store経由） | `Brewfile` |
| ワーカー機だけに必要なもの | `Brewfile.worker` |

現在の全インストール済みパッケージから生成し直すこともできますが、**`--force` で `Brewfile` を直接上書きすると分割（`instance_eval` の行）ごと消えます。** 別ファイルに出して差分を見てから手で振り分けてください:

```bash
brew bundle dump --file /tmp/Brewfile.dump
diff <(brew bundle list --all --file ~/dev/dotfiles/Brewfile | sort) \
     <(brew bundle list --all --file /tmp/Brewfile.dump | sort)
```

## Colimaの保護（`colima stop` の自動化とデータディスクの点検）

### なぜ必要か

Colimaのdockerイメージは、VM内の専用データディスク（ext4, `/dev/vdb1`）に載っている。
**`colima stop` を経ずにMacを落とすとここが壊れる。** 症状はcontainerdが起動しなくなること:

```
panic: freepages: failed to get all reachable pages (page 91: multiple references)
```

2026-07-26にこれで全イメージをロストした。そのときの `e2fsck -fn` の結果は
multiply-claimed blockが**10,161件**で、e2fsckが `aborted` するレベル。
異常終了を重ねるほど悪化する（7/15と7/26の2回で累積した）ため、早期検知も要る。

毎回手で `colima stop` するのを忘れないのは無理なので、機械にやらせる。

### 仕組み（2段構え）

| 層 | 実体 | 役割 |
|---|---|---|
| ① 停止の自動化 | LaunchAgent `com.miyanaga.colima-graceful-stop` | ログアウト/シャットダウン時にlaunchdが送るSIGTERMをtrapして `colima stop` を実行 |
| ② 事後の点検 | `colima-fsck`（zshの `colima` ラッパーが `start`/`restart` 後に自動実行） | データディスクのFS Error countとcontainerd/dockerの稼働を確認。正常なら無音 |

①は `install.sh` が自動で登録する。②は問題を見つけたときだけ警告を出す。

**①でも防げないもの**: 電源断・カーネルパニック・電源ボタン長押し。
どんなフックでも捕まえられないので、②で早期に気づいて被害の累積を止める。

### 使い方

```bash
colima-fsck              # 健全性チェックのみ（読み取りのみ・無害）
colima-fsck --repair     # e2fsck -fy で修復（サービス停止とcolima再起動を伴う）
colima-fsck --reformat   # データディスクを作り直す（最終手段・イメージは全消失）
colima-fsck --help       # 全オプション
```

`--reformat` はラベルとUUIDを維持して `mkfs.ext4` するので、colima側の設定変更は不要。
イメージは消えるが再pull/再ビルドで戻る（volumeを使っている場合は事前に退避すること）。

判断の目安:

- **FSにエラーが出ている** → `--repair`
- **containerdが `panic: freepages`** → メタデータDB(bbolt)の内部破損。ファイルの中身が壊れて
  いるので**e2fsckでは直らない**。`--reformat` が確実（`colima-fsck` がこれを判別して案内する）

### 動作確認とトラブルシュート

```bash
# 常駐しているか
launchctl print "gui/$(id -u)/com.miyanaga.colima-graceful-stop" | grep -E "state|pid"

# 停止処理のログ（SIGTERMを受けた記録とcolima stopの結果が残る）
tail -20 ~/Library/Logs/colima-graceful-stop.log

# ログアウトを模擬してテストする（bootoutはSIGTERMを送るので実際の経路を通る）
launchctl bootout "gui/$(id -u)/com.miyanaga.colima-graceful-stop"   # → colimaが停止する
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.miyanaga.colima-graceful-stop.plist
```

plistを書き換えたときは上記の bootout → bootstrap で読み直す。

**注意**: launchd配下のPATHは `/usr/bin:/bin:/usr/sbin:/sbin` しかない。
`graceful-stop.sh` でHomebrewのbinを明示的に通しているのは、これを忘れると
colimaが `limactl` を見つけられず `dependency check failed for VM: lima not found`
で停止に失敗するため（ログには出るが、気づかないまま毎回壊れることになる）。

## シークレットとマシン固有設定（git管理外の2ファイル）

zshrcの最後で、存在すれば次の2ファイルを読み込みます。**どちらもgitには入れません**。

| ファイル | 用途 | 例 |
|---|---|---|
| `~/.zsh_secrets` | APIキー・トークン類（chmod 600） | `export OPENAI_API_KEY=...` |
| `~/.zshrc.local` | そのマシンだけの設定 | `export CHROME_PATH=...`、マシン固有のPATH |

APIキーを増やすときは `~/.zsh_secrets` に追記するだけです。新マシンへは `ssh/export.sh` の暗号化アーカイブで `~/.ssh` と一緒に移送されます（下記）。

さらに堅くするなら、1Passwordに書類として預ける方法もあります:

```bash
op document create ~/.zsh_secrets --title "zsh_secrets"        # 預ける
op document get "zsh_secrets" --out-file ~/.zsh_secrets && chmod 600 ~/.zsh_secrets  # 取り出す
```

## SSHとシークレットの移行（重要: gitに入れない）

`~/.ssh` と `~/.zsh_secrets` は **このリポジトリでは管理しません**。理由:

- 秘密鍵・APIキーは絶対にgitに入れてはいけない（リモートにpushした瞬間に漏洩リスク。履歴から消すのも困難）
- `~/.ssh/config` にも接続先ホスト名など秘匿すべき情報が多く含まれる

代わりに、次の2段構えで運びます。

### 手順1: 全体を1Passwordにバックアップ（整理・移行の前に必ず）

```bash
~/dev/dotfiles/ssh/backup-to-1password.sh
```

`~/.ssh` 全体（未使用の鍵・退役鍵の `.archives/` も含む）を1Passwordの「書類」として保存します。
これがセーフティネットになるので、以降は未使用の鍵を気兼ねなく捨てられます。
前提: 1Passwordアプリ > 設定 > 開発者 > 「1Password CLIと連携」をON。

復元が必要になったら:

```bash
op document get 'ssh-full-backup-YYYYMMDD' --out-file ~/backup.tar.gz
tar xzf ~/backup.tar.gz -C ~ && rm ~/backup.tar.gz
```

### 手順2: 使用中のものだけ暗号化アーカイブで新マシンへ

```bash
# 旧マシンで（--list で対象を事前確認できる）
~/dev/dotfiles/ssh/export.sh --list
~/dev/dotfiles/ssh/export.sh
# → デスクトップに secrets-backup-YYYYMMDD.tar.gz.enc ができるので AirDrop で新マシンへ

# 新マシンで
~/dev/dotfiles/ssh/import.sh ~/Downloads/secrets-backup-YYYYMMDD.tar.gz.enc
# → 復元され、パーミッションも自動調整される

# 動作確認後、アーカイブは両マシンから削除
```

export.sh が選ぶのは **configが実際に参照している鍵だけ**です（`IdentityFile` 行とデフォルト名 `id_*` を解析）。
それに加えて `~/.zsh_secrets` `~/.aws` `~/.npmrc`、そして **`~/.config` 一式**（gcloud/gh/firebase等のアプリ認証。
yarnキャッシュ・gcloudのPython環境などの再生成可能な大物は除外済み）も同梱します。
configから参照されていない鍵は新マシンに持ち込みません — 必要になったら手順1のバックアップから取り出します。

### さらにセキュアにするなら（任意・今後の改善候補）

- **1Password SSH Agent**: 秘密鍵を1Passwordに保管し、ファイルとしてディスクに置かない。複数マシン同期も自動
- **マシンごとに鍵を分ける**: 新マシンで `ssh-keygen -t ed25519` して公開鍵を各サーバーに登録。マシン紛失時にその鍵だけ無効化できる

## 注意事項

- **このリポジトリをGitHubに置く場合はprivateリポジトリにする**こと。gitconfigのメールアドレス等が含まれるため
- **preztoは廃止**。旧マシンでこの構成に切り替える場合は `./install.sh` 実行後（旧symlinkは自動退避される）、`rm -rf ~/.zprezto` と残った `~/.zpreztorc` 等のリンクを削除してよい。ただし旧マシンのprezto版zshrcにはmise未対応のPATH設定（asdf/pnpm/gcloud等）が残っているため、切り替えは新マシンの安定後でよい
- 旧マシンの `~/.ssh` 内には秘密鍵をコミットした古いgitリポジトリ（`~/.ssh/.git`、2021年から未更新・リモートなし）が残っている。**絶対にリモートを追加してpushしないこと**。不要なら `rm -rf ~/.ssh/.git ~/.ssh/.archives` で撤去してよい（撤去前に必要な鍵が現役ディレクトリにあるか確認）
- `macos/defaults.sh` のキーリピート速度はGUIの最速値を超えた設定のため、システム設定のキーボード画面でスライダーを触ると上書きされる。その場合は再度スクリプトを実行
- **Time Machineで移行するとTailscaleが旧Macと重複する**。移行元の machine key（デバイス身元）まで複製されるため、admin上で旧Macと同じデバイス扱いになり同じ100.x IPを奪い合う（"Duplicate node key"）。`brew uninstall` や `rm -rf /Library/Tailscale` では直らない — 身元は **System keychain の `tailscale-*`**（`tailscale-current-profile`/`tailscale-profiles`/`tailscale-id-profile-*`等）に保存されているため。`./macos/reset-tailscale.sh`（`--list` で対象確認）で全消し → 再起動 → 再ログインすると、新しい身元・新IPで別デバイスとして登録し直せる。詳細はスクリプト冒頭のコメントと [new-mac.md](new-mac.md) を参照
- `install.sh` は登録済みのLaunchAgentには触らない（`launchctl bootout` すると常駐スクリプトにSIGTERMが飛び、**作業中のcolimaのVMが停止してしまう**ため）。plistを書き換えたときだけ手で bootout → bootstrap する
- **FileVaultがONのMacは、再起動するとTailscale経由では復帰できない**。データボリュームが解除されるまでTailscaleもSSHセッションも動かないため。計画的な再起動は `sudo fdesetup authrestart`、不意の再起動後は同じLAN内から `ssh` してパスワード認証（`man fdesetup` の REMOTE UNLOCKING VIA SSH）。外出先からやるには家に常時起動のTailscaleノードが要る。詳細は「ワーカーモード」節
- `worker/setdown.sh` は FileVault・自動ログインOFF・即時ロックを**戻さない**。意図的な設計（利便性のために穴を開けない）。また、画面共有やSSH経由で実行するとその接続自体が切れるため、検出したら確認を求める

## 今後追加するとよいもの

- `mise/config.toml`（グローバルのランタイムバージョン固定。`~/.config/mise/config.toml`）
- Claude Code の `~/CLAUDE.md` や `~/.claude/settings.json`
- `~/.config/karabiner/`（キーリマップを使うなら）

VSCodeの設定はdotfilesでも管理できるが、公式の **Settings Sync**（GitHubアカウントでサインイン）の方が
拡張機能まで同期されるので楽。新マシンではサインインするだけでよい。
