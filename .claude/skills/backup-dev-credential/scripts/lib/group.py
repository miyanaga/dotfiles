#!/usr/bin/env python3
"""scan.sh の生出力から重複を畳んで整形する。

同じリポジトリを ~/dev と ~/m4pro/dev の両方に clone していると、同じキーの
リポジトリが複数のパスから見つかる。その場合は「ファイル数が最も多いclone」を
正とし、同じ相対パスが複数あって中身が違うときは警告を出す。
"""
import json
import os
import sys
from collections import Counter, defaultdict

COLS = ("key", "root", "rel", "state", "size", "sha256")


def read_rows(path):
    rows = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) == len(COLS):
                rows.append(dict(zip(COLS, parts)))
    return rows


def pick_primary_root(rows):
    """そのキーの代表となるclone。ファイル数が多い方、同数なら更新が新しい方。"""
    counts = Counter(r["root"] for r in rows)
    top = max(counts.values())
    cands = [root for root, n in counts.items() if n == top]
    if len(cands) == 1:
        return cands[0]

    def newest(root):
        times = [os.path.getmtime(os.path.join(root, r["rel"]))
                 for r in rows if r["root"] == root
                 and os.path.exists(os.path.join(root, r["rel"]))]
        return max(times) if times else 0

    return max(cands, key=newest)


def main() -> int:
    path, fmt = sys.argv[1], sys.argv[2]

    by_key = defaultdict(list)
    for r in read_rows(path):
        by_key[r["key"]].append(r)

    result = []
    for key in sorted(by_key):
        rows = by_key[key]
        primary = pick_primary_root(rows)

        by_rel = defaultdict(list)
        for r in rows:
            by_rel[r["rel"]].append(r)

        files = []
        for rel in sorted(by_rel):
            cands = by_rel[rel]
            # 代表cloneにあるものを優先する
            chosen = next((c for c in cands if c["root"] == primary), cands[0])

            if len({c["sha256"] for c in cands}) > 1:
                print(f"警告: {key} の {rel} が clone 間で内容不一致。"
                      f"{chosen['root']} を採用します:", file=sys.stderr)
                for c in cands:
                    print(f"    {os.path.join(c['root'], c['rel'])}  "
                          f"sha={c['sha256'][:12]}", file=sys.stderr)

            files.append({
                "rel": rel,
                "abspath": os.path.join(chosen["root"], rel),
                "state": chosen["state"],
                "size": int(chosen["size"]),
                "sha256": chosen["sha256"],
            })

        result.append({"key": key, "repo_root": primary, "files": files})

    if fmt == "json":
        json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
        print()
    else:
        for repo in result:
            for f in repo["files"]:
                print("\t".join([repo["key"], repo["repo_root"], f["rel"],
                                 f["state"], str(f["size"]), f["sha256"]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
