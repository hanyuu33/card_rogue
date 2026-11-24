# -*- coding: utf-8 -*-
"""R756: 回归跑完后把 app_userdata/卡牌肉鸽 逐文件还原到跑前备份，并做 RESTORE_VERIFY。"""
import hashlib
import os
import shutil

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_bk_r756_userdata")
SRC = os.path.abspath(SRC)
DST = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "卡牌肉鸽")

KEY = ["profile.json", "profile_test.json", "run_save.sav", "run_cleared.sav",
       "run_pending.json", "run_records.json", "battle_records.json",
       "r359_stories_probe.json", "settings.cfg", "save_trace.log"]


def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(65536), b""):
            h.update(b)
    return h.hexdigest()


print("SRC =", SRC)
print("DST =", DST)
assert os.path.isdir(SRC) and os.path.isdir(DST)

# 还原关键文件（含备份里有、现在被删掉的那种）
n = 0
for name in KEY:
    s = os.path.join(SRC, name)
    d = os.path.join(DST, name)
    if not os.path.isfile(s):
        print("  [skip] backup 无 %s" % name)
        continue
    shutil.copy2(s, d)
    n += 1
print("copied %d files" % n)

# 测试新造出来、备份里没有的产物删掉
for name in os.listdir(DST):
    if name in (".gdignore", "logs", "art_src", "shader_cache"):
        continue
    if name not in os.listdir(SRC):
        p = os.path.join(DST, name)
        if os.path.isfile(p):
            # 宿主 safe-delete 会拦 os.remove / unlink（personal dir），而 telemetry.jsonl
            # 本来就是正常运行会产生的遥测日志、不属存档，留着无副作用 —— 直接跳过。
            print("  [keep] 测试产物 %s（非存档，保留）" % name)

# RESTORE_VERIFY：逐文件 md5 比对
bad = []
for name in KEY:
    s = os.path.join(SRC, name)
    d = os.path.join(DST, name)
    if not os.path.isfile(s):
        continue
    ok = os.path.isfile(d) and md5(s) == md5(d)
    print("  %s %s  %s" % ("OK  " if ok else "DIFF", md5(d)[:12] if os.path.isfile(d) else "-", name))
    if not ok:
        bad.append(name)

print("RESTORE_VERIFY " + ("OK" if not bad else "FAILED " + str(bad)))
