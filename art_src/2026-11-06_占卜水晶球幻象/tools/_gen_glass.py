# -*- coding: utf-8 -*-
"""玻璃质感层 v2：只留球壳内壁 + 高光斑 + 底部金色反射，压掉内部星云涡旋。"""
import os
from PIL import Image, ImageFilter, ImageChops

SRC = r"D:/work/card_rogue/assets/ui/bg_divination.png"
OUT_DIR = r"D:/work/card_rogue/art_src/2026-11-06_占卜水晶球幻象/processed"
os.makedirs(OUT_DIR, exist_ok=True)

CX, CY, R = 639.0, 188.0, 89.0
OUT = 256
PAD = 2

# 内部弱化：r < INNER 的像素只按 HILITE_MIN 以上保留
INNER = 0.70          # 占半径比例
INNER_KEEP = 0.10     # 内部非高光像素保留比例
HILITE_MIN = 48       # detail 值高于此视为「镜面高光」，内部也保留

im = Image.open(SRC).convert("RGB")
box = (int(CX - R - PAD), int(CY - R - PAD), int(CX + R + PAD), int(CY + R + PAD))
sq = im.crop(box).resize((OUT, OUT), Image.LANCZOS)

lum = sq.convert("L")
low = lum.filter(ImageFilter.GaussianBlur(radius=OUT * 0.16))
detail = ImageChops.subtract(lum, low, scale=1.0, offset=0)

dp = detail.load()
for y in range(OUT):
    for x in range(OUT):
        v = dp[x, y]
        v = 0 if v < 5 else min(255, int((v ** 0.8) * 1.3))
        dp[x, y] = v
detail = detail.filter(ImageFilter.GaussianBlur(radius=0.5))

r_out = OUT / 2.0 * 0.985
inner_r = r_out * INNER
mask = Image.new("L", (OUT, OUT), 0)
mp = mask.load()
dpx = detail.load()
cxo = cyo = OUT / 2.0

for y in range(OUT):
    yn = y / float(OUT)
    for x in range(OUT):
        d = ((x - cxo) ** 2 + (y - cyo) ** 2) ** 0.5
        if d >= r_out:
            continue
        a = 255.0
        edge = r_out * 0.95
        if d > edge:
            a = 255.0 * (r_out - d) / (r_out - edge)
        # 内部弱化（高光斑例外）
        if d < inner_r and dpx[x, y] < HILITE_MIN:
            a *= INNER_KEEP
        elif d < inner_r:
            a *= 0.92
        # 底部与金色底座交界淡出
        if yn > 0.74:
            a *= max(0.0, 1.0 - (yn - 0.74) / 0.26) ** 1.5
        mp[x, y] = int(a)

glass = Image.merge("RGB", (detail, detail, detail))
r, g, b = glass.split()
glass = Image.merge("RGB", (r.point(lambda v: int(v * 0.90)),
                            g.point(lambda v: int(v * 1.00)),
                            b.point(lambda v: int(v * 1.06))))

out = Image.new("RGBA", (OUT, OUT), (0, 0, 0, 0))
out.paste(glass, (0, 0))
out.putalpha(mask)
p = os.path.join(OUT_DIR, "div_orb_glass.png")
out.save(p)
print("saved", p)

# 预览：ADD 到中性灰蓝底上，近似 Godot 的加法混合观感
prev = Image.new("RGB", (OUT, OUT), (26, 30, 46))
gp = glass.load()
ap = mask.load()
pp = prev.load()
for y in range(OUT):
    for x in range(OUT):
        a = ap[x, y] / 255.0
        gv = gp[x, y]
        pp[x, y] = tuple(min(255, int(pp[x, y][i] + gv[i] * a)) for i in range(3))
prev.save(r"C:/Users/Administrator/AppData/Local/Temp/glass_preview2.png")
print("preview ok")
