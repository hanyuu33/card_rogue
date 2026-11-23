# -*- coding: utf-8 -*-
"""R860 原子提交：临时 index + commit-tree（只收自己这次改的 9 个文件 + 2 个工具脚本）。

工作区里 `scripts/field_state.gd`、`tools/_patch_r847b_field_art.py` 是**别人未提交**的
改动，不在 MY 列表里，不会被捎走。
"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r860_commit.idx"
MSG = "E:/work/card_rogue/tools/_commit_r860.txt"
MY = [
    "cards.json",
    "i18n/zh_canonical.json",
    "i18n/cards_en.json",
    "i18n/cards_ja.json",
    "i18n/cards_es.json",
    "scripts/battle_scene.gd",
    "scripts/game_engine.gd",
    "scripts/game_levels.gd",
    "scripts/test_engine.gd",
    "tools/_patch_r860_dmg_text.py",
    "tools/_commit_r860.txt",
    "tools/_commit_r860.py",
]


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


blobs = {}
for p in MY:
    b = run("git", "hash-object", "-w", "--path", p, p).strip()
    if len(b) != 40:
        sys.exit("blob 异常 %s: %r" % (p, b))
    blobs[p] = b

if os.path.exists(TMPIDX):
    os.remove(TMPIDX)
env = {"GIT_INDEX_FILE": TMPIDX}
run("git", "read-tree", "HEAD", env=env)
for p in MY:
    run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (blobs[p], p), env=env)
tree = run("git", "write-tree", env=env).strip()

head = run("git", "rev-parse", "HEAD").strip()
commit = run("git", "commit-tree", tree, "-p", head, "-F", MSG).strip()
run("git", "update-ref", "refs/heads/main", commit, head)
os.remove(TMPIDX)

for p in MY:
    head_txt = subprocess.run(["git", "cat-file", "-p", "HEAD:" + p], cwd=ROOT,
                              capture_output=True).stdout
    disk = open(ROOT + p, "rb").read()
    if head_txt != disk:
        sys.exit("提交内容与来源不一致：%s (head %d / src %d)" % (p, len(head_txt), len(disk)))
    print("  ✓ %s" % p)

# 反查：别人的两个文件不能被带进本次提交
changed = run("git", "show", "--name-only", "--pretty=format:", "HEAD").split()
for other in ("scripts/field_state.gd", "tools/_patch_r847b_field_art.py"):
    if other in changed:
        sys.exit("✗ 误把别人的改动带进提交：%s" % other)

print(run("git", "show", "--numstat", "--oneline", "HEAD").strip())
print("COMMIT_OK")
