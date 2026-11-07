# -*- coding: utf-8 -*-
"""R519i：9018 金属龙卡图重出（写实厚涂 → 卡通赛璐璐）。

用户口径：「既然挣扎已经有图了，那么可以给金属龙也加上卡图了」。

澄清：`assets/pics/9018.png` **本来就有**（2026-11-01 批，manifest 标 approved），
游戏里正常显示，不是缺图 —— 但它是写实厚涂，与 R519e 定下的卡通赛璐璐不符。
本轮按 `bg_struggle.png`（挣扎事件背景）里那只金属龙的形象重出，
卡图风格参照 `assets/pics/9207.png`（量产型阿斯克勒庇厄斯，已验收的赛璐璐卡图）。

裁切：1024×1024 → 取 (0, 20, 1024, 941) = 1024×921 → 448×403（卡图标准口径）。
水印在右下 y≈948 之后 → 裁切窗底边 941 在其上，**自然裁掉**，不用修补。
代价：最下方那截爪尖被裁掉约 60px，卡图下缘裁切属正常构图。

旧图留档 `assets/pics/_legacy3d/9018__old_realistic.png`（沿用 9207 的 _legacy3d 惯例）。

用法：
    python tools/process_9018.py           # 干跑：只打印裁切框
    python tools/process_9018.py --write   # 落盘 + 旧图归档
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE.parent / "raw" / "9018.png"
PROC = HERE.parent / "processed"
PICS = ROOT / "assets" / "pics"
LEGACY = PICS / "_legacy3d"

CROP = (0, 20, 1024, 941)     # 1024×921 ≈ 448×403 的宽高比
TARGET = (448, 403)
WM_TOP = 948                  # 后端水印固定框的上沿（沿用 R515b 口径）


def main() -> None:
    write = "--write" in sys.argv
    im = Image.open(RAW).convert("RGB")
    print("原图", im.size, "裁", CROP,
          "水印", "已裁掉" if CROP[3] <= WM_TOP else "⚠️ 仍在窗内，需修补")
    if not write:
        return
    out = im.crop(CROP).resize(TARGET, Image.LANCZOS)
    PROC.mkdir(parents=True, exist_ok=True)
    out.save(PROC / "9018.png", "PNG", optimize=True)
    LEGACY.mkdir(parents=True, exist_ok=True)
    old = PICS / "9018.png"
    if old.exists() and not (LEGACY / "9018__old_realistic.png").exists():
        shutil.copy(old, LEGACY / "9018__old_realistic.png")
        print("旧图归档 → _legacy3d/9018__old_realistic.png")
    out.save(old, "PNG", optimize=True)
    print("→ assets/pics/9018.png", out.size, old.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
