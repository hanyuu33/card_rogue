# -*- coding: utf-8 -*-
"""R597 回归驱动：备份存档 → 跑 _verify.py 六套 → 逐文件比对还原。"""
import hashlib
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UD = r"C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\卡牌肉鸽"
BK = r"E:\tmp\r597_userdata_bk"


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
    if os.path.exists(BK):
        shutil.rmtree(BK)
    shutil.copytree(UD, BK)
    before = snap(UD)
    print("[BACKUP] %d 项 → %s" % (len(before), BK), flush=True)
    try:
        proc = subprocess.run([sys.executable, "_verify.py"], cwd=ROOT,
                              capture_output=True, timeout=900)
        out = (proc.stdout + proc.stderr).decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        out = "[FAIL] _verify.py 超时 900s"
        proc = None
    print(out, flush=True)
    extra_root = BK + "_extra"
    current_files = {os.path.relpath(os.path.join(base, f), UD): os.path.join(base, f)
                     for base, _dirs, files in os.walk(UD) for f in files}
    backup_files = {os.path.relpath(os.path.join(base, f), BK): os.path.join(base, f)
                    for base, _dirs, files in os.walk(BK) for f in files}
    extras = sorted(set(current_files) - set(backup_files))
    for rel in extras:
        src = current_files[rel]
        dst = os.path.join(extra_root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        with open(src, "rb") as a, open(dst, "rb") as b:
            assert hashlib.sha256(a.read()).digest() == hashlib.sha256(b.read()).digest()
    for rel in extras:
        shutil.move(current_files[rel], os.path.join(extra_root, rel))
    for rel, src in backup_files.items():
        dst = os.path.join(UD, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    after = snap(UD)
    restore_ok = (after == before)
    print("[RESTORE_VERIFY] %s（%d 项）" % ("OK" if restore_ok else "MISMATCH", len(after)), flush=True)
    if not restore_ok:
        only_a = sorted(set(after) - set(before))
        only_b = sorted(set(before) - set(after))
        diff = sorted(k for k in set(after) & set(before) if after[k] != before[k])
        print("  新增=%s 缺失=%s 内容不同=%s" % (only_a[:8], only_b[:8], diff[:8]))
    bad_counts = [int(x) for x in re.findall(r"/\s*(\d+)✗", out)]
    green = (proc is not None and proc.returncode == 0
             and "== _verify：全部通过 ==" in out
             and all(n == 0 for n in bad_counts)
             and "Parse Error" not in out and "SCRIPT ERROR" not in out
             and "有失败" not in out)
    print("[REGRESSION] %s  exit=%s  bad=%s" %
          ("GREEN" if green else "RED", proc.returncode if proc else "timeout", bad_counts), flush=True)
    return 0 if (green and restore_ok) else 1


if __name__ == "__main__":
    sys.exit(main())
