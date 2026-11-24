# -*- coding: utf-8 -*-
"""R854 原子提交：临时 index + commit-tree（不碰真实 index / 工作区里的并行线改动）。"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r854_commit.idx"
MSG = "E:/work/card_rogue/tools/_commit_r854.txt"
B = "art_src/2026-11-22_舰炮炮击_R854/"
MY = [
    "assets/pics/9201.png",
    "assets/pics/_pending/9201.png",
    B + ".gitignore",
    B + "README.md",
    B + "_batch.log",
    B + "_cut.py",
    B + "_make_preview.py",
    B + "_run_codex.py",
    B + "prompts/9201_cannon_blast.txt",
    B + "processed/9201.png",
    B + "processed/9201_view_top.png",
    B + "processed/9201_view_center.png",
    B + "processed/9201_view_safe.png",
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
