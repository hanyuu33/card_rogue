# -*- coding: utf-8 -*-
"""R663 回归驱动：备份存档 → 跑 _verify.py 全七套 → 逐文件比对还原。

沿用 R657 的口径（文件集合 + sha256 内容快照），不删旧备份（目录带时间戳）。
用法：python tools/_run_r663_verify.py
"""
import hashlib
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UD = r"C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\卡牌肉鸽"
BK = r"E:\tmp\r663_userdata_bk_%s" % time.strftime("%H%M%S")


def snap(root):
    out = {}
    for base, dirs, files in os.walk(root):
        rel_base = os.path.relpath(base, root).replace("\\", "/")
        for d in dirs:
            key = (rel_base + "/" + d) if rel_base != "." else d
            out[("D", key)] = ""
        for f in files:
            p = os.path.join(base, f)
            key = (rel_base + "/" + f) if rel_base != "." else f
            with open(p, "rb") as fh:
                out[("F", key)] = hashlib.sha256(fh.read()).hexdigest()
    return out


def main():
    if not os.path.isdir(UD):
        print("[FAIL] 找不到存档目录：%s" % UD)
        return 2
    os.makedirs(os.path.dirname(BK), exist_ok=True)
    shutil.copytree(UD, BK)
    before = snap(UD)
    print("[BACKUP] %d 项 → %s" % (len(before), BK), flush=True)

    proc = subprocess.run([sys.executable, "_verify.py"], cwd=ROOT)
    print("[VERIFY] exit=%d" % proc.returncode, flush=True)

    current_files = {os.path.relpath(os.path.join(base, f), UD): os.path.join(base, f)
                     for base, _dirs, files in os.walk(UD) for f in files}
    backup_files = {os.path.relpath(os.path.join(base, f), BK): os.path.join(base, f)
                    for base, _dirs, files in os.walk(BK) for f in files}
    extra_root = BK + "_extra"
    extras = sorted(set(current_files) - set(backup_files))
    for rel in extras:
        dst = os.path.join(extra_root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(current_files[rel], dst)
    for rel in extras:
        shutil.move(current_files[rel], os.path.join(extra_root, rel))
    for rel, src in backup_files.items():
        dst = os.path.join(UD, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    after = snap(UD)
    ok = (after == before)
    print("[RESTORE_VERIFY] %s（%d 项，新增搬走 %d 个）" % (
        "OK" if ok else "MISMATCH", len(after), len(extras)), flush=True)
    if not ok:
        only_a = sorted(set(after) - set(before))
        only_b = sorted(set(before) - set(after))
        diff = sorted(k for k in set(after) & set(before) if after[k] != before[k])
        print("  新增=%s 缺失=%s 内容不同=%s" % (only_a[:8], only_b[:8], diff[:8]))
    green = (proc.returncode == 0 and ok)
    print("[REGRESSION] %s" % ("GREEN" if green else "RED"), flush=True)
    return 0 if green else 1


if __name__ == "__main__":
    sys.exit(main())
