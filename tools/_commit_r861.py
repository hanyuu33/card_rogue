# -*- coding: utf-8 -*-
"""R861 原子提交：临时 index + commit-tree。

只收本次修复的两个源文件 + 三个工具脚本。
⚠️ `tools/_patch_r847b_field_art.py` 是别的线的未提交改动，不在 MY 里。
"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r861_commit.idx"
MSG = "E:/work/card_rogue/tools/_commit_r861.txt"
MY = [
    "scripts/field_state.gd",
    "scripts/test_engine.gd",
    "tools/_patch_r861_forge_test.py",
    "tools/_patch_r861_forge_test2.py",
    "tools/_commit_r861.txt",
    "tools/_commit_r861.py",
]
OTHERS = ("tools/_patch_r847b_field_art.py",)


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

changed = run("git", "show", "--name-only", "--pretty=format:", "HEAD").split()
for other in OTHERS:
    if other in changed:
        sys.exit("✗ 误把别人的改动带进提交：%s" % other)

print(run("git", "show", "--numstat", "--oneline", "HEAD").strip())
print("COMMIT_OK")
