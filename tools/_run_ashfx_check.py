# -*- coding: utf-8 -*-
"""灰烬龙战吼火焰 / 龙息喷流核查驱动：备份 userdata → 两次真机渲染 → 逐文件还原。

用法：python tools/_run_ashfx_check.py
结果：_shots/_check_ash_fx_ash.png、_shots/_check_ash_fx_breath.png
"""
import hashlib
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "_shots")
UD = r"C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\卡牌肉鸽"
GODOT = os.path.join(os.path.expanduser("~"), ".workbuddy", "binaries",
                     "godot", "Godot_v4.3-stable_win64_console.exe")
BK = r"E:\tmp\ashfx_bk_" + time.strftime("%H%M%S")


def snap(root):
    out = {}
    for base, dirs, files in os.walk(root):
        rel = os.path.relpath(base, root).replace("\\", "/")
        for d in dirs:
            out[("D", (rel + "/" + d) if rel != "." else d)] = ""
        for f in files:
            p = os.path.join(base, f)
            key = (rel + "/" + f) if rel != "." else f
            with open(p, "rb") as fh:
                out[("F", key)] = hashlib.sha256(fh.read()).hexdigest()
    return out


def restore(before, bk):
    cur = {os.path.relpath(os.path.join(b, f), UD): os.path.join(b, f)
           for b, _d, fs in os.walk(UD) for f in fs}
    bak = {os.path.relpath(os.path.join(b, f), bk): os.path.join(b, f)
           for b, _d, fs in os.walk(bk) for f in fs}
    extra_root = bk + "_extra"
    extras = sorted(set(cur) - set(bak))
    for rel in extras:
        dst = os.path.join(extra_root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(cur[rel], dst)
    for rel in extras:
        shutil.move(cur[rel], os.path.join(extra_root, rel))
    for rel, src in bak.items():
        dst = os.path.join(UD, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    after = snap(UD)
    print("[RESTORE_VERIFY] %s（%d 项，新增搬走 %d 个）" % (
        "OK" if after == before else "MISMATCH", len(after), len(extras)), flush=True)
    return after == before


def run_one(target):
    out_png = os.path.join(SHOTS, "_check_ash_fx_%s.png" % target)
    if os.path.isfile(out_png):
        os.remove(out_png)
    cmd = [GODOT, "--path", ROOT, "--resolution", "1280x720",
           "--script", "res://tools/_check_ash_fx.gd", "--",
           "--screenshot", "--shotframe", "9999", "--target", target]
    print("[shot] %s ..." % target, flush=True)
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                           errors="replace", timeout=180)
    except subprocess.TimeoutExpired:
        print("   TIMEOUT %s" % target, flush=True)
        return False
    txt = (p.stdout or "") + "\n" + (p.stderr or "")
    errs = [l for l in txt.splitlines()
            if any(k in l for k in ["Parse Error", "SCRIPT ERROR", "ERROR:", "Failed loading resource"])]
    ok = os.path.isfile(out_png) and os.path.getsize(out_png) > 50000
    print("   rc=%d png=%s size=%d err_lines=%d" % (
        p.returncode, "OK" if ok else "MISS",
        os.path.getsize(out_png) if os.path.isfile(out_png) else 0, len(errs)), flush=True)
    for l in errs[:10]:
        print("   ERR", l[:200], flush=True)
    for l in txt.splitlines():
        if "[ashfx]" in l:
            print("   ", l[:220], flush=True)
    return ok and p.returncode == 0 and not errs


def main():
    if os.path.isdir(UD):
        before = snap(UD)
        shutil.copytree(UD, BK)
        print("[backup] %s（%d 项）" % (BK, len(before)), flush=True)
    else:
        before = {}
        print("[backup] userdata 不存在，跳过", flush=True)
    try:
        results = {t: run_one(t) for t in ["ash", "breath"]}
    finally:
        if before:
            restore(before, BK)
    print("[ASHFX] %s" % ("GREEN" if all(results.values()) else "RED"), flush=True)
    print("[ASHFX] " + " / ".join("%s=%s" % (k, "OK" if v else "FAIL") for k, v in results.items()), flush=True)
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
