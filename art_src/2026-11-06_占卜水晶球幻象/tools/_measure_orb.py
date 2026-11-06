# -*- coding: utf-8 -*-
"""定位 bg_divination.png 里水晶球的圆心与半径（纯 PIL，无 numpy）。"""
from PIL import Image, ImageDraw

SRC = r"D:/work/card_rogue/assets/ui/bg_divination.png"
im = Image.open(SRC).convert("RGB")
W, H = im.size
data = im.tobytes()
print("size", W, H)

cx_lo, cx_hi = int(W * 0.25), int(W * 0.75)
y_lo, y_hi = 0, int(H * 0.55)

rows = {}
pts = []
for y in range(y_lo, y_hi):
    base = y * W * 3
    xs = []
    for x in range(cx_lo, cx_hi):
        i = base + x * 3
        r, g, b = data[i], data[i + 1], data[i + 2]
        lum = (r * 299 + g * 587 + b * 114) // 1000
        if lum > 150 and b > 140 and g > 140:
            xs.append(x)
    if xs:
        rows[y] = (min(xs), max(xs))
        pts.append((y, min(xs), max(xs)))

print("rows with bright px:", len(rows))
if pts:
    print("y range", pts[0][0], "..", pts[-1][0])
    top = pts[0]
    bot = pts[-1]
    print("top row  y=%d  x=%d..%d" % top)
    print("bot row  y=%d  x=%d..%d" % bot)

best = max(rows.items(), key=lambda kv: kv[1][1] - kv[1][0])
y0, (x1, x2) = best
wid = x2 - x1
cx = (x1 + x2) / 2.0
print("widest row y=%d  x=%d..%d  width=%d" % (y0, x1, x2, wid))

# 竖向：沿 cx 扫，找亮的上下界
col_ys = []
cxi = int(round(cx))
for y in range(y_lo, y_hi):
    i = y * W * 3 + cxi * 3
    r, g, b = data[i], data[i + 1], data[i + 2]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    if lum > 150 and b > 140 and g > 140:
        col_ys.append(y)
print("column x=%d  bright y=%s..%s" % (cxi, col_ys[0] if col_ys else None, col_ys[-1] if col_ys else None))

# 逐行 width 剖面（每 10 行）
print("--- profile ---")
for y in sorted(rows)[::10]:
    lo, hi = rows[y]
    print("  y=%3d  %4d..%4d  w=%3d" % (y, lo, hi, hi - lo))

dbg = im.copy()
d = ImageDraw.Draw(dbg)
for y in sorted(rows)[::1]:
    lo, hi = rows[y]
d.line([x1, y0, x2, y0], fill=(0, 255, 0), width=3)
d.line([cx, max(0, y0 - 220), cx, min(H - 1, y0 + 220)], fill=(255, 255, 0), width=2)
d.ellipse([cx - wid / 2, y0 - wid / 2, cx + wid / 2, y0 + wid / 2], outline=(255, 0, 0), width=3)
dbg.save(r"C:/Users/Administrator/AppData/Local/Temp/orb_measure.png")
print("cx=%.1f cy=%d r=%.1f" % (cx, y0, wid / 2.0))
