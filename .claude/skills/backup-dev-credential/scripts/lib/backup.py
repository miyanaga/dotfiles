#!/usr/bin/env python3
"""走査結果を1Passwordのアイテムとして保存する。

アイテム構造（リポジトリ1件につき1アイテム）:

    title    ideamans/lightfile6            ... GitHubのパスをキーにする
    tags     dev-credential
    meta.repo_key / meta.repo_root / meta.backed_up_at / meta.host
    meta.manifest   添付ラベル→元の相対パスの対応表(JSON)
    files.<ラベル>  クレデンシャルの中身（添付）

添付ラベルに使える文字は [A-Za-z0-9._-] のみ。op read のシークレット
リファレンス op://vault/item/files/<ラベル> の一部になるためで、
%, ~, +, / を含むと "invalid character in secret reference" になる。
元の相対パスは manifest から復元するので、ラベルは一意でありさえすればよい。

秘密の中身をコマンド引数に置かないこと。opへは必ず [file]=パス の形で渡す
（引数はpsで他プロセスから見える）。
"""
import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

UNSAFE = re.compile(r"[^A-Za-z0-9._-]")


def sanitize(rel: str) -> str:
    return UNSAFE.sub("_", rel)


def make_labels(rels):
    """相対パス→添付ラベル。衝突したら -2, -3 を足して一意にする。"""
    used, out = set(), {}
    for rel in rels:
        base = sanitize(rel)
        label, n = base, 1
        while label in used:
            n += 1
            label = f"{base}-{n}"
        used.add(label)
        out[rel] = label
    return out


def op(args, **kw):
    return subprocess.run(["op", *args], capture_output=True, text=True, **kw)


def find_item(title, vault):
    r = op(["item", "get", title, "--vault", vault, "--format", "json"])
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return None


def esc(label: str) -> str:
    """代入文のフィールド名では . をバックスラッシュで逃がす。"""
    return label.replace("\\", "\\\\").replace(".", "\\.")


def build_assignments(entries, stage, manifest_json, key, repo_root):
    """op item create/edit に渡す代入文を組み立てる。"""
    args = [
        f"meta.repo_key[text]={key}",
        f"meta.repo_root[text]={repo_root}",
        f"meta.host[text]={socket.gethostname()}",
        f"meta.backed_up_at[text]={datetime.now(timezone.utc).isoformat(timespec='seconds')}",
        f"meta.manifest[text]={manifest_json}",
    ]
    for e in entries:
        args.append(f"files.{esc(e['label'])}[file]={os.path.join(stage, e['label'])}")
    return args


def process_repo(repo, vault, tag, apply_):
    key = repo["key"]
    files = repo["files"]
    labels = make_labels([f["rel"] for f in files])

    entries = [
        {"path": f["rel"], "label": labels[f["rel"]], "sha256": f["sha256"],
         "size": f["size"], "mode": oct(os.stat(f["abspath"]).st_mode & 0o777)[2:],
         "abspath": f["abspath"]}
        for f in files
    ]
    repo_root = repo["repo_root"]

    existing = find_item(key, vault) if apply_ else None
    action = "更新" if existing else "新規"

    print(f"{'[dry-run] ' if not apply_ else ''}{action}  {key}  ({len(entries)}件)")
    for e in entries:
        print(f"    {e['path']}  ->  files.{e['label']}  ({e['size']}B)")

    if not apply_:
        return True

    manifest = json.dumps(
        [{k: e[k] for k in ("path", "label", "sha256", "size", "mode")} for e in entries],
        ensure_ascii=False, separators=(",", ":"))

    # 添付名は「ステージしたファイル名」ではなく「フィールドのラベル」が使われるが、
    # ラベル名でステージしておくと1Passwordのアプリ上でも中身が追いやすい。
    stage = tempfile.mkdtemp(prefix="devcred-")
    try:
        for e in entries:
            shutil.copyfile(e["abspath"], os.path.join(stage, e["label"]))

        args = build_assignments(entries, stage, manifest, key, repo_root)

        if existing:
            # 前回あって今回無いファイルの添付を消す（リポジトリ側で消えたもの）
            keep = {e["label"] for e in entries}
            stale = [f["name"] for f in existing.get("files", [])
                     if f["name"] not in keep]
            for name in stale:
                args.append(f"files.{esc(name)}[delete]")
                print(f"    (削除) files.{name}")
            r = op(["item", "edit", existing["id"], "--vault", vault, *args])
        else:
            r = op(["item", "create", "--category", "Secure Note",
                    "--title", key, "--vault", vault, "--tags", tag, *args])

        if r.returncode != 0:
            print(f"  失敗: {key}: {r.stderr.strip().splitlines()[:2]}", file=sys.stderr)
            return False
        return True
    finally:
        shutil.rmtree(stage, ignore_errors=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--scan", required=True)
    p.add_argument("--vault", required=True)
    p.add_argument("--tag", required=True)
    p.add_argument("--only")
    p.add_argument("--apply", action="store_true")
    a = p.parse_args()

    repos = json.load(open(a.scan, encoding="utf-8"))
    if a.only:
        repos = [r for r in repos if r["key"] == a.only]
        if not repos:
            print(f"該当なし: {a.only}", file=sys.stderr)
            return 1

    ok = sum(process_repo(r, a.vault, a.tag, a.apply) for r in repos)
    total_files = sum(len(r["files"]) for r in repos)

    print()
    if a.apply:
        print(f"完了: {ok}/{len(repos)} リポジトリ、{total_files} ファイルを "
              f"vault「{a.vault}」に保存しました。")
    else:
        print(f"dry-run: {len(repos)} リポジトリ、{total_files} ファイルが対象です。")
        print("実際に保存するには --apply を付けて実行してください。")
    return 0 if ok == len(repos) else 1


if __name__ == "__main__":
    sys.exit(main())
