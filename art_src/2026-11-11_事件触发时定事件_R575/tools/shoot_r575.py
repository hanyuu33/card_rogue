# -*- coding: utf-8 -*-
"""R575 截图验收：飞行器事件页（确认按钮与正文都不再提「消耗巧克力」）。

必须带窗口（不能 --headless，dummy 渲染器下 get_image() 返回 null）。
"""
import shutil
import subprocess
import time
from pathlib import Path

G = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64_console.exe"
ROOT = Path(r"E:\work\card_rogue")
OUT = ROOT / "art_src" / "2026-11-11_事件触发时定事件_R575" / "_review"
OUT.mkdir(parents=True, exist_ok=True)

src = ROOT / "screenshot_event.png"
if src.exists():
    src.unlink()
t0 = time.time()
r = subprocess.run([G, "--path", str(ROOT), "--resolution", "1280x720",
                    "res://scenes/event.tscn", "--", "--flyer", "--screenshot"],
                   cwd=str(ROOT), capture_output=True, timeout=180)
if src.exists():
    dst = OUT / "flyer_no_chocolate_cost.png"
    shutil.move(str(src), str(dst))
    print("ok %.1fs %d KB -> %s" % (time.time() - t0, dst.stat().st_size // 1024, dst), flush=True)
else:
    print("MISSING rc=%d" % r.returncode, flush=True)
    print((r.stdout or b"").decode("utf-8", "replace")[-900:], flush=True)
