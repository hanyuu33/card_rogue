# -*- coding: utf-8 -*-
"""R845 原子提交：临时 index + commit-tree。

理由（见 MEMORY 里 R780b 那条）：`git commit -- <paths>` 的语义是「把工作区内容重新 add
一遍」，会把我用 cacheinfo 塞进去的 blob 丢掉；而且工作区里同时躺着并行线（卡面重做）的
未提交改动，绝不能用 `git add` / `commit -a`。

本脚本只认 13 个 R845 文件，真实 index 与工作区一概不动。
"""
import io
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r845_commit.idx"
MSG = "_commit_r845.txt"
MY = [
    "cards.json",
    "i18n/zh_canonical.json", "i18n/cards_en.json", "i18n/cards_ja.json", "i18n/cards_es.json",
    "scripts/game_engine.gd", "scripts/battle_scene.gd",
    "scripts/assemble_rules.gd", "scripts/card_data.gd",
    "scripts/test_engine.gd", "scripts/test_assemble.gd", "scripts/test_smoke.gd",
    "暗影刺客_稀有史诗明细_R329.md",
]
# 并行线的文件：出现即中止
FOREIGN = ["scripts/card_face.gd", "scripts/ui_assets.gd", "scripts/ui_theme.gd",
           "art_src/2026-11-20_card_face_redesign/card_style.png"]


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


def blob_bytes(rev_path):
    return subprocess.run(["git", "cat-file", "-p", rev_path], cwd=ROOT,
                          capture_output=True).stdout


def work_bytes(p):
    with open(os.path.join(ROOT, p), "rb") as f:
        return f.read()


# 0) 前置：HEAD 必须与 origin/main 齐平（不齐就先停下，别在落后基线上提交）
run("git", "fetch", "origin")
head0 = run("git", "rev-parse", "HEAD").strip()
origin0 = run("git", "rev-parse", "origin/main").strip()
if head0 != origin0:
    sys.exit("HEAD(%s) 与 origin/main(%s) 不齐，先处理基线再提交" % (head0[:8], origin0[:8]))

# 1) 逐文件写 blob（全部取工作区内容）
blobs = {}
for p in MY:
    b = run("git", "hash-object", "-w", "--path", p, p).strip()
    if len(b) != 40:
        sys.exit("blob 异常 %s: %r" % (p, b))
    blobs[p] = b

# 2) 临时 index → write-tree
if os.path.exists(TMPIDX):
    os.remove(TMPIDX)
env = {"GIT_INDEX_FILE": TMPIDX}
run("git", "read-tree", "HEAD", env=env)
for p in MY:
    run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (blobs[p], p), env=env)
tree = run("git", "write-tree", env=env).strip()

# 3) 树里必须「我全在（内容=工作区）、并行线一个字节没变」
listed = run("git", "ls-tree", "-r", "--name-only", tree).splitlines()
for p in MY:
    if p not in listed:
        sys.exit("树里缺我的文件：%s" % p)
for f in FOREIGN:
    # ⚠️ 并行线文件本来就已在 HEAD 树里 → 判据是「blob 与 HEAD 相同」，不是「不存在」。
    want = run("git", "rev-parse", "HEAD:" + f).strip()
    got = run("git", "rev-parse", tree + ":" + f).strip()
    if want != got:
        sys.exit("树里混进并行线改动：%s（HEAD %s / 新树 %s）" % (f, want[:8], got[:8]))

# 4) commit-tree + 移动 main
commit = run("git", "commit-tree", tree, "-p", head0, "-F", MSG).strip()
run("git", "update-ref", "refs/heads/main", commit, head0)
os.remove(TMPIDX)

# 5) 逐字节复核：提交内容 == 工作区内容
for p in MY:
    got = blob_bytes("HEAD:" + p)
    want = work_bytes(p)
    if got != want:
        sys.exit("提交内容与工作区不一致：%s（%d / %d 字节）" % (p, len(got), len(want)))
    if len(want) == 0:
        sys.exit("空文件：%s" % p)

print(run("git", "show", "--stat", "--oneline", "HEAD").strip())
print("COMMIT_OK %s" % commit[:8])
