# -*- coding: utf-8 -*-
"""R761：「诗」6069 道具图标收尾 —— 原图已是真透明（RGBA，四角 alpha=0），
所以不用 R755 那套棋盘格泛洪，直接 bbox → 正方形居中 → 128。

⚠️ RGB / A **分开**降采样再合并：透明区的 RGB 是 0（纯黑），一起缩会把描边外侧
染出一圈暗边。这里先把 RGB 铺在描边色底上再缩，alpha 单独缩。
"""
from PIL import Image, ImageChops

ROOT = "E:/work/card_rogue/"
SRC = ROOT + "art_src/2026-11-15_吟游诗人CG_R761/raw/icon_relic_6069.png"
OUT = ROOT + "assets/ui/relic_icon_6069.png"
EDGE = (22, 20, 40)      # 描边深色（原图 #1a1630 附近）
PAD = 0.04


def main():
    im = Image.open(SRC).convert("RGBA")
    a = im.split()[3]
    bb = a.point(lambda v: 255 if v >= 8 else 0).getbbox()
    side = int(max(bb[2] - bb[0], bb[3] - bb[1]) * (1.0 + PAD * 2))
    cx = (bb[0] + bb[2]) // 2
    cy = (bb[1] + bb[3]) // 2
    box = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    # 正方形可能越界 → 先扩一块描边色底，再整体裁
    canvas = Image.new("RGBA", (im.width + side, im.height + side), EDGE + (0,))
    canvas.paste(im, (side // 2, side // 2), im)
    box = (box[0] + side // 2, box[1] + side // 2, box[2] + side // 2, box[3] + side // 2)
    flat = canvas.crop(box)
    alpha = flat.split()[3].resize((128, 128), Image.LANCZOS)
    rgb = Image.composite(flat.convert("RGB"), Image.new("RGB", flat.size, EDGE),
                          flat.split()[3]).resize((128, 128), Image.LANCZOS)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    out.save(OUT)
    print("wrote", OUT, out.size, "bbox", bb, "side", side)


if __name__ == "__main__":
    main()
