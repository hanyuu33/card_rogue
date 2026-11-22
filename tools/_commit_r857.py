# -*- coding: utf-8 -*-
"""R857 原子提交：临时 index + commit-tree（不碰真实 index / 工作区里并行线的未提交改动）。"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r857_commit.idx"
MSG = "E:/work/card_rogue/tools/_commit_r857.txt"
MY = [
    "scripts/game_engine.gd",
    "scripts/test_engine.gd",
    "cards.json",
    "i18n/zh_canonical.json",
    "i18n/cards_en.json",
    "i18n/cards_ja.json",
    "i18n/cards_es.json",
    "tools/_patch_r857_sleep_armor.py",
    "tools/_patch_r857_test.py",
    "tools/_patch_r857_test2.py",
    "tools/_patch_r857_text.py",
    "tools/_commit_r857.txt",
    "tools/_commit_r857.py",
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

# 逐字节复核：提交里的内容 == 工作区内容
for p in MY:
    head_txt = subprocess.run(["git", "cat-file", "-p", "HEAD:" + p], cwd=ROOT,
                              capture_output=True).stdout
    disk = open(ROOT + p, "rb").read()
    if head_txt != disk:
        sys.exit("提交内容与工作区不一致：%s (head %d / disk %d)" % (p, len(head_txt), len(disk)))
    print("  ✓ %s" % p)

print(run("git", "show", "--numstat", "--oneline", "HEAD").strip())
print("COMMIT_OK")
