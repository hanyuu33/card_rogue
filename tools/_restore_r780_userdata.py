# -*- coding: utf-8 -*-
"""R780：回归后把 app_userdata 整目录还原成备份状态，再做 md5 全量校验。

与 R778b 那版不同：这里**整体还原**（备份里有什么就是什么），
测试新造的 / 改写的一律覆盖或删除 —— 避免「又一个新 *_test* 文件」漏在名单外。
logs / art_src 两个目录不动（日志与素材，测试本来也不该改它们）。
"""
import hashlib
import os
import shutil
import sys

BK = r"E:/tmp/r780_ud"
UD = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "卡牌肉鸽")
SKIP = ("logs", "art_src")


def walk_files(root):
    out = []
    for dirpath, dirnames, files in os.walk(root):
        rel = os.path.relpath(dirpath, root).replace("\\", "/")
        if rel != "." and rel.split("/")[0] in SKIP:
            continue
        for f in files:
            relf = os.path.relpath(os.path.join(dirpath, f), root).replace("\\", "/")
            if relf.split("/")[0] in SKIP:
                continue
            out.append(relf)
    return out


bk_files = set(walk_files(BK))
live_files = set(walk_files(UD))

# 1) 备份里有的 → 覆盖回去
for relf in sorted(bk_files):
    src = os.path.join(BK, relf)
    dst = os.path.join(UD, relf)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)

# 2) 备份里没有的 → 删掉（测试产物）
removed = []
for relf in sorted(live_files - bk_files):
    p = os.path.join(UD, relf)
    if os.path.isfile(p):
        os.remove(p)
        removed.append(relf)

if removed:
    print("removed:", removed)


def snap(root):
    out = {}
    for relf in walk_files(root):
        out[relf] = hashlib.md5(open(os.path.join(root, relf), "rb").read()).hexdigest()
    return out


a = snap(BK)
b = snap(UD)
only_b = sorted(set(b) - set(a))
only_a = sorted(set(a) - set(b))
diff = sorted(k for k in set(a) & set(b) if a[k] != b[k])
print("backup=%d live=%d" % (len(a), len(b)))
if only_b or only_a or diff:
    print("only_live:", only_b)
    print("only_backup:", only_a)
    print("content_diff:", diff)
    sys.exit("RESTORE_VERIFY DIFF")
print("RESTORE_VERIFY OK")
