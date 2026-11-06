# -*- coding: utf-8 -*-
"""R512 出图核验：六种事件各截一张（会弹真实窗口，每次约 3 秒）。"""
import os
import shutil
import subprocess
import time

G = 'C:/Users/Administrator/.workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe'
ROOT = 'D:/work/card_rogue'
OUT = os.path.join(os.environ['TEMP'], 'r512shots')
os.makedirs(OUT, exist_ok=True)

SHOTS = [('moon', '--moon'), ('furnace', '--furnace'), ('cave', '--cave'),
         ('merchant', '--cardmerchant'), ('core', '--corecontract'),
         ('gaze', '--gaze')]

for name, arg in SHOTS:
    src = os.path.join(ROOT, 'screenshot_event.png')
    if os.path.exists(src):
        os.remove(src)
    t0 = time.time()
    r = subprocess.run([G, '--path', ROOT, 'res://scenes/event.tscn', '--', arg, '--screenshot'],
                       cwd=ROOT, capture_output=True, timeout=120)
    if os.path.exists(src):
        shutil.move(src, os.path.join(OUT, name + '.png'))
        print('%-9s ok   %.1fs  %d KB' % (name, time.time() - t0,
                                          os.path.getsize(os.path.join(OUT, name + '.png')) // 1024))
    else:
        print('%-9s MISSING rc=%d' % (name, r.returncode))
        print((r.stdout or b'').decode('utf-8', 'replace')[-600:])
