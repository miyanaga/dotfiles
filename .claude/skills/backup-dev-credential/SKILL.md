---
name: backup-dev-credential
description: 開発ツリー(~/dev, ~/m4pro/dev)にある .env / service-account.json / firebase-admin.json などのクレデンシャルを走査し、GitHubのパス(例 ideamans/lightfile6)をキーにして1Passwordのdev-credentials vaultにバックアップ・復元する。新しいMacのセットアップ、リポジトリを再cloneした後の環境復旧、クレデンシャルを失くす前の保全に使う。
---

# backup-dev-credential

`.gitignore` で除外されているためgitに残らないクレデンシャルを、1Passwordに退避・復元する。

## 何が対象か

**gitに追跡されていないファイルだけ**が対象。追跡済みのものはリポジトリから復元できるので拾わない。

対象になるファイル名: `.env` `.env.*` `service-account.json` `firebase-admin.json`
`*-adminsdk-*.json` `credentials.json` `key.json` `*.pem` `*.key` `*.p8` `*.p12`
`*.jks` `*.keystore` `.npmrc` `.netrc` `terraform.tfvars` ほか。

除外は `ignore.txt` で調整する（テスト用の使い捨て鍵、公開CA証明書バンドル、
`*.pub.pem` のような公開部分、`node_modules` などは既定で除外済み）。

## 保存のかたち

リポジトリ1件 = 1Passwordのアイテム1件。

```
タイトル  ideamans/lightfile6          ← GitHubのパスがキー
vault    dev-credentials
タグ      dev-credential
meta.repo_root    /Users/miyanaga/dev/lightfile6
meta.backed_up_at 2026-08-11T02:00:00+00:00
meta.manifest     [{"path":"functions/.env","label":"functions_.env",...}]
添付      functions_.env / functions_service-account.json / ...
```

origin が無いリポジトリは `local:m4pro/dev/study/my-first-volt` というキーになる。

## 使い方

```bash
S=~/.claude/skills/backup-dev-credential/scripts

$S/scan.sh                          # 対象の一覧（TSV）
$S/scan.sh --format json            # JSONで

$S/backup.sh                        # 何が保存されるか表示するだけ
$S/backup.sh --apply                # 実際に保存（新規は作成、既存は更新）
$S/backup.sh --apply --only ideamans/lightfile6

$S/restore.sh                       # 保存済みリポジトリの一覧
$S/restore.sh ideamans/lightfile6   # 復元内容の確認だけ
$S/restore.sh ideamans/lightfile6 --apply
$S/restore.sh ideamans/lightfile6 --apply --to ~/dev/lightfile6   # 別の場所へ
$S/restore.sh --all --apply         # 全部を元の場所へ
```

`backup.sh` も `restore.sh` も**既定はdry-run**。書き込むには `--apply` が要る。
`restore.sh` は既存ファイルを上書きしない（上書きするなら `--force`）。

## 1Passwordの認証について

**`op` を実行するたびにTouch IDを求められる。**このアカウントは Individual なので、
無人実行できるサービスアカウント（`OP_SERVICE_ACCOUNT_TOKEN`）は使えない
（Business/Teams限定）。

だから **全リポジトリの処理を1プロセスで完結させる**設計にしてある。
`backup.sh --apply` を1回叩けば106リポジトリでも承認は原則1回で済む。
リポジトリごとに `--only` で回すと、その回数だけ認証を求められる。

エージェントがこのスキルを使うときも、`--only` のループではなく
`--apply` の一括実行を選ぶこと。

## 注意

- 秘密の中身をコマンド引数に渡さない。`op` へは必ず `[file]=パス` の形で渡す
  （引数は `ps` で他プロセスから見える）。
- 添付のラベルに使える文字は `[A-Za-z0-9._-]` のみ。`op read` のリファレンス
  `op://vault/item/files/<ラベル>` の一部になるためで、`%` `~` `+` `/` を含むと
  `invalid character in secret reference` になる。元の相対パスは `meta.manifest`
  に持っているので、ラベルは一意でありさえすればよい。
- 同じリポジトリを複数箇所にcloneしていると、どちらを正とするか判定が要る。
  ファイル数が多いcloneを採用し、内容が食い違うファイルは警告を出す。
  **警告が出たら、どちらが正か人間が確認すること。**
- 権限はバックアップ時の値を `meta.manifest` に控えて、そのまま復元する
  （手元の `.env` や `key.pem` はたいてい 644 なので、644 で戻る）。
  復元先を締めたいなら復元後に `chmod` すること。
