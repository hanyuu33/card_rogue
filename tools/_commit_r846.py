# -*- coding: utf-8 -*-
"""R846 原子提交：临时 index + commit-tree（同 R845 模板）。

工作区里同时躺着并行卡面线（card_face.gd / ui_theme.gd / ui_assets.gd / 卡面素材）的
未提交改动 → 绝不能用 `git add` / `commit -a`。
"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r846_commit.idx"
MSG = "_commit_r846.txt"
MY = [
    "cards.json",
    "i18n/zh_canonical.json", "i18n/cards_en.json", "i18n/cards_ja.json", "i18n/cards_es.json",
    "i18n/interface_zh_canonical.json", "i18n/interface_en.json", "i18n/interface_ja.json",
    "i18n/interface_es.json", "i18n/validate_spanish.py",
    "scripts/game_engine.gd", "scripts/battle_scene.gd", "scripts/battle_energy_hud.gd",
    "scripts/card_data.gd", "scripts/assemble_rules.gd",
    "scripts/test_engine.gd", "scripts/test_assemble.gd",
    "tools/verify_battle_mana.gd",
    "暗影刺客_稀有史诗明细_R329.md",
]
FOREIGN = ["scripts/card_face.gd", "scripts/ui_assets.gd", "scripts/ui_theme.gd",
           "assets/ui/card_paper_layout.json"]


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


def work_bytes(p):
    with open(os.path.join(ROOT, p), "rb") as f:
        return f.read()


run("git", "fetch", "origin")
head0 = run("git", "rev-parse", "HEAD").strip()
origin0 = run("git", "rev-parse", "origin/main").strip()
if head0 != origin0:
    sys.exit("HEAD(%s) 与 origin/main(%s) 不齐，先处理基线" % (head0[:8], origin0[:8]))

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

listed = run("git", "ls-tree", "-r", "--name-only", tree).splitlines()
for p in MY:
    if p not in listed:
        sys.exit("树里缺我的文件：%s" % p)
for f in FOREIGN:
    want = run("git", "rev-parse", "HEAD:" + f).strip()
    got = run("git", "rev-parse", tree + ":" + f).strip()
    if want != got:
        sys.exit("树里混进并行线改动：%s" % f)

commit = run("git", "commit-tree", tree, "-p", head0, "-F", MSG).strip()
run("git", "update-ref", "refs/heads/main", commit, head0)
os.remove(TMPIDX)

for p in MY:
    got = subprocess.run(["git", "cat-file", "-p", "HEAD:" + p], cwd=ROOT,
                         capture_output=True).stdout
    want = work_bytes(p)
    if got != want or len(want) == 0:
        sys.exit("提交内容与工作区不一致：%s" % p)

print(run("git", "show", "--stat", "--oneline", "HEAD").strip())
print("COMMIT_OK %s" % commit[:8])
