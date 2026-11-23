# -*- coding: utf-8 -*-
"""R859 原子提交：临时 index + commit-tree。

⚠️ `scripts/field_state.gd` 的工作区里混着**别人未提交**的 R856 收尾 hunk
（has_sun_forge / unit_actions 的注释与 is_mass_produced 判据）——本提交只收自己那一个
hunk（place 里给甲壳），内容取自 /e/tmp/fs_r859.gd（= HEAD 版 + 我的 hunk）。
"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r859_commit.idx"
MSG = "E:/work/card_rogue/tools/_commit_r859.txt"
MY = [
    "scripts/game_engine.gd",
    "scripts/test_engine.gd",
    "scripts/test_smoke.gd",
    "cards.json",
    "i18n/zh_canonical.json",
    "i18n/cards_en.json",
    "i18n/cards_ja.json",
    "i18n/cards_es.json",
    "i18n/glossary.json",
    "i18n/glossary_es.json",
    "i18n/build_glossary.py",
    "i18n/validate_spanish.py",
    "tools/_patch_r859_shell.py",
    "tools/_patch_r859_test.py",
    "tools/_patch_r859_oldtests.py",
    "tools/_patch_r859_text.py",
    "tools/_patch_r859_i18n.py",
    "tools/_patch_r859_i18n2.py",
    "tools/_commit_r859.txt",
    "tools/_commit_r859.py",
]
# (仓库路径, 取内容的文件) —— 内容源不是工作区文件的那一个
SPECIAL = {"scripts/field_state.gd": "E:/tmp/fs_r859.gd"}


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


paths = MY + list(SPECIAL)
blobs = {}
for p in paths:
    src_file = SPECIAL.get(p, p)
    arg = os.path.relpath(src_file, ROOT) if not os.path.isabs(src_file) else src_file
    b = run("git", "hash-object", "-w", "--path", p, arg).strip()
    if len(b) != 40:
        sys.exit("blob 异常 %s: %r" % (p, b))
    blobs[p] = b

if os.path.exists(TMPIDX):
    os.remove(TMPIDX)
env = {"GIT_INDEX_FILE": TMPIDX}
run("git", "read-tree", "HEAD", env=env)
for p in paths:
    run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (blobs[p], p), env=env)
tree = run("git", "write-tree", env=env).strip()

head = run("git", "rev-parse", "HEAD").strip()
commit = run("git", "commit-tree", tree, "-p", head, "-F", MSG).strip()
run("git", "update-ref", "refs/heads/main", commit, head)
os.remove(TMPIDX)

# 逐字节复核：提交内容 == 这次要提交的那份内容
for p in paths:
    head_txt = subprocess.run(["git", "cat-file", "-p", "HEAD:" + p], cwd=ROOT,
                              capture_output=True).stdout
    src_file = SPECIAL.get(p, p)
    disk = open(src_file if os.path.isabs(src_file) else ROOT + src_file, "rb").read()
    if head_txt != disk:
        sys.exit("提交内容与来源不一致：%s (head %d / src %d)" % (p, len(head_txt), len(disk)))
    print("  ✓ %s" % p)

print(run("git", "show", "--numstat", "--oneline", "HEAD").strip())
print("COMMIT_OK")
