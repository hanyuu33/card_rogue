# -*- coding: utf-8 -*-
"""R758：生成「常数测量员」的计量特效贴图 assets/fx/fx_survey_beam.png（256x256 RGBA）。

视觉：金色**刻度环**（环 + 均匀刻度 + 中央准星 + 辉光）。与土元素（土黄石块）、
火元素（橙红火团）同尺寸同用法，battle_scene 的 `_primal_fx` 按 source 选这张图。
"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 256
C = S / 2.0
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

GOLD = (255, 210, 120)
GOLD_HI = (255, 240, 200)
AMBER = (240, 170, 60)


def ring(r, w, col, a):
    d.ellipse([C - r, C - r, C + r, C + r], outline=col + (a,), width=w)


# ① 外环（双线）
ring(98, 3, AMBER, 150)
ring(90, 2, GOLD, 210)

# ② 刻度：48 条，每 4 条一个长刻度
for i in range(48):
    ang = math.radians(i * 360.0 / 48.0)
    long_tick = (i % 4 == 0)
    r0 = 78.0 if long_tick else 82.0
    r1 = 90.0
    x0, y0 = C + math.cos(ang) * r0, C + math.sin(ang) * r0
    x1, y1 = C + math.cos(ang) * r1, C + math.sin(ang) * r1
    d.line([x0, y0, x1, y1], fill=GOLD_HI + (230 if long_tick else 150,),
           width=3 if long_tick else 2)

# ③ 内环虚线（24 段，留 1/3 空隙）
for i in range(24):
    a0 = i * 15.0 - 4.0
    a1 = i * 15.0 + 8.0
    d.arc([C - 58, C - 58, C + 58, C + 58], a0, a1, fill=GOLD + (170,), width=2)

# ④ 中央准星：四根短线 + 中心小圆
for ang in (0, 90, 180, 270):
    rad = math.radians(ang)
    d.line([C + math.cos(rad) * 16, C + math.sin(rad) * 16,
            C + math.cos(rad) * 40, C + math.sin(rad) * 40],
           fill=GOLD_HI + (200,), width=2)
d.ellipse([C - 10, C - 10, C + 10, C + 10], outline=GOLD_HI + (220,), width=2)

# ⑤ 中心辉光（径向渐变，白 → 金 → 透明）
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for i in range(46, 0, -1):
    t = i / 46.0
    a = int(120 * (1.0 - t) ** 2.2)
    r = 46 * t
    gd.ellipse([C - r, C - r, C + r, C + r],
               fill=(int(255 - 20 * t), int(225 - 40 * t), int(150 - 60 * t), a))

# ⑥ 整体外发光：把已有线条复制一份模糊后垫在底下
blur = img.filter(ImageFilter.GaussianBlur(6))
out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
out = Image.alpha_composite(out, blur)
out = Image.alpha_composite(out, glow)
out = Image.alpha_composite(out, img)
out.save("e:/work/card_rogue/assets/fx/fx_survey_beam.png")
print("wrote assets/fx/fx_survey_beam.png", out.size)
