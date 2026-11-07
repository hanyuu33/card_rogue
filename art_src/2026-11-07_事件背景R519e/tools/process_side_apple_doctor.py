# -*- coding: utf-8 -*-
"""R519j：苹果与医生左右布局侧图 = 木制餐桌上的一只苹果。

原图为 1024×1024 方图；右下角水印在画面内，沿用 R519h 的镜像条带修补。
产物：`assets/ui/side_apple_doctor.png` 742×742。

用法：
    python process_side_apple_doctor.py           # 干跑
    python process_side_apple_doctor.py --write   # 修补水印 + 缩放 + 落盘
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from process_r519e import patch_wm, wm_box  # noqa: E402

ROOT = HERE.parents[2]
RAW = HERE.parent / "raw" / "side_apple_doctor.png"
PROC = HERE.parent / "processed"
UI = ROOT / "assets" / "ui"
NAME = "side_apple_doctor"
TARGET = (742, 742)


def main() -> None:
    write = "--write" in sys.argv
    im = Image.open(RAW).convert("RGB")
    if im.size != (1024, 1024):
        raise ValueError("side_apple_doctor 原图必须是 1024×1024，实际 %s" % (im.size,))
    bx = wm_box(im)
    print("原图 %s 水印框 %s → 在画面内，需修补" % (im.size, bx))
    if not write:
        return
    patch_wm(im, bx)
    out = im.resize(TARGET, Image.LANCZOS)
    PROC.mkdir(parents=True, exist_ok=True)
    UI.mkdir(parents=True, exist_ok=True)
    out.save(PROC / (NAME + ".png"), "PNG", optimize=True)
    out.save(UI / (NAME + ".png"), "PNG", optimize=True)
    print("→ %s.png %s %d KB" % (NAME, out.size, (UI / (NAME + ".png")).stat().st_size // 1024))


if __name__ == "__main__":
    main()
