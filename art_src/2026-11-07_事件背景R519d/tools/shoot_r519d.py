# -*- coding: utf-8 -*-
"""R519d 出图核验：六个刚补了背景的事件各截一张。

`event_scene` 支持 `--<kind>` 演示参数（伪装成该事件节点），加 `--screenshot` 就
画完一帧自动存 `screenshot_event.png` 并退出。这里逐张跑、改名归档到 `_review/`。

用法：python shoot_r519d.py
"""
import os
import shutil
import subprocess
import time

G = "C:/Users/Administrator/.workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe"
if not os.path.exists(G):
    G = "C:/Users/Administrator/.workbuddy/binaries/godot/Godot_v4.3-stable_win64.exe"
ROOT = "E:/work/card_rogue"
OUT = os.path.join(ROOT, "art_src", "2026-11-07_事件背景R519d", "_review")
os.makedirs(OUT, exist_ok=True)

SHOTS = [
    ("struggle", "--struggle"),
    ("oblivion", "--oblivion"),
    ("smith", "--smith"),
    ("snow_leopard", "--snowleopard"),
    ("adventurer", "--adventurer"),
    ("martial", "--martial"),
]

for name, arg in SHOTS:
    src = os.path.join(ROOT, "screenshot_event.png")
    if os.path.exists(src):
        os.remove(src)
    t0 = time.time()
    r = subprocess.run([G, "--path", ROOT, "--resolution", "1280x720",
                        "res://scenes/event.tscn", "--", arg, "--screenshot"],
                       cwd=ROOT, capture_output=True, timeout=180)
    if os.path.exists(src):
        shutil.move(src, os.path.join(OUT, name + ".png"))
        print("%-14s ok   %.1fs  %d KB" % (name, time.time() - t0,
                                           os.path.getsize(os.path.join(OUT, name + ".png")) // 1024))
    else:
        print("%-14s MISSING rc=%d" % (name, r.returncode))
        print((r.stdout or b"").decode("utf-8", "replace")[-600:])
