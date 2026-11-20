# -*- coding: utf-8 -*-
"""R842c 素材落地：raw -> processed -> assets/ui。

`bg_*` 缩到 1280×720（整屏），`event_*` 缩到 640×480（4:3 特写），
与既有 `bg_sword.png` / `event_sword.png` 同规格。

用法：python tools/_make_r842c_art.py [bg|event|all]
"""
import io
import os
import shutil
import struct
import sys

from PIL import Image

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-20_龙石板_R842")
RAW = os.path.join(D, "raw")
PROC = os.path.join(D, "processed")
UI = os.path.join(ROOT, "assets", "ui")

JOBS = {
    "bg": ("bg_dragon_slab.png", (1280, 720)),
    "event": ("event_dragon_slab.png", (640, 480)),
}


def png_size(p):
    b = io.open(p, "rb").read(33)
    return struct.unpack(">II", b[16:24])


def do_one(key, name, target):
    src = os.path.join(RAW, name)
    if not os.path.exists(src):
        print("MISS raw", src)
        return False
    os.makedirs(PROC, exist_ok=True)
    im = Image.open(src)
    if im.mode != "RGB":
        im = im.convert("RGB")
    sw, sh = im.size
    ratio = sw / sh
    want = target[0] / target[1]
    print("raw %dx%d ratio %.4f  target %s ratio %.4f" % (sw, sh, ratio, target, want))
    if abs(ratio - want) > 0.02:
        # 比例不对：居中裁到目标比例再缩，避免拉伸变形
        if ratio > want:
            new_w = int(round(sh * want))
            left = (sw - new_w) // 2
            im = im.crop((left, 0, left + new_w, sh))
            print("  crop width -> %d (center)" % new_w)
        else:
            new_h = int(round(sw / want))
            top = (sh - new_h) // 2
            im = im.crop((0, top, sw, top + new_h))
            print("  crop height -> %d (center)" % new_h)
    out = im.resize(target, Image.LANCZOS)
    dst_proc = os.path.join(PROC, name)
    out.save(dst_proc, optimize=True)
    dst_ui = os.path.join(UI, name)
    shutil.copyfile(dst_proc, dst_ui)
    assert io.open(dst_proc, "rb").read() == io.open(dst_ui, "rb").read()
    print("OK  %s -> %s  %s  %dKB  (ui byte-identical)" %
          (name, dst_ui, png_size(dst_ui), os.path.getsize(dst_ui) // 1024))
    return True


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    keys = list(JOBS) if which == "all" else [which]
    ok = True
    for k in keys:
        name, target = JOBS[k]
        ok = do_one(k, name, target) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
