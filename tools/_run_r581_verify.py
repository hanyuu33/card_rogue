# -*- coding: utf-8 -*-
"""R581 回归驱动：备份存档 → 跑 _verify.py 六套 → 逐文件比对还原。

判据只看「文件集合 + 内容」（settings.cfg 的 mtime 会被 Godot 重写，不算差异）。
用法：python tools/_run_r581_verify.py
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UD = r"C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\卡牌肉鸽"
BK = r"E:\tmp\r581_userdata_bk"


def snap(root):
    """相对路径 -> 类型/内容摘要；目录也记，保证「文件集合」同源。"""
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

    # 还原：整目录按备份重建，然后按「集合 + 内容」判据核对
    shutil.rmtree(UD, ignore_errors=True)
    shutil.copytree(BK, UD)
    after = snap(UD)
    restore_ok = (after == before)
    print("[RESTORE_VERIFY] %s（%d 项）" % ("OK" if restore_ok else "MISMATCH", len(after)),
          flush=True)
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
          ("GREEN" if green else "RED",
           proc.returncode if proc else "timeout", bad_counts), flush=True)
    return 0 if (green and restore_ok) else 1


if __name__ == "__main__":
    sys.exit(main())
