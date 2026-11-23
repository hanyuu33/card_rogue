#!/usr/bin/env python3
"""黑底 → 透明抠图。把「纯黑背景」上的亮字抠出来。

用法：
  python tools/_matte_black.py --src <in.png> --dst <out.png> [--crop-right N] [--crop-bottom N]

抠法：非黑 = 前景。用 max(r,g,b) 判黑底（纯黑三通道都≈0，冰蓝字 b 高、火焰字 r 高，
比亮度键稳：深色阴影即使不饱和也能被 max 通道兜住）。暗阈值以下全透明、亮阈值以上全不透明，
中间线性羽化避免硬边。
"""
import sys
from PIL import Image


def matte(src: str, dst: str, crop_right: int = 0, crop_bottom: int = 0,
          lo: float = 0.055, hi: float = 0.28) -> None:
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    if crop_right or crop_bottom:
        im = im.crop((0, 0, w - crop_right, h - crop_bottom))
        w, h = im.size
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            mx = max(r, g, b) / 255.0
            if mx >= hi:
                na = 255
            elif mx > lo:
                na = int(round((mx - lo) / (hi - lo) * 255))
            else:
                na = 0
            px[x, y] = (r, g, b, na)
    im.save(dst)
    print(f"[matte] SAVED {dst} ({w}x{h})")


if __name__ == "__main__":
    args = sys.argv[1:]
    d = {}
    i = 0
    while i < len(args):
        if args[i].startswith("--") and i + 1 < len(args):
            d[args[i]] = args[i + 1]
            i += 2
        else:
            i += 1
    if "--src" not in d or "--dst" not in d:
        print("需要 --src 与 --dst")
        sys.exit(1)
    matte(d["--src"], d["--dst"],
          int(d.get("--crop-right", 0)), int(d.get("--crop-bottom", 0)))
