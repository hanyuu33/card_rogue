# -*- coding: utf-8 -*-
"""R519d：六张事件整屏背景（第一层缺的那几个）的裁切与落盘。

素材是 1536×1024，裁成 16:9 后缩到 1280×720 —— 与 `bg_arcane` 等既有背景同一口径。

⚠️ 水印：后端默认水印「AI生成 WORKBUDDY」固定贴在**右下角**（约 130×44，距右 6、距底 12）。
1536×1024 居中裁 16:9 会取 y=80..944，水印在 y≈948 之下 → **自然裁掉**。
脚本仍会逐张复核一次，若水印框落在裁切窗内就改用「上方条带镜像贴回」修补。

用法：
    python process_r519d.py           # 干跑：只打印裁切框 + 水印是否已越界
    python process_r519d.py --write   # 真跑：裁切 + 缩放 + 落 assets/ui
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE.parent / "raw"
PROC = HERE.parent / "processed"
UI = ROOT / "assets" / "ui"

JOBS = [
    ("bg_struggle",     "Semi_realistic_painted_fantasy_2026-11-07T05-15-00.png"),
    ("bg_oblivion",     "Semi_realistic_painted_fantasy_2026-11-07T05-15-32.png"),
    ("bg_smith",        "Semi_realistic_painted_fantasy_2026-11-07T05-15-48.png"),
    ("bg_snow_leopard", "Semi_realistic_painted_fantasy_2026-11-07T05-16-06.png"),
    ("bg_adventurer",   "Semi_realistic_painted_fantasy_2026-11-07T05-16-17.png"),
    ("bg_martial",      "Semi_realistic_painted_fantasy_2026-11-07T05-16-32.png"),
]

TARGET = (1280, 720)


def wm_box(im: Image.Image) -> tuple[int, int, int, int]:
    """水印的固定框（沿用 R515b 的口径：右下角，四周留 16px 余量）。"""
    w, h = im.size
    return (w - 152, h - 76, w, h)


def patch_wm(im: Image.Image, bx: tuple[int, int, int, int]) -> None:
    """取上方等高条带 → 垂直镜像 → 轻模糊 → 软边贴回（R515b 同款）。"""
    x0, y0, x1, y1 = bx
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(im.size[0], x1), min(im.size[1], y1)
    w, h = x1 - x0, y1 - y0
    sy = max(0, y0 - h - 8)
    if y0 - sy < 4:
        sy = min(im.size[1] - h, y1 + 8)
        src = im.crop((x0, sy, x1, sy + h))
    else:
        src = im.crop((x0, sy, x1, y0)).transpose(Image.FLIP_TOP_BOTTOM)
    src = src.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(2.0))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rectangle([5, 5, w - 6, h - 6], fill=255)
    im.paste(src, (x0, y0), mask.filter(ImageFilter.GaussianBlur(3.2)))


def crop_16_9(im: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int]]:
    """居中裁成 16:9，返回裁切后的图与用掉的框（便于核对水印位置）。"""
    w, h = im.size
    nh = round(w * 9 / 16)
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh)), (0, y, w, y + nh)


def main() -> None:
    write = "--write" in sys.argv
    if write:
        PROC.mkdir(parents=True, exist_ok=True)
        UI.mkdir(parents=True, exist_ok=True)
    for name, fname in JOBS:
        src = RAW / fname
        if not src.exists():
            print("跳过（没有原图）:", fname)
            continue
        im = Image.open(src).convert("RGB")
        bx = wm_box(im)
        cropped, used = crop_16_9(im)
        inside = not (bx[3] <= used[1] or bx[1] >= used[3])
        print("[%-16s] %s 裁 %s 水印框 %s → %s"
              % (name, im.size, used, bx, "仍在窗内，需修补" if inside else "已裁掉"))
        if not write:
            continue
        if inside:
            patch_wm(cropped, (bx[0], bx[1] - used[1], bx[2], bx[3] - used[1]))
        out = cropped.resize(TARGET, Image.LANCZOS)
        out.save(PROC / (name + ".png"), "PNG", optimize=True)
        out.save(UI / (name + ".png"), "PNG", optimize=True)
        print("   → %s.png %s %d KB"
              % (name, out.size, (UI / (name + ".png")).stat().st_size // 1024))


if __name__ == "__main__":
    main()
