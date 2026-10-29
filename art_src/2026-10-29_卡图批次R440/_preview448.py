# -*- coding: utf-8 -*-
"""448 卡面预览：raw → art_src/_review/<id>_卡面预览448.png

只为「交稿前看看有没有被切」用，**不写 assets/pics/**（入库要走 process.py，且要用户点头）。
链路与 process.py 一致：切底部 11%（去水印）→ 1.1117 cover → LANCZOS 448×403。

用法：python _preview448.py 9022:9022_鸭蛋_v1_候选.png
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "..", "_review")
W, H = 448, 403
RATIO = W / H
WATERMARK_CUT = 0.11


def cover(im: Image.Image, ratio: float) -> Image.Image:
    w, h = im.size
    if w / h > ratio:
        nw = int(round(h * ratio))
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(round(w / ratio))
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for arg in sys.argv[1:]:
        cid, _, name = arg.partition(":")
        if not name:
            raise SystemExit("用法：python _preview448.py 9022:9022_鸭蛋_v1_候选.png")
        im = Image.open(os.path.join(RAW, name)).convert("RGB")
        w, h = im.size
        cut = int(round(h * WATERMARK_CUT))
        im = im.crop((0, 0, w, h - cut))
        im = cover(im, RATIO).resize((W, H), Image.LANCZOS)
        dst = os.path.join(OUT, "%s_卡面预览448.png" % cid)
        im.save(dst, "PNG", optimize=True)
        print("%s -> %s (%dx%d)" % (name, dst, im.size[0], im.size[1]))


if __name__ == "__main__":
    main()
