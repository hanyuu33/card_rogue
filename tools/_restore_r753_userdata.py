# -*- coding: utf-8 -*-
"""R753：把 app_userdata 从 _bk_r753_userdata 逐文件还原，并逐文件校验哈希。"""
import hashlib
import os
import shutil

UD = r"C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\卡牌肉鸽"
BK = r"E:\work\card_rogue\_bk_r753_userdata"

SKIP = {".gdignore"}


def h(p):
    with open(p, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


restored = 0
for name in sorted(os.listdir(BK)):
    if name in SKIP:
        continue
    s = os.path.join(BK, name)
    d = os.path.join(UD, name)
    if os.path.isdir(s):
        # 目录（logs / art_src / shader_cache）不影响存档正确性，跳过：
        # 宿主的安全删除闸会拦 rmtree（trash 失败即抛），没必要为它绕路。
        continue
    shutil.copy2(s, d)
    restored += 1

print("restored entries:", restored)

bad = []
for name in sorted(os.listdir(BK)):
    if name in SKIP:
        continue
    s = os.path.join(BK, name)
    d = os.path.join(UD, name)
    if os.path.isdir(s):
        continue
    if not os.path.exists(d) or h(s) != h(d):
        bad.append(name)

print("RESTORE_VERIFY:", "OK" if not bad else ("MISMATCH " + ", ".join(bad)))
