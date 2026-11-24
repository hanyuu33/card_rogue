# -*- coding: utf-8 -*-
"""R780b 原子提交 v2：**临时 index + commit-tree**，彻底绕开 `git commit -- <paths>`。

踩过的坑（第三次才认出来，记牢）：
`git commit -- <path>` 的语义是「把 <path> 的**工作区内容**重新 add 一遍再提交」，
**不是**「按 index 里已暂存的内容提交」。所以我先 `update-index --cacheinfo` 塞进去的
干净版 blob，被这一句无声丢弃，提交里又是并行线的工作区版本（多出 20 行删除，
把 `anthem` / `organ` 两条演出分支删掉了）。

做法：完全不碰真实 index ——
  GIT_INDEX_FILE=临时文件  git read-tree HEAD
  逐个 update-index --cacheinfo <我 hash 出的 blob>
  write-tree → commit-tree -p HEAD → update-ref
真实 index 与工作区都不动，并行线的东西原样保留。
"""
import io
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r780b_commit.idx"
MSG = "_commit_r780b.txt"
MY = ["cards.json", "i18n/zh_canonical.json", "i18n/cards_en.json", "i18n/cards_ja.json",
      "i18n/cards_es.json", "scripts/card_face.gd", "scripts/card_info_boxes.gd",
      "scripts/game_engine.gd", "scripts/test_engine.gd", "scripts/battle_scene.gd"]


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


def git_show(rev_path):
    return subprocess.run(["git", "cat-file", "-p", rev_path], cwd=ROOT,
                          capture_output=True).stdout.decode("utf-8", "replace")


# 0) 撤掉上一次（内容错的）提交
top = run("git", "log", "--oneline", "-1")
if "R780b" in top:
    run("git", "reset", "--soft", "HEAD~1")
    print("rolled back previous R780b commit")

# 1) 拼干净版 battle_scene
print(run(sys.executable, ROOT + "tools/_mk_r780b_battle_clean.py").strip())
clean = io.open(ROOT + "tools/_tmp_r780b_battle_clean.gd", encoding="utf-8", newline="").read()
for keep in ('"anthem":', '"organ":'):
    if keep not in clean:
        sys.exit("干净版丢了 HEAD 里的既有功能 %s —— 基准取错，中止" % keep)

# 2) 每个文件写成 blob（battle_scene 用干净版，其余用工作区）
blobs = {}
blobs["scripts/battle_scene.gd"] = run(
    "git", "hash-object", "-w", "--path", "scripts/battle_scene.gd",
    "tools/_tmp_r780b_battle_clean.gd").strip()
for p in MY:
    if p in blobs:
        continue
    blobs[p] = run("git", "hash-object", "-w", "--path", p, p).strip()
for p, b in blobs.items():
    if len(b) != 40:
        sys.exit("blob 异常 %s: %r" % (p, b))

# 3) 临时 index
if os.path.exists(TMPIDX):
    os.remove(TMPIDX)
env = {"GIT_INDEX_FILE": TMPIDX}
run("git", "read-tree", "HEAD", env=env)
for p in MY:
    run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (blobs[p], p), env=env)
tree = run("git", "write-tree", env=env).strip()

# 4) commit-tree + 移动 main
head = run("git", "rev-parse", "HEAD").strip()
commit = run("git", "commit-tree", tree, "-p", head, "-F", MSG).strip()
run("git", "update-ref", "refs/heads/main", commit, head)
os.remove(TMPIDX)

# 5) 逐字节复核
head_scene = git_show("HEAD:scripts/battle_scene.gd")
if head_scene != clean:
    sys.exit("提交内容与干净版不一致（head %d / clean %d 字符）"
             % (len(head_scene), len(clean)))
for keep in ('"anthem":', '"organ":'):
    if keep not in head_scene:
        sys.exit("提交里丢了 %s" % keep)
for must in ("_draw_damage_cap_aura", '"damage_capped"', '"glyph": "immune"'):
    if must not in head_scene:
        sys.exit("提交里缺我的改动：%s" % must)

print(run("git", "show", "--numstat", "--oneline", "HEAD").strip())
print("COMMIT_OK")
