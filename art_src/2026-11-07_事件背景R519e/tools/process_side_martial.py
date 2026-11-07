# -*- coding: utf-8 -*-
"""R519g：`side_martial.png` 的裁切 —— 左右布局的左栏竖图。

武术大师从「整屏背景 + 居中卡片」改成湖中仙女那种**左右布局**，需要一张 1:1 侧图，
口径与 `side_lake_lady.png` 一致（742×742，`KEEP_ASPECT_COVERED` 铺满左侧全高）。

原图 1536×1024 是宽幅出图，**右下角带后端水印**。做法不是修补而是**裁掉**：
取左边 1024×1024 方形（x=0..1024），水印在 x≈1400 之后 → 自然出界。
同时这一裁也把画面收成「主体在左、右侧连续压暗」的形状，正好给 `_side_fade_material()` 收边。

用法：
    python process_side_martial.py           # 干跑：打印裁切框 + 水印是否出界
    python process_side_martial.py --write   # 真跑：裁切 + 缩放 + 落 assets/ui
"""
from __future__ import annotations

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.dirname(HERE)
ROOT = os.path.abspath(os.path.join(SRC_DIR, "..", ".."))
RAW = os.path.join(SRC_DIR, "raw", "side_martial.png")
PROC = os.path.join(SRC_DIR, "processed")
UI = os.path.join(ROOT, "assets", "ui")

TARGET = (742, 742)          # 与 side_lake_lady.png 同口径
CROP = (0, 0, 1024, 1024)    # 左边方形；水印在 x≈1400 之后，出界
WM_BOX = (1384, 948, 1536, 1024)   # 沿用 R519d/e 的水印固定框


def main() -> None:
    write = "--write" in sys.argv
    im = Image.open(RAW).convert("RGB")
    print("原图", im.size, "裁", CROP)
    if not (WM_BOX[2] <= CROP[0] or WM_BOX[0] >= CROP[2]
            or WM_BOX[3] <= CROP[1] or WM_BOX[1] >= CROP[3]):
        print("  ⚠️ 水印框落在裁切窗内，需要修补")
        if not write:
            return
    else:
        print("  水印已出界")
    if not write:
        return
    # 不做右侧压暗：接缝实测已自然（草坡轮廓自己淡出 + `_side_fade_material()` 收边），
    # 再叠一道 ramp 反而会把坐在 60%~74% 的老人压暗。
    out = im.crop(CROP).resize(TARGET, Image.LANCZOS)
    os.makedirs(PROC, exist_ok=True)
    os.makedirs(UI, exist_ok=True)
    out.save(os.path.join(PROC, "side_martial.png"), "PNG", optimize=True)
    out.save(os.path.join(UI, "side_martial.png"), "PNG", optimize=True)
    print("   → side_martial.png", out.size,
          os.path.getsize(os.path.join(UI, "side_martial.png")) // 1024, "KB")


if __name__ == "__main__":
    main()
