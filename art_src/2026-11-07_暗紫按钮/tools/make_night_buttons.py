# -*- coding: utf-8 -*-
"""把 adventure_shared/button_paper.png 重映射成暗紫肤版本（R517）。

为什么不用 modulate_color：
    素材是「暖白纸面 + 黄铜金线」，直接乘色的话纸面能压成暗紫，
    但金线（原本就比纸暗）会被一起乘成更黑的暗红，金线直接消失 ——
    用户要的正是那条金线，乘色会把风格再丢一次。

这里的做法：按「暖度」分量分离纸面与金线，各自重映射到目标色：
    warm = R - B        纸面约 22，金线约 57 → 能干净分开
    warm≥50 → 金线色（保留原有明暗起伏）
    warm≤25 → 暗紫底（保留原有明暗起伏）
    中间做线性过渡，避免锯齿边
只改 RGB，alpha（尖角轮廓 + 抗锯齿）原样保留。

产出 4 张，尺寸与源一致（400×92），交给 Godot 走九宫格拉伸。
（本机没有 numpy，纯 PIL 逐像素，36800 像素跑起来是毫秒级。）
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, "assets", "ui", "adventure_shared", "button_paper.png")
OUT_DIR = os.path.join(ROOT, "assets", "ui", "adventure_shared")

PAPER = (0x2b, 0x21, 0x35)   # 暗紫底（UiTheme.NIGHT_BTN）
GOLD = (0xc9, 0xa9, 0x6a)    # 黄铜金线

VARIANTS = [
    ("button_night",          1.00, 1.00),
    ("button_night_hover",    1.30, 1.18),
    ("button_night_pressed",  0.78, 0.84),
    ("button_night_disabled", 0.70, 0.50),
]


def clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else (hi if v > hi else v)


def build(paper_k: float, gold_k: float) -> Image.Image:
    src = Image.open(SRC).convert("RGBA")
    w, h = src.size
    sp = src.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dp = out.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a == 0:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            warm = r - b

            shade_p = clamp(lum / 0.90, 0.86, 1.14)
            shade_g = clamp(lum / 0.76, 0.88, 1.16)
            k = clamp((warm - 25.0) / 25.0, 0.0, 1.0)

            res = []
            for i in range(3):
                pv = clamp(PAPER[i] * shade_p * paper_k, 0, 255)
                gv = clamp(GOLD[i] * shade_g * gold_k, 0, 255)
                res.append(int(round(pv * (1.0 - k) + gv * k)))
            dp[x, y] = (res[0], res[1], res[2], a)
    return out


def main() -> None:
    for name, pk, gk in VARIANTS:
        img = build(pk, gk)
        dst = os.path.join(OUT_DIR, name + ".png")
        img.save(dst)
        print("wrote", os.path.relpath(dst, ROOT), img.size)


if __name__ == "__main__":
    main()
