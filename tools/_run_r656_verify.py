# -*- coding: utf-8 -*-
"""R656：跑 _verify.py 前备份 userdata，跑完逐文件还原并校验（旧口径，一次跑完）。

用法：python tools/_run_r656_verify.py

⚠️ 为什么要它：回归套件会写 `app_userdata/卡牌肉鸽`（存档 / 图鉴 / 设置），
   跑一次就把玩家当前进度覆盖掉。这里的流程 = 备份 → 跑 → 按「文件集合 + 内容」
   逐文件还原 → RESTORE_VERIFY。校验不过就是**没还原干净**，必须当失败处理。
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPDATA = os.environ.get("APPDATA", os.path.expanduser("~"))
UD = os.path.join(APPDATA, "Godot", "app_userdata", "卡牌肉鸽")
BK = os.path.join(APPDATA, "Godot", "app_userdata", "_bk_r656_userdata")


def snapshot(d):
    out = {}
    for base, _dirs, files in os.walk(d):
        for f in files:
            p = os.path.join(base, f)
            out[os.path.relpath(p, d)] = open(p, "rb").read()
    return out


def main():
    if not os.path.isdir(UD):
        sys.exit("[r656] userdata 不存在：%s" % UD)
    if os.path.isdir(BK):
        shutil.rmtree(BK)
    shutil.copytree(UD, BK)
    before = snapshot(UD)
    print("[r656] 备份 %d 个文件 → %s" % (len(before), BK))

    rc = subprocess.call([sys.executable, os.path.join(ROOT, "_verify.py")])

    after = snapshot(UD)
    changed = 0
    for rel in list(after.keys()):
        if rel not in before:
            os.remove(os.path.join(UD, rel))
            changed += 1
    for rel, data in before.items():
        p = os.path.join(UD, rel)
        cur = open(p, "rb").read() if os.path.isfile(p) else None
        if cur != data:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "wb") as fh:
                fh.write(data)
            changed += 1

    now = snapshot(UD)
    bad = [r for r, d in before.items() if now.get(r) != d]
    extra = [r for r in now if r not in before]
    print("[r656] RESTORE 改写 %d 个文件" % changed)
    if bad or extra:
        print("[r656] RESTORE_VERIFY FAIL  missing/changed=%s extra=%s" % (bad[:6], extra[:6]))
    else:
        print("[r656] RESTORE_VERIFY OK（%d 个文件逐字节一致）" % len(before))
    print("[r656] _verify 退出码 = %d" % rc)
    sys.exit(0 if rc == 0 and not bad and not extra else 1)


main()
