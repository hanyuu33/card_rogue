# -*- coding: utf-8 -*-
"""R519n：9223 执法者卡图出图 + 处理。

用户口径：「执法者：持枪的警员机器人，注意科幻感」。

画风锚点：`assets/pics/9131.png`（量产型俄倪厄，执法者同阵营机械单位，已验收的
赛璐璐卡图）——深灰炭黑装甲 + 黄色警示条纹 + 青色发光眼睛 + 清晰描边美漫赛璐璐。
执法者沿用这套视觉语言，改成直立持枪的警员机器人。

裁切：1024×1024 → 取 (0, 70, 1024, 991) = 1024×921 → 448×403（卡图标准口径）。
水印固定框（R515b 口径）在全图坐标 = (872, 948, 1024, 1024)，上沿 948 落在本裁切窗内
（948 < 991），故对窗内部分 (872, 878, 1024, 921) 做 patch_wm 修补——该区域是右脚外的
背景地面，无主体，修补安全。

用法：
    python tools/process_9223.py           # 干跑：只打印裁切框
    python tools/process_9223.py --write   # 落盘 processed + assets/pics/9223.png
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE.parent / "raw" / "EDIT_THIS_IMAGE_while_preservi_2026-11-08T03-56-59.png"
PROC = HERE.parent / "processed"
PICS = ROOT / "assets" / "pics"

CROP = (0, 40, 1024, 961)    # 1024×921 ≈ 448×403 的宽高比；顶部上移以容纳警帽（帽顶 y≈55）
TARGET = (448, 403)
WM_BOX = (872, 948, 1024, 1024)   # 水印固定框（全图坐标）


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


def main() -> None:
    write = "--write" in sys.argv
    im = Image.open(RAW).convert("RGB")
    bx = (WM_BOX[0], WM_BOX[1] - CROP[1], WM_BOX[2], WM_BOX[3] - CROP[1])
    inside = not (bx[3] <= 0 or bx[1] >= (CROP[3] - CROP[1]))
    print("原图", im.size, "裁", CROP, "水印窗内框", bx,
          "→", "需修补" if inside else "已裁掉")
    if not write:
        return
    out = im.crop(CROP)
    if inside:
        patch_wm(out, bx)
    out = out.resize(TARGET, Image.LANCZOS)
    PROC.mkdir(parents=True, exist_ok=True)
    out.save(PROC / "9223.png", "PNG", optimize=True)
    out.save(PICS / "9223.png", "PNG", optimize=True)
    print("→ assets/pics/9223.png", out.size, (PICS / "9223.png").stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
