# -*- coding: utf-8 -*-
"""R820 原子提交：临时 index + commit-tree（并行线暂存的 R819 改动原样不动）。"""
import io
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r820_commit.idx"
MSG = "E:/work/card_rogue/tools/_commit_r820.txt"
MY = [
    "relics.json",
    "i18n/noncard_zh_canonical.json",
    "scripts/battle_scene.gd",
    "scripts/game_engine.gd",
    "scripts/field_state.gd",
    "tools/_patch_r820_claw_wake.py",
    "tools/_patch_r820_sleep_comments.py",
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

blobs = {}
for p in MY:
    h = run("git", "hash-object", "-w", p)
    blobs[p] = h
    run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, p), env=env)
    print("[blob] %s %s" % (h[:10], p))

tree = run("git", "write-tree", env=env)
print("[tree]", tree)

commit = run("git", "commit-tree", tree, "-p", head, "-F", MSG)
print("[commit]", commit)

run("git", "update-ref", "refs/heads/main", commit)

# 逐字节校验：提交里的每个文件必须与工作区一致
for p in MY:
    got = subprocess.run(["git", "cat-file", "-p", "HEAD:" + p], cwd=ROOT,
                         capture_output=True).stdout
    want = open(os.path.join(ROOT, p), "rb").read()
    assert got == want, "内容不一致：%s" % p
    print("[verify] %s OK" % p)

os.remove(TMPIDX)
print("R820 commit done:", commit[:10])
