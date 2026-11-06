# -*- coding: utf-8 -*-
"""R515 出图核验：三种事件各截一张（会弹真实窗口）。"""
import os
import shutil
import subprocess
import time

G = 'C:/Users/Administrator/.workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe'
ROOT = 'E:/work/card_rogue'
OUT = os.path.join(ROOT, 'art_src', '2026-11-07_事件插图R515', '_review')
os.makedirs(OUT, exist_ok=True)

SHOTS = [('delivery', '--delivery'), ('arcane', '--arcane'), ('lake_lady', '--lakelady')]

for name, arg in SHOTS:
    src = os.path.join(ROOT, 'screenshot_event.png')
    if os.path.exists(src):
        os.remove(src)
    t0 = time.time()
    r = subprocess.run([G, '--path', ROOT, 'res://scenes/event.tscn', '--', arg, '--screenshot'],
                       cwd=ROOT, capture_output=True, timeout=180)
    if os.path.exists(src):
        shutil.move(src, os.path.join(OUT, name + '.png'))
        print('%-10s ok   %.1fs  %d KB' % (name, time.time() - t0,
                                           os.path.getsize(os.path.join(OUT, name + '.png')) // 1024))
    else:
        print('%-10s MISSING rc=%d' % (name, r.returncode))
        print((r.stdout or b'').decode('utf-8', 'replace')[-800:])
