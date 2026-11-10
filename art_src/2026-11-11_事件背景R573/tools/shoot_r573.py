# -*- coding: utf-8 -*-
"""R573 游戏内验收：三张新背景各截一张（必须带窗口，不能 --headless）。

复用 R519e 的截图口径：event_scene 的 --<kind> 演示参数 + --screenshot，
画完一帧自动存 screenshot_event.png 后退出。
"""
import shutil
import subprocess
import time
from pathlib import Path

G = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64_console.exe"
ROOT = Path(r"E:\work\card_rogue")
OUT = ROOT / "art_src" / "2026-11-11_事件背景R573" / "_review"
OUT.mkdir(parents=True, exist_ok=True)
SHOTS = [("pear", "--pear"), ("hero", "--hero"), ("flyer", "--flyer")]

for name, arg in SHOTS:
    src = ROOT / "screenshot_event.png"
    if src.exists():
        src.unlink()
    t0 = time.time()
    r = subprocess.run([G, "--path", str(ROOT), "--resolution", "1280x720",
                        "res://scenes/event.tscn", "--", arg, "--screenshot"],
                       cwd=str(ROOT), capture_output=True, timeout=180)
    if src.exists():
        dst = OUT / ("ingame_" + name + ".png")
        shutil.move(str(src), str(dst))
        print("%-8s ok   %.1fs  %d KB" % (
            name, time.time() - t0, dst.stat().st_size // 1024), flush=True)
    else:
        print("%-8s MISSING rc=%d" % (name, r.returncode), flush=True)
        print((r.stdout or b"").decode("utf-8", "replace")[-800:], flush=True)
