# -*- coding: utf-8 -*-
"""R519p：9210 寒霜结界 / 9212 枭熊之怒 卡图出图 + 处理。

用户口径：「继续生成敌人的」—— 敌人待做剩 9210 寒霜结界、9212 枭熊之怒（执法者 R519o 已收）。

画风纪律：项目卡图统一「日式动漫赛璐璐、禁止写实」（art_src/_style_prompts.md A 套 +
卡图索引 R407 口径）。两张敌方「效果卡」都走赛璐璐，不沿用 9214/9011 那批旧图的写实厚涂。

- 9210 寒霜结界：image1 = `assets/pics/8081.png`（雪豹，冷蓝灰赛璐璐画风锚点，只借画风），
  文生冰霜魔法结界（青色发光符文圈 + 环绕冰晶尖刺 + 地面霜纹）。
- 9212 枭熊之怒：image1 = `assets/pics/9214.png`（敌方枭熊形象，只借角色设计），
  改赛璐璐 + 发怒扑击姿态。

裁切（448×403 ≈ 1.1117，1024×921）：
- 9210：主体结界居中，顶部冰刺尖 y≈140，取 `(0,55,1024,976)`；水印右下 `(872,948,1024,1024)`
  上沿 948 < 976 落在窗内 → `patch_wm()` 修补（右下角暗色地面，无主体，安全）。
- 9212：主体头/双爪/后腿，水印在 y≈944 起、裁切底 936 已避开，取 `(0,15,1024,936)` 不需修补。

用法：
    python tools/process_r519p.py           # 干跑：只打印裁切框
    python tools/process_r519p.py --write   # 落盘 processed + assets/pics/<id>.png
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE.parent / "raw"
PROC = HERE.parent / "processed"
PICS = ROOT / "assets" / "pics"

TARGET = (448, 403)

JOBS = {
    "9210": {"raw": "9210_frost_ward.png", "crop": (0, 55, 1024, 976),
             "wm": (760, 890, 1024, 1024)},   # 文字 y≈895 起，框上移到 890 覆盖顶部
    "9212": {"raw": "9212_owlbear_fury.png", "crop": (0, 15, 1024, 936),
             "wm": (872, 948, 1024, 1024)},   # 裁切底 936 已避开，无需修补
}


def patch_wm(im: Image.Image, bx: tuple[int, int, int, int]) -> None:
    """取上方等高条带 → 垂直镜像 → 轻模糊 → 软边贴回（R515b 同款）。"""
    x0, y0, x1, y1 = bx
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(im.size[0], x1), min(im.size[1], y1)
    w, h = x1 - x0, y1 - y0
    if w <= 0 or h <= 0:
        return
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


def patch_from_left(im: Image.Image, bx: tuple[int, int, int, int]) -> None:
    """取左侧等宽暗色地面 → 水平镜像 → 轻模糊 → 软边贴回（适合水印上方是亮主体的场景）。"""
    x0, y0, x1, y1 = bx
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(im.size[0], x1), min(im.size[1], y1)
    w, h = x1 - x0, y1 - y0
    if w <= 0 or h <= 0:
        return
    sx = max(0, x0 - w - 8)
    if x0 - sx < 4:
        sx = min(im.size[0] - w, x1 + 8)
        src = im.crop((sx, y0, sx + w, y1))
    else:
        src = im.crop((sx, y0, x0, y1)).transpose(Image.FLIP_LEFT_RIGHT)
    src = src.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(2.0))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rectangle([5, 5, w - 6, h - 6], fill=255)
    im.paste(src, (x0, y0), mask.filter(ImageFilter.GaussianBlur(3.2)))


def main() -> None:
    write = "--write" in sys.argv
    for cid, job in JOBS.items():
        crop = job["crop"]
        wm = job["wm"]
        im = Image.open(RAW / job["raw"]).convert("RGB")
        bx = (wm[0], wm[1] - crop[1], wm[2], wm[3] - crop[1])
        inside = not (bx[3] <= 0 or bx[1] >= (crop[3] - crop[1]))
        print(f"{cid}: 原图 {im.size} 裁 {crop} 水印窗内框 {bx} → {'需修补' if inside else '已裁掉'}")
        if not write:
            continue
        out = im.crop(crop)
        if inside:
            patch_from_left(out, bx)
        out = out.resize(TARGET, Image.LANCZOS)
        PROC.mkdir(parents=True, exist_ok=True)
        out.save(PROC / f"{cid}.png", "PNG", optimize=True)
        out.save(PICS / f"{cid}.png", "PNG", optimize=True)
        print(f"  → assets/pics/{cid}.png", out.size, (PICS / f"{cid}.png").stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
