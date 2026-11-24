# -*- coding: utf-8 -*-
"""R832b 原子提交：临时 index + commit-tree（不碰真实 index、不碰工作区）。

为什么不用 `git commit -- <paths>`：它的语义是「把工作区内容重新 add 再提交」，
工作区里现阶段躺着并行线未提交的 cards.json / relics.json 文案改写 —— 一旦按路径提交
就会被卷进来（R780b 的教训）。
"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r832b_commit.idx"
MSG = "_commit_r832b.txt"
MINE = ["scripts/game_engine.gd", "scripts/test_engine.gd"]


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out.strip()


# 0) 前置：本地不得有已暂存内容（有就说明有别的线在做，先停）
staged = run("git", "diff", "--cached", "--name-only")
if staged:
    sys.exit("真实 index 里已有暂存内容，先确认归属再继续：\n" + staged)

if os.path.exists(TMPIDX):
    os.remove(TMPIDX)

head = run("git", "rev-parse", "HEAD")
print("base HEAD =", head)

# 1) 用临时 index 起一份 HEAD 树
tienv = {"GIT_INDEX_FILE": TMPIDX}
run("git", "read-tree", head, env=tienv)

# 2) 逐文件写 blob（工作区内容）+ 塞进临时 index，并记下 blob 用于事后校验
blobs = {}
for f in MINE:
    h = run("git", "hash-object", "-w", "--", f)
    blobs[f] = h
    run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, f), env=tienv)
    print("  blob", h, f)

# 3) 树 + 提交
tree = run("git", "write-tree", env=tienv)
msg = open(os.path.join(ROOT, MSG), encoding="utf-8").read()
commit = subprocess.run(["git", "commit-tree", tree, "-p", head, "-F", os.path.join(ROOT, MSG)],
                        cwd=ROOT, capture_output=True)
if commit.returncode != 0:
    sys.exit("commit-tree 失败：" + commit.stderr.decode("utf-8", "replace"))
csha = commit.stdout.decode().strip()
print("new commit =", csha)
run("git", "update-ref", "HEAD", csha, head)

# 4) 逐字节校验：提交里这 4 个文件必须与工作区完全一致
bad = []
for f, h in blobs.items():
    got = subprocess.run(["git", "cat-file", "blob", "HEAD:" + f], cwd=ROOT,
                         capture_output=True).stdout
    want = open(os.path.join(ROOT, f), "rb").read()
    if got != want:
        bad.append(f)
print("VERIFY", "OK" if not bad else "MISMATCH " + str(bad))

# 5) 提交里**只**该有这 4 个文件
names = run("git", "show", "--name-only", "--pretty=format:", "HEAD").split("\n")
names = [n for n in names if n.strip()]
print("files in commit:", names)
extra = [n for n in names if n not in MINE]
if extra:
    sys.exit("提交里混进了不属于本轮的文件：" + str(extra))

# 6) 工作区仍保留并行线的东西（cards.json / relics.json 未被改动）
print("worktree still dirty:", run("git", "status", "--porcelain").split("\n")[:8])
if bad:
    sys.exit("校验失败，先别 push")
print("R832b 提交完成（未 push）")
