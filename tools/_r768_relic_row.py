# -*- coding: utf-8 -*-
"""R768：猴爪（6066）道具图标在**道具栏真实尺寸**下与邻居的并排验收。

为什么要看 44px：RelicBarLayout.CELL = 44.0，图标在游戏里就显示这么大。
128×128 的原图好看不代表 44px 下认得出 —— 这是 R765 巧克力图标学到的，
这次一并按同样标准验。

输出：_review/relic_row_6066.png
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"E:\work\card_rogue")
UI = ROOT / "assets" / "ui"
OUT = ROOT / "art_src" / "2026-11-16_诅咒火柴人_R768" / "_review"

CELL = 44          # RelicBarLayout.CELL
ORDER = [6064, 6065, 6066, 6067, 6068, 6069]
BIG = 128          # 原图尺寸，放大参考用


def font(sz, bold=False):
    names = ("msyhbd.ttc", "msyh.ttc") if bold else ("msyh.ttc", "msyhbd.ttc")
    for name in names + ("simhei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype("C:/Windows/Fonts/" + name, sz)
        except Exception:
            continue
    return ImageFont.load_default()


def measure(im):
    """不透明 bbox 与实际覆盖率 —— 判「看起来小」靠这个，不靠眼睛。"""
    a = im.convert("RGBA").split()[-1]
    box = a.getbbox()
    if box is None:
        return None, 0.0
    w, h = box[2] - box[0], box[3] - box[1]
    opaque = sum(1 for v in a.getdata() if v > 8)
    return (w, h, box), opaque / float(im.width * im.height)


def main():
    PAD = 14
    ROW1_H = BIG + 20
    W = PAD + len(ORDER) * (BIG + PAD)
    H = 34 + ROW1_H + 48 + CELL + 44
    canvas = Image.new("RGB", (W, H), (26, 19, 33))    # 道具栏所在面板的深棕紫底
    dr = ImageDraw.Draw(canvas)
    dr.text((PAD, 8), "猴爪 6066 道具图标 — 上排原图 128px，下排道具栏实尺 44px（与邻居同框）",
            font=font(14, True), fill=(238, 226, 246))

    # 标题下留够一行标签的高度再落图，否则第一列的数字标签会压在标题上
    y_big = 44
    y_small = y_big + ROW1_H + 34
    for i, rid in enumerate(ORDER):
        p = UI / ("relic_icon_%d.png" % rid)
        if not p.exists():
            continue
        im = Image.open(p).convert("RGBA")
        x = PAD + i * (BIG + PAD)
        # 上排：原图铺在 checker 底上，看得清 alpha
        base = Image.new("RGBA", (BIG, BIG), (46, 36, 54, 255))
        base.alpha_composite(im.resize((BIG, BIG), Image.LANCZOS))
        canvas.paste(base.convert("RGB"), (x, y_big))
        # 下排：真实 44px
        small = Image.new("RGBA", (CELL, CELL), (46, 36, 54, 255))
        small.alpha_composite(im.resize((CELL, CELL), Image.LANCZOS))
        canvas.paste(small.convert("RGB"), (x, y_small))

        box, cov = measure(im)
        tag = "猴爪 ★" if rid == 6066 else str(rid)
        dr.text((x, y_big - 16), tag, font=font(12, True),
                fill=(255, 214, 120) if rid == 6066 else (176, 162, 190))
        if box:
            dr.text((x, y_small + CELL + 4), "%dx%d  %.0f%%" % (box[0], box[1], cov * 100),
                    font=font(10), fill=(150, 140, 164))

    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / "relic_row_6066.png"
    canvas.save(dst)
    print("->", dst, canvas.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
