# -*- coding: utf-8 -*-
"""R793：生成静态道具图标 assets/ui/relic_icon_6075.png（大师之剑）。

风格对齐现有道具图标（参考 relic_icon_6053 骑士剑）：透明底、卡通粗描边、
主体居中、钢蓝剑身 + 金色护手；与 6053 的区别 = **蓝色握柄 + 刃身凹槽 + 护手宝石**
（骑士剑是紫柄、无凹槽、无宝石），一眼能分开。

做法：4 倍超采样 + 逐层「外描边 / 内填色」（MinFilter 侵蚀出内形），最后 LANCZOS 缩回 128。
"""
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
S = 4
PX = SIZE * S
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui", "relic_icon_6075.png")

INK = (33, 32, 42, 255)          # 描边（近黑）
BLADE_HI = (238, 243, 250)       # 剑身亮部
BLADE_LO = (150, 168, 190)       # 剑身暗部
FULLER = (74, 124, 196)          # 刃中凹槽（蓝）
GUARD_HI = (233, 183, 60)        # 护手金
GUARD_LO = (176, 122, 34)        # 护手暗金
GRIP_HI = (68, 104, 176)         # 握柄亮（蓝）
GRIP_LO = (36, 60, 116)          # 握柄暗
GEM = (94, 196, 226)             # 护手宝石（青）


def sc(pts):
    return [(x * S, y * S) for x, y in pts]


def mask_poly(pts):
    m = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(m).polygon(sc(pts), fill=255)
    return m


def mask_round_line(a, b, w):
    m = Image.new("L", (PX, PX), 0)
    d = ImageDraw.Draw(m)
    d.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=255, width=int(w * S))
    r = w * S / 2.0
    for p in (a, b):
        d.ellipse([p[0] * S - r, p[1] * S - r, p[0] * S + r, p[1] * S + r], fill=255)
    return m


def mask_circle(c, r):
    m = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(m).ellipse(
        [(c[0] - r) * S, (c[1] - r) * S, (c[0] + r) * S, (c[1] + r) * S], fill=255)
    return m


def mask_rect(x0, y0, x1, y1, radius=0):
    m = Image.new("L", (PX, PX), 0)
    d = ImageDraw.Draw(m)
    box = [x0 * S, y0 * S, x1 * S, y1 * S]
    if radius > 0:
        d.rounded_rectangle(box, radius=radius * S, fill=255)
    else:
        d.rectangle(box, fill=255)
    return m


def grad_v(top, bottom, y0, y1):
    """竖直渐变图（只在 y0..y1 之间过渡）。"""
    img = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    y0, y1 = int(y0 * S), int(y1 * S)
    span = max(1, y1 - y0)
    for y in range(y0, y1):
        t = (y - y0) / span
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (PX, y)], fill=c)
    return img


def outline_px(width_px):
    """把「描边像素宽度」换算成侵蚀核尺寸（超采样下必须是奇数）。"""
    k = int(width_px * S) | 1
    return max(3, k)


def paste_layer(canvas, mask, fill, ink_w=2.0):
    """先按 mask 外扩的描边涂黑，再把内形（腐蚀 ink_w）填色。"""
    k = outline_px(ink_w)
    inner = mask.filter(ImageFilter.MinFilter(k))
    canvas.paste(Image.new("RGBA", (PX, PX), INK), (0, 0), mask)
    if isinstance(fill, Image.Image):
        canvas.paste(fill, (0, 0), inner)
    else:
        canvas.paste(Image.new("RGBA", (PX, PX), fill), (0, 0), inner)
    return canvas


def main():
    canvas = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))

    # ---- 剑身（尖头 + 直刃）
    blade = mask_poly([(64, 12), (71.5, 32), (71.5, 76), (56.5, 76), (56.5, 32)])
    paste_layer(canvas, blade, grad_v(BLADE_HI, BLADE_LO, 12, 76), ink_w=2.2)

    # ---- 刃中凹槽（蓝，两侧留出钢色）
    fuller = mask_rect(62.3, 31, 65.7, 72, radius=1.8)
    paste_layer(canvas, fuller, grad_v(FULLER, (52, 92, 156, 255), 31, 72), ink_w=1.3)

    # ---- 刃上高光（左侧一道窄亮线，不描边）
    hl = mask_poly([(58.8, 33), (60.4, 33), (60.4, 73), (58.8, 73)])
    canvas.paste(Image.new("RGBA", (PX, PX), (255, 255, 255, 190)), (0, 0), hl)

    # ---- 护手：横条 + 两端上翘的翼
    guard = mask_rect(31, 76, 97, 87, radius=4.5)
    wing_l = mask_poly([(31.5, 76), (23.5, 81.5), (31.5, 87)])
    wing_r = mask_poly([(96.5, 76), (104.5, 81.5), (96.5, 87)])
    for m in (guard, wing_l, wing_r):
        paste_layer(canvas, m, grad_v(GUARD_HI, GUARD_LO, 76, 88), ink_w=2.0)

    # ---- 握柄（蓝 + 斜向缠绳纹）
    grip = mask_rect(58.5, 87, 69.5, 110, radius=2.8)
    paste_layer(canvas, grip, grad_v(GRIP_HI, GRIP_LO, 87, 110), ink_w=2.0)
    for gy in (93, 99, 105):
        wrap = mask_round_line((58.8, gy), (69.2, gy + 2.4), 1.5)
        canvas.paste(Image.new("RGBA", (PX, PX), (22, 38, 78, 235)), (0, 0), wrap)

    # ---- 柄头
    pommel = mask_circle((64, 113), 6.4)
    paste_layer(canvas, pommel, grad_v(GUARD_HI, GUARD_LO, 107, 120), ink_w=2.0)

    # ---- 护手宝石（青，一点高光）
    gem = mask_circle((64, 81.5), 3.6)
    paste_layer(canvas, gem, grad_v(GEM, (40, 132, 168, 255), 78, 86), ink_w=1.4)
    spark = mask_circle((62.8, 80.2), 1.2)
    canvas.paste(Image.new("RGBA", (PX, PX), (240, 252, 255, 235)), (0, 0), spark)

    out = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("wrote", os.path.normpath(OUT), out.size, out.mode)


if __name__ == "__main__":
    main()
