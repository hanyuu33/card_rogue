# -*- coding: utf-8 -*-
"""R778b：回归后还原 app_userdata，并做 md5 全量校验（RESTORE_VERIFY）。"""
import hashlib
import io
import os
import shutil
import sys

BK = r"E:/tmp/r778b_ud"
UD = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "卡牌肉鸽")
SKIP = ("logs", "art_src")          # 日志与素材不进校验

# 1) 拷回被测试改写的文件
for name in ("battle_records.json", "run_cleared_test.sav"):
    src = os.path.join(BK, name)
    if os.path.isfile(src):
        shutil.copy2(src, os.path.join(UD, name))
        print("restored", name)

# 2) 删掉测试新造出来的产物（备份里没有的 *_test* 文件）
for name in ("profile_test.json", "run_pending_test.json"):
    p = os.path.join(UD, name)
    if os.path.isfile(p):
        os.remove(p)
        print("removed", name)


def snap(root):
    out = {}
    for dirpath, dirnames, files in os.walk(root):
        rel = os.path.relpath(dirpath, root).replace("\\", "/")
        if rel.split("/")[0] in SKIP:
            continue
        for f in files:
            full = os.path.join(dirpath, f)
            relf = os.path.relpath(full, root).replace("\\", "/")
            if relf.split("/")[0] in SKIP:
                continue
            h = hashlib.md5(open(full, "rb").read()).hexdigest()
            out[relf] = h
    return out


a = snap(BK)
b = snap(UD)
only_b = sorted(set(b) - set(a))
only_a = sorted(set(a) - set(b))
diff = sorted(k for k in set(a) & set(b) if a[k] != b[k])
print("backup files=%d  live files=%d" % (len(a), len(b)))
if only_b:
    print("多出来的（测试产物）：", only_b)
if only_a:
    print("缺失的：", only_a)
if diff:
    print("内容不同：", diff)
if not (only_b or only_a or diff):
    print("RESTORE_VERIFY OK")
else:
    sys.exit("RESTORE_VERIFY DIFF")
