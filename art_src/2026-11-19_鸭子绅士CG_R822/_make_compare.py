# -*- coding: utf-8 -*-
"""R819 鸭子绅士 CG 对比页：把「游戏内鸭子参照 / v1 / v2 / v3」并排拼一张。

用法：python _make_compare.py
输出：compare_duck_gentleman.png（同目录）
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-19_鸭子绅士CG_R822")
RAW = os.path.join(D, "raw")

PANEL_W, PANEL_H, GAP, PAD, BAR = 760, 428, 18, 22, 46
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\msyhbd.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
]

ITEMS = [
    (os.path.join(ROOT, "assets", "pics", "9001.png"), "游戏内参照：鸭子骑士 9001（约2.5头身·无脖子）"),
    (os.path.join(RAW, "cg_duck_gentleman_v1.png"), "v1 七头身瘦管家（否决）"),
    (os.path.join(RAW, "cg_duck_gentleman_v2.png"), "v2 胖鸭回来了·脖子被领口藏住"),
    (os.path.join(RAW, "cg_duck_gentleman_v3.png"), "v3 脖子加强版"),
]


def font(size):
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:  # noqa: BLE001
                continue
    return ImageFont.load_default()


def main():
    items = [(p, t) for p, t in ITEMS if os.path.exists(p)]
    if len(items) < 2:
        print("素材不足，至少要有 2 张")
        return 1

    cols = 2
    rows = (len(items) + cols - 1) // cols
    W = PAD * 2 + cols * PANEL_W + (cols - 1) * GAP
    H = PAD * 2 + rows * (PANEL_H + BAR) + (rows - 1) * GAP
    canvas = Image.new("RGB", (W, H), (26, 28, 34))
    draw = ImageDraw.Draw(canvas)
    f = font(22)

    for i, (path, title) in enumerate(items):
        im = Image.open(path).convert("RGB")
        # 居中裁成 16:9 左右的面板比例，不拉伸
        ratio = PANEL_W / PANEL_H
        w, h = im.size
        if w / h > ratio:
            nw = int(h * ratio)
            im = im.crop(((w - nw) // 2, 0, (w + nw) // 2, h))
        else:
            nh = int(w / ratio)
            im = im.crop((0, max(0, (h - nh) // 2), w, max(0, (h - nh) // 2) + nh))
        im = im.resize((PANEL_W, PANEL_H), Image.LANCZOS)

        r, c = divmod(i, cols)
        x = PAD + c * (PANEL_W + GAP)
        y = PAD + r * (PANEL_H + BAR + GAP)
        canvas.paste(im, (x, y))
        draw.text((x + 6, y + PANEL_H + 10), title, font=f, fill=(238, 236, 230))

    out = os.path.join(D, "compare_duck_gentleman.png")
    canvas.save(out)
    print("OK", out, canvas.size, "面板数", len(items))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
