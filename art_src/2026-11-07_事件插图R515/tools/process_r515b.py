# -*- coding: utf-8 -*-
"""R515b：整屏 CG 版（delivery / arcane）+ 湖中仙女改稿（银金双卡）。

三张图都带后端默认水印「AI生成 WORKBUDDY」（右下角固定位置、灰白半透明）。
水印压在画面内部（大图裁 16:9 之后仍在），切边切不掉，所以改成**局部修补**：
取水印正上方一条等高的画面，垂直镜像 + 轻高斯模糊后贴回，再用软边遮罩羽化接缝。
背景都是土路 / 苔藓之类的低结构纹理，这么补肉眼看不出来。

用法：
    python process_r515b.py            # 干跑：只打印检测到的水印框
    python process_r515b.py --write    # 真跑：修补 + 裁切 + 缩放 + 落 assets/ui
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
RAW = os.path.join(ROOT, "art_src", "2026-11-07_事件插图R515", "raw")
PROC = os.path.join(ROOT, "art_src", "2026-11-07_事件插图R515", "processed")
UI = os.path.join(ROOT, "assets", "ui")

JOBS = [
    # (输出名, raw 文件, 目标尺寸, 裁切比例 "16:9" / "4:3" / "none")
    ("bg_delivery", "JAPANESE_ANIME_trading_card_ga_2026-11-06T23-50-48.png", (1280, 720), "16:9"),
    ("bg_arcane", "JAPANESE_ANIME_trading_card_ga_2026-11-06T23-51-08.png", (1280, 720), "16:9"),
    ("event_lake_lady", "JAPANESE_ANIME_trading_card_il_2026-11-06T23-51-39.png", (640, 480), "4:3"),
    # R516：左右布局的左栏竖图。1:1 出图，缩到 742×742 由 KEEP_ASPECT_COVERED 铺满左侧全高。
    ("side_lake_lady", "JAPANESE_ANIME_trading_card_il_2026-11-07T00-36-04.png", (742, 742), "none"),
]

RATIOS = {"16:9": (16, 9), "4:3": (4, 3)}


def find_wm(im):
    """水印是**固定像素尺寸贴在右下角**：约 130×44，距右 6px、距底 12px。

    不能用绝对亮度阈值找 —— 它半透明压在原画上，暗部只有 ~160 的亮度
    （1536 宽的 CG 就完全检不到）；亮部又会和画面里的白高光混（湖面花瓣 255）。
    所以直接给固定框，四周留 16px 余量。
    """
    w, h = im.size
    return (w - 152, h - 76, w, h), 0


def patch_wm(im, bx):
    """用上方等高条带（垂直镜像 + 模糊）盖掉水印，软边羽化。"""
    x0, y0, x1, y1 = bx
    x0 = max(0, x0); y0 = max(0, y0)
    x1 = min(im.size[0], x1); y1 = min(im.size[1], y1)
    w, h = x1 - x0, y1 - y0
    sy = max(0, y0 - h - 8)
    if y0 - sy < 4:                      # 上方没空间就往下取
        sy = min(im.size[1] - h, y1 + 8)
        src = im.crop((x0, sy, x1, sy + h))
    else:
        src = im.crop((x0, sy, x1, y0)).transpose(Image.FLIP_TOP_BOTTOM)
    src = src.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(2.0))

    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rectangle([5, 5, w - 6, h - 6], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(3.2))
    im.paste(src, (x0, y0), mask)
    return bx


def to_ratio(im, ratio):
    w, h = im.size
    want = ratio[0] / ratio[1]
    if w / h > want:
        nw = int(round(h * want))
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(round(w / want))
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def main():
    write = "--write" in sys.argv
    if write:
        os.makedirs(PROC, exist_ok=True)
    for name, fname, target, mode in JOBS:
        src = os.path.join(RAW, fname)
        im = Image.open(src).convert("RGB")
        bx, n = find_wm(im)
        print("[%s] %s  水印框 %s" % (name, im.size, bx))
        if not write:
            continue
        if bx is not None:
            patch_wm(im, bx)
        if mode in RATIOS:
            im = to_ratio(im, RATIOS[mode])
        out = im.resize(target, Image.LANCZOS)
        if target[0] <= 800:
            out = out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=55, threshold=2))
        out.save(os.path.join(PROC, name + ".png"), "PNG", optimize=True)
        out.save(os.path.join(UI, name + ".png"), "PNG", optimize=True)
        print("  → %s.png  %s  %d KB" % (name, out.size, os.path.getsize(os.path.join(UI, name + ".png")) // 1024))


if __name__ == "__main__":
    main()
