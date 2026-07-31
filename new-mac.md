# 新しいMacのセットアップ手順

素のmacOS（Apple Silicon）を最短で開発可能な状態にするための手順書。
（このリポジトリ自体の使い方・zsh構成・シークレット移行の詳細は [README.md](README.md) を参照）

シェルスクリプトで全自動化するのではなく、人間の操作（GUIダイアログ、App Store、ブラウザログイン）を挟みつつ、待ち時間を並列化して短時間で完了させる。

## 全体の流れ（所要時間の目安）

| フェーズ | 内容 | 待ち時間 | 人間の操作 |
|---|---|---|---|
| 0 | Xcode CLT + App StoreでXcodeのDL開始 | CLT 5〜10分 / Xcode 30分〜 | ダイアログ承認・App Storeサインイン |
| 1 | Claude Code | 2分 | ブラウザでOAuthログイン |
| 2 | Homebrew | 5分 | パスワード入力・Enter |
| 3 | dotfiles導入 + Brewfile一括インストール（mise/WezTerm/Zed/Colima）+ SSH移行 + 自社ツール | 10分 | AirDropでSSHアーカイブ転送 |
| 4 | Xcodeの初期設定 | 10分 | ライセンス同意 |

ポイント: **Xcodeのダウンロード（数十GB）を最初に仕掛けて、待っている間に残りを全部済ませる。**

---

## 手動ログインToDoチェックリスト

コマンド化できない人間の作業。**1Passwordを最初に**済ませると、以降のすべてのログインでパスワードを参照できる。

- [ ] **Apple IDでサインイン**（システム設定 / App Store）— XcodeのDL開始に必要なので最優先
- [ ] **1Passwordにログイン**（`brew bundle` でインストール後すぐ）
  - 新デバイスでは「メールアドレス + Secret Key + マスターパスワード」が必要
  - Secret Keyは旧マシンの1Password（設定 > アカウント）か Emergency Kit のPDFから
  - ログイン後、設定 > 開発者 > 「SSH Agentを使用」も検討（鍵の1Password管理に移行する場合）
- [ ] **Googleアカウントにログイン**（Chrome）
  - Chromeを急ぐ場合はHomebrew導入直後に単発で: `brew install --cask google-chrome`（brew bundleにも含まれる）
  - [ ] miyanaga@ideamans.com
  - [ ] miyanaga@gmail.com
- [ ] **Claude Code ログイン**（初回 `claude` 実行時にブラウザが開く）
- [ ] **Claude / ChatGPT デスクトップアプリにログイン**
- [ ] **Tailscale ログイン**（メニューバーのアイコンから。SSO利用ならGoogleログインを先に）
  - ⚠️ Time Machine移行だと旧Macの machine key を引き継いでしまい、admin上で旧Macと
    同じデバイス扱い（同じ100.x IP・"Duplicate node key"）になって競合する。
    その場合は `./macos/reset-tailscale.sh` で身元を全消し → 再起動 → ログインし直す。
    （keychainの `tailscale-*` を消すのが本丸。`brew uninstall` や `rm -rf /Library/Tailscale` だけでは直らない）
- [ ] **Colima 初回起動**（`colima start`。GUIもログインも不要だがVMの初回DLに数分。詳細はフェーズ3）
- [ ] **ライセンス・サブスク系アプリの認証**
  - [ ] CleanShot X（ライセンスキー。1Passwordから）
  - [ ] Microsoft Office（Brewfileではコメントアウト。必要なら有効化してMicrosoftアカウントで認証）
  - [ ] djay Pro / Aqua Voice（各アカウントでログイン）
  - [ ] rekordbox（AlphaThetaアカウントでログイン。サブスク契約分の機能は要ログイン）

> App Storeアプリ（Pixelmator Pro / djay Pro / UTM）は `brew bundle` 中に `mas` 経由で入るが、
> **Apple IDサインインが先に済んでいないと失敗する**（失敗しても他のインストールは続行される）。
> その場合はサインイン後に `brew bundle` を再実行すればよい。

---

## フェーズ0: 最初に仕掛けるもの（並列で待つ）

### Xcode Command Line Tools

Homebrewとgitに必要。GUIダイアログが出るので承認する。

```bash
xcode-select --install
```

### Xcode本体（iOS/macOS開発用）

App Storeを開いてXcodeのダウンロードを開始しておく（Apple IDサインインが必要）。
ダウンロード中に以降のフェーズを進める。

> 代替: https://developer.apple.com/download/ から.xipを落とす方が速いことも多い（要Apple Developerアカウント）。

---

## フェーズ1: Claude Code

**前提条件は不要**（CLT・Homebrew・Nodeいずれも不要）。フェーズ0の完了を待たずに実行できる。

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

- インストール先: `~/.local/bin/claude`（単一バイナリ、自動アップデートあり）
- **PATHは自動では通らない**。以下を実行:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
claude --version
```

初回起動でブラウザが開き、Claudeアカウント（Pro/Max/Team）またはConsole APIキーでログイン。

```bash
claude          # 初回はOAuthログイン
claude doctor   # 診断
```

### インストールが「先に進まない」ときの切り分け

```bash
# 1) 実はインストール済みでPATHが通っていないだけ、が最多パターン
ls -la ~/.local/bin/claude

# 2) ダウンロードサーバーに到達できるか（HTTP/2 200 が返ればOK）
curl -sI https://downloads.claude.ai/claude-code-releases/latest

# 3) ディスク空き容量（512MB以上必要）
df -h /
```

- ネットワークが原因なら、Homebrew導入後に `brew install --cask claude-code` でも同じバイナリが入る
- `syntax error near unexpected token '<'` が出た場合は一時的なサーバーエラー。数分後に再試行

---

## フェーズ2: Homebrew

CLT（フェーズ0）完了後に実行。パスワード入力とEnterの操作あり。

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple SiliconではPATH設定が必要（インストーラの指示にも表示される）
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

---

## フェーズ3: dotfiles + 開発ツール一式

### dotfiles（zsh / git / WezTerm設定 + Brewfile）

シェルやgitの設定は `~/dev/dotfiles` リポジトリで一元管理する（詳細はそのREADME.md参照）。
Brewfileにmise・WezTerm・Zed・Colima等が定義済みなので、これで一括導入できる。

```bash
mkdir -p ~/dev && cd ~/dev
git clone <dotfilesリポジトリのURL> dotfiles   # またはAirDrop等でコピー
cd dotfiles
./install.sh                                  # ~/.zshrc 等のシンボリックリンクを張る
brew bundle --file ./Brewfile --verbose       # mise, wezterm, zed, colima等を一括インストール
./macos/defaults.sh                           # キーボード・Finder・Dock・電源等の適用（sudoを聞かれる／一部は要再ログイン）
exec zsh
```

**ワーカー機（普段使いしないMac）をセットアップする場合** は、`Brewfile` の代わりに
`Brewfile.worker` を使う。CLI・開発環境は同じで、趣味・制作系のGUIアプリとApp Storeアプリが入らない:

```bash
brew bundle --file ./Brewfile.worker --verbose
```

このとき、上の「手動ログインToDo」のうち **Apple ID / djay Pro / rekordbox / CleanShot X は不要**
になる（該当アプリを入れないため）。1Password・Google・Claude Code・Tailscaleは引き続き必要。
振り分けの詳細はdotfilesのREADME.md「Brewfileの3分割」を参照。

> `--verbose` を付ける理由: `brew bundle` は最初に未導入のパッケージを**まとめて先読みダウンロード**するが、
> 通常はこの間の出力が抑制され、数GB落としている最中でも無言になる（止まったように見える）。
> `--verbose` を付けるとダウンロードの進捗バーが出る。Blenderなど大きなcaskがあるので時間がかかることもある。
> 別ターミナルから `du -sh ~/Library/Caches/Homebrew/downloads` で進行を確認してもよい。

### SSH設定・鍵の移行

秘密鍵とssh configはgit管理せず、暗号化アーカイブで直接運ぶ（手順はdotfilesのREADME.md参照）。

```bash
# 旧マシン: ~/dev/dotfiles/ssh/export.sh → できたファイルをAirDropで送る
# 新マシン: ~/dev/dotfiles/ssh/import.sh <受け取ったファイル>
```

### 自社ツール（Homebrewでは配っていないもの）

**SSH鍵の移行を済ませてから**実行する（非公開リポジトリのマーケットプレイス登録にGitHub認証が要るため）。

```bash
./install-all-bin-repo.sh    # bin.ideamans.com のCLI一式（gg/gplay/loadshow/crux/asc等 約28本）
                             # 既定の /usr/local/bin に書き込むのでsudoを聞かれることがある
./claude-marketplaces.sh     # Claude Codeのプラグインマーケットプレイス（公開/非公開）を登録
```

どちらも何度実行しても安全。詳細と注意点（PATHの優先順位、GitHub認証の確認方法）は
dotfilesのREADME.md「自社ツールの導入」を参照。

### ランタイムのインストール（mise）

```bash
mise use -g node@lts go@latest
node -v && go version
```

### Dockerランタイム（Colima）

Docker Desktopの代替として**Colima**を使う（Brewfileに `colima` / `docker` / `docker-compose` / `docker-buildx` が入っている）。
完全無料のOSSでGUIなし・CLI専用。商用利用でもライセンス費がかからない。

`brew bundle` の後、VMの起動と `docker compose` / `docker buildx` 用の設定が必要:

```bash
# compose / buildx をプラグインとして認識させる（Homebrew版のcaveats）
mkdir -p ~/.docker
cat > ~/.docker/config.json <<'JSON'
{
  "cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]
}
JSON

colima start --cpu 4 --memory 8 --disk 60   # VM起動（初回はLinuxイメージのDLで数分）
docker run --rm hello-world                 # 動作確認
docker buildx version                       # buildxが認識されていること
```

VMのリソースは初回の `colima start` の指定がそのまま保存される（変更は `colima stop` → `colima start --memory 16` 等）。

#### 重要: `colima stop` を忘れるとVMのデータディスクが壊れる

`colima stop` を経ずにMacを落とすと、イメージを格納しているext4が書き込み途中で切られて壊れ、
containerdが `panic: freepages: failed to get all reachable pages` で起動しなくなる。
2026-07-26にこれで全イメージをロストした。

**dotfilesの `install.sh` がこの対策を自動で仕込むので、追加の作業は不要**:

- LaunchAgent `com.miyanaga.colima-graceful-stop` が、ログアウト/シャットダウン時に
  `colima stop` を自動実行する
- `colima start` / `colima restart` の後に `colima-fsck` が走り、データディスクが
  壊れていれば警告する（正常時は無音）

導入されているかの確認:

```bash
launchctl print "gui/$(id -u)/com.miyanaga.colima-graceful-stop" | grep -E "state|pid"
colima-fsck    # 「健全」と出ればOK
```

詳細と復旧手順（`colima-fsck --repair` / `--reformat`）は [README.md](README.md) の「Colimaの保護」を参照。

なお `brew services start colima` でログイン時の自動起動もできるが、
`keep_alive successful_exit: true` のため**手動で `colima stop` すると再起動されてしまう**ので使っていない。

代替:
- **OrbStack**: 起動が速く省メモリでGUIもあるが、**商用利用は有料ライセンス**（Brewfileにコメントで残してある）
- **Podman**: Docker互換だがdocker-compose周りで互換性の差が出ることがある

---

## フェーズ4: Xcodeの初期設定（ダウンロード完了後）

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch

# iOSシミュレータランタイム（これも大きいので早めに仕掛ける）
xcodebuild -downloadPlatform iOS
```

---

## フェーズ5: リモートアクセスとmacOSシステム設定

### SSHログイン（リモートログイン）を有効化

```bash
sudo systemsetup -setremotelogin on

# 確認
sudo systemsetup -getremotelogin
```

> macOS Ventura以降、この操作にはターミナル（またはWezTerm）への「フルディスクアクセス」権限が求められることがある。
> 拒否された場合は「システム設定 > プライバシーとセキュリティ > フルディスクアクセス」でターミナルを許可してから再実行。
> それでもダメならGUIで: システム設定 > 一般 > 共有 > リモートログイン。

### 画面共有を有効化

```bash
# 現行macOS（Ventura以降）
sudo launchctl enable system/com.apple.screensharing
sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist

# 無効化する場合
# sudo launchctl bootout system /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

接続は他のMacのFinderから `Cmd+K` → `vnc://<ホスト名>.local`。

> 注意: フルコントロールの「リモートマネージメント（ARD）」をCLIだけで完全設定するのはmacOSの制限で不可（MDMが必要）。通常の画面共有（VNC）は上記で有効になる。

### キーボードのリピート速度（現行機より少し速く）

現行機の実測値は `KeyRepeat=1.6` / `InitialKeyRepeat=12`（GUIの最速 2/15 を超える値）。
新しいMacではさらに一段速い値を設定する:

```bash
# リピート間隔（小さいほど速い。単位は約15ms。GUI最速=2、現行機=1.6）
defaults write -g KeyRepeat -float 1.3

# リピート開始までの待ち（小さいほど短い。GUI最速=15、現行機=12）
defaults write -g InitialKeyRepeat -int 10

# 長押しでアクセント文字パネルを出さず、全キーをリピートさせる（vim等で有効）
defaults write -g ApplePressAndHoldEnabled -bool false
```

**再ログイン（またはre再起動）後に反映される。** GUIのスライダー最速値を超えているため、後からシステム設定のキーボード画面でスライダーを触ると上書きされる点に注意。

### マウス・トラックパッドの速度（現行機の値をそのまま移植）

```bash
defaults write -g com.apple.mouse.scaling -float 2.5
defaults write -g com.apple.trackpad.scaling -float 3
```

これも再ログイン後に反映。移行元・移行先で値を確認するには:

```bash
defaults read -g KeyRepeat
defaults read -g InitialKeyRepeat
defaults read -g com.apple.mouse.scaling
defaults read -g com.apple.trackpad.scaling
```

---

## 動作確認チェックリスト

```bash
claude --version
brew --version
mise doctor
node -v
go version
colima status                                         # VMが起動していること
docker run --rm hello-world
xcodebuild -version
sudo systemsetup -getremotelogin                      # On になっていること
sudo launchctl print system/com.apple.screensharing   # 画面共有が有効なこと
defaults read -g KeyRepeat                            # 1.3
defaults read -g InitialKeyRepeat                     # 10
```
