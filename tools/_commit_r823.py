# -*- coding: utf-8 -*-
"""R823 原子提交：临时 index + commit-tree（工作区只有本轮 7 个改动文件）。"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r823_commit.idx"
MSG = "E:/work/card_rogue/tools/_commit_r823.txt"
MY = [
    "scripts/game_engine.gd",
    "scripts/test_engine.gd",
    "relics.json",
    "i18n/noncard_zh_canonical.json",
    "i18n/noncard_en.json",
    "i18n/noncard_ja.json",
    "i18n/noncard_es.json",
    "tools/_patch_r823_claw_discount2.py",
    "tools/_patch_r823_test.py",
    "tools/_commit_r823.py",
    "tools/_commit_r823.txt",
]


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out.strip()


head = run("git", "rev-parse", "HEAD")
env = {"GIT_INDEX_FILE": TMPIDX}
if os.path.exists(TMPIDX):
    os.remove(TMPIDX)
run("git", "read-tree", "HEAD", env=env)

for p in MY:
    h = run("git", "hash-object", "-w", p)
    run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, p), env=env)
    print("[blob] %s %s" % (h[:10], p))

tree = run("git", "write-tree", env=env)
commit = run("git", "commit-tree", tree, "-p", head, "-F", MSG)
print("[tree]", tree)
print("[commit]", commit)
run("git", "update-ref", "refs/heads/main", commit)
os.remove(TMPIDX)

# 逐字节复核
for p in MY:
    got = subprocess.run(["git", "cat-file", "-p", "HEAD:" + p], cwd=ROOT,
                         capture_output=True).stdout
    want = open(os.path.join(ROOT, p), "rb").read()
    assert got == want, "内容不一致：%s" % p
print("[verify] %d 个文件逐字节一致 ✓" % len(MY))

# 提交范围复核
stat = run("git", "show", "--stat", "--oneline", "HEAD")
print(stat)
