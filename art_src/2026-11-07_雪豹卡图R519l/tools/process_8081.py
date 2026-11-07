# -*- coding: utf-8 -*-
"""R519l：8081 雪豹卡图，形象与氛围取自 snow_leopard 事件。

1024x1024 原图 -> (0,20,1024,941) = 1024x921 -> 448x403。
裁切窗底边在右下水印上方，保留完整头、四足与长尾。

用法：python tools/process_8081.py [--write]
"""
from pathlib import Path
import sys
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE.parent / "raw" / "8081.png"
PROC = HERE.parent / "processed"
OUT = ROOT / "assets" / "pics" / "8081.png"
CROP = (0, 20, 1024, 941)
TARGET = (448, 403)
WM_TOP = 948


def main() -> None:
    im = Image.open(RAW).convert("RGB")
    assert im.size == (1024, 1024), im.size
    assert CROP[3] <= WM_TOP, "水印进入裁切窗"
    print("原图", im.size, "裁", CROP, "目标", TARGET, "水印已裁掉")
    if "--write" not in sys.argv:
        return
    out = im.crop(CROP).resize(TARGET, Image.LANCZOS)
    PROC.mkdir(parents=True, exist_ok=True)
    out.save(PROC / "8081.png", "PNG", optimize=True)
    out.save(OUT, "PNG", optimize=True)
    print("->", OUT, out.size)


if __name__ == "__main__":
    main()
