#!/usr/bin/env python3
"""1Passwordに保存したクレデンシャルをローカルに書き戻す。

meta.manifest の 添付ラベル→相対パス の対応を使って、元のディレクトリ構造に
復元する。既存ファイルは既定では上書きしない（--force で上書き）。
"""
import argparse
import json
import os
import subprocess
import sys


def op(args):
    return subprocess.run(["op", *args], capture_output=True, text=True)


def list_items(vault, tag):
    r = op(["item", "list", "--vault", vault, "--tags", tag, "--format", "json"])
    if r.returncode != 0:
        print(f"一覧の取得に失敗: {r.stderr.strip()}", file=sys.stderr)
        return []
    return json.loads(r.stdout or "[]")


def get_item(ref, vault):
    r = op(["item", "get", ref, "--vault", vault, "--format", "json"])
    if r.returncode != 0:
        return None
    return json.loads(r.stdout)


def field(item, section_label, field_label):
    for f in item.get("fields", []):
        if (f.get("section", {}).get("label") == section_label
                and f.get("label") == field_label):
            return f.get("value")
    return None


def restore_item(item, vault, dest_root, apply_, force):
    key = item["title"]
    manifest_raw = field(item, "meta", "manifest")
    if not manifest_raw:
        print(f"  スキップ {key}: manifestがありません（このスキル以外で作られたアイテム）",
              file=sys.stderr)
        return False
    manifest = json.loads(manifest_raw)

    root = dest_root or field(item, "meta", "repo_root")
    if not root:
        print(f"  スキップ {key}: 復元先が不明です（--to で指定してください）",
              file=sys.stderr)
        return False

    print(f"{'[dry-run] ' if not apply_ else ''}{key}  ->  {root}")
    ok = True
    for m in manifest:
        out = os.path.join(root, m["path"])
        exists = os.path.exists(out)

        if exists and not force:
            same = ""
            try:
                import hashlib
                h = hashlib.sha256(open(out, "rb").read()).hexdigest()
                same = "（内容一致）" if h == m["sha256"] else "（内容が違う！）"
            except OSError:
                pass
            print(f"    skip  {m['path']} は既に存在{same}")
            continue

        print(f"    {'write' if apply_ else 'would write'}  {m['path']}  ({m['size']}B)")
        if not apply_:
            continue

        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        ref = f"op://{vault}/{item['id']}/files/{m['label']}"
        r = op(["read", "--out-file", out, "--file-mode", m.get("mode", "600"),
                "--force", ref])
        if r.returncode != 0:
            print(f"    失敗  {m['path']}: {r.stderr.strip()}", file=sys.stderr)
            ok = False
    return ok


def main():
    p = argparse.ArgumentParser()
    p.add_argument("key", nargs="?", help="リポジトリのキー（例 ideamans/lightfile6）")
    p.add_argument("--vault", required=True)
    p.add_argument("--tag", required=True)
    p.add_argument("--all", action="store_true", help="保存されている全リポジトリを復元")
    p.add_argument("--to", help="復元先のディレクトリ（既定はバックアップ時のパス）")
    p.add_argument("--apply", action="store_true")
    p.add_argument("--force", action="store_true", help="既存ファイルを上書きする")
    a = p.parse_args()

    if a.all:
        items = [get_item(i["id"], a.vault) for i in list_items(a.vault, a.tag)]
        items = [i for i in items if i]
    elif a.key:
        item = get_item(a.key, a.vault)
        if not item:
            print(f"見つかりません: {a.key}", file=sys.stderr)
            return 1
        items = [item]
    else:
        for i in list_items(a.vault, a.tag):
            print(i["title"])
        return 0

    ok = sum(restore_item(i, a.vault, a.to, a.apply, a.force) for i in items)
    print()
    if a.apply:
        print(f"完了: {ok}/{len(items)} リポジトリを復元しました。")
    else:
        print("dry-run です。実際に書き出すには --apply を付けてください。")
    return 0 if ok == len(items) else 1


if __name__ == "__main__":
    sys.exit(main())
