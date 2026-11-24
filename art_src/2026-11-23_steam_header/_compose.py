# -*- coding: utf-8 -*-
"""把 codex 出的无字底图 + QUACKILL 标题素材合成 Steam 横条。

口径（店长 2026-11-23）：
  * 缩放一律「等比缩小 + 裁剪」，禁止拉伸（x/y 不同比例缩放）。
  * 标题素材用 release/store/quackill_title_en_alpha.png（透明通道），
    只做等比缩放，不变形、不裁字。
  * 先在原始分辨率上排版，最后一步才整体缩小到目标像素。

用法：
    python _compose.py                 # 用 raw/header_v1.png 出全部尺寸
    python _compose.py --raw raw/x.png --title-w 0.60 --title-y 0.22
"""
import argparse
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
D = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "release", "store", "header_capsule")
TITLE = os.path.join(ROOT, "release", "store", "quackill_title_en_alpha.png")

# 目标尺寸：Steam header capsule 与 main capsule，各带 2x。
TARGETS = [
    ("header_460x215", 460, 215),
    ("header_920x430", 920, 430),
    ("main_616x353", 616, 353),
    ("main_1232x706", 1232, 706),
]


def crop_to_aspect(im, aw, ah):
    """居中裁剪到目标宽高比（双向自适应），返回裁剪后的图。"""
    w, h = im.size
    target = aw / float(ah)
    cur = w / float(h)
    if cur > target:                      # 比目标宽 → 切左右
        nw = int(round(h * target))
        x = (w - nw) // 2
        box = (x, 0, x + nw, h)
    else:                                 # 比目标高 → 切上下
        nh = int(round(w / target))
        y = (h - nh) // 2
        box = (0, y, w, y + nh)
    return im.crop(box), box


def place_title(canvas, title, width_ratio, center_y_ratio):
    """把标题按宽度比例等比缩放后贴到画布中轴，返回贴好的图。"""
    cw, ch = canvas.size
    tw = int(round(cw * width_ratio))
    th = int(round(tw * title.height / float(title.width)))
    t = title.resize((tw, th), Image.LANCZOS)
    x = (cw - tw) // 2
    y = int(round(ch * center_y_ratio - th / 2.0))
    out = canvas.copy()
    out.paste(t, (x, y), t)
    return out, (x, y, tw, th)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=os.path.join(D, "raw", "header_v1.png"))
    ap.add_argument("--title-w", type=float, default=0.58, help="标题宽度占画布宽度比例")
    ap.add_argument("--title-y", type=float, default=0.225, help="标题中心垂直位置比例")
    ap.add_argument("--tag", default="v1")
    args = ap.parse_args()

    base = Image.open(args.raw).convert("RGB")
    title = Image.open(TITLE).convert("RGBA")
    print("底图 %s  %dx%d" % (args.raw, base.width, base.height))
    print("标题 %s  %dx%d" % (TITLE, title.width, title.height))

    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, aw, ah in TARGETS:
        cropped, box = crop_to_aspect(base, aw, ah)
        composed, tbox = place_title(cropped, title, args.title_w, args.title_y)
        # 关键：只在最后一步等比缩小到目标像素。
        final = composed.resize((aw, ah), Image.LANCZOS)
        path = os.path.join(OUT, "%s_%s.png" % (name, args.tag))
        final.save(path, optimize=True)
        made.append(path)
        print("  %-22s crop=%s  title=%s  -> %dx%d" % (name, box, tbox, aw, ah))
    print("输出 %d 张 -> %s" % (len(made), OUT))


if __name__ == "__main__":
    main()
