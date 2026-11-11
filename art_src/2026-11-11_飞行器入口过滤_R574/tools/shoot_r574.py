# -*- coding: utf-8 -*-
"""R574 截图验收：飞行器事件「正常态」与「旧档没油态」各一张。

必须带窗口（不能 --headless，dummy 渲染器下 get_image() 返回 null）。
"""
import shutil
import subprocess
import time
from pathlib import Path

G = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64_console.exe"
ROOT = Path(r"E:\work\card_rogue")
OUT = ROOT / "art_src" / "2026-11-11_飞行器入口过滤_R574" / "_review"
OUT.mkdir(parents=True, exist_ok=True)
SHOTS = [("flyer_ok", "--flyer"), ("flyer_low", "--flyerlow")]

for name, arg in SHOTS:
    src = ROOT / "screenshot_event.png"
    if src.exists():
        src.unlink()
    t0 = time.time()
    r = subprocess.run([G, "--path", str(ROOT), "--resolution", "1280x720",
                        "res://scenes/event.tscn", "--", arg, "--screenshot"],
                       cwd=str(ROOT), capture_output=True, timeout=180)
    if src.exists():
        dst = OUT / (name + ".png")
        shutil.move(str(src), str(dst))
        print("%-12s ok   %.1fs  %d KB" % (
            name, time.time() - t0, dst.stat().st_size // 1024), flush=True)
    else:
        print("%-12s MISSING rc=%d" % (name, r.returncode), flush=True)
        print((r.stdout or b"").decode("utf-8", "replace")[-800:], flush=True)
