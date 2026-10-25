import os
from PIL import Image, ImageDraw

SRC = os.path.join("art_src", "2026-10-25_机械之心卡图")
RAW = os.path.join(SRC, "raw")
BASE = os.path.join(RAW, "Keep_the_pose__the_powered_arm_2026-10-25T02-38-49.png")
OUT = os.path.join(RAW, "91936_pupil_ring.png")

PUPILS = [(503, 112), (553, 112)]     # 两眼瞳孔中心（1024 尺度的实测坐标）
SS = 6                                # 超采样倍数，保证 1px 环不锯齿

im = Image.open(BASE).convert("RGB")
w, h = im.size
big = im.resize((w * SS, h * SS), Image.LANCZOS)
ov = Image.new("RGBA", big.size, (0, 0, 0, 0))
d = ImageDraw.Draw(ov)

CYAN = (120, 214, 208)
for (cx, cy) in PUPILS:
    bx, by = cx * SS, cy * SS
    # 极细外环：环本身就 1 物理像素宽（超采样下 1*SS）
    for (rr, alpha, wd) in ((3.3, 95, 0.7),):
        r = rr * SS
        d.ellipse([bx - r, by - r, bx + r, by + r],
                  outline=(CYAN[0], CYAN[1], CYAN[2], alpha), width=int(round(wd * SS)))

big = Image.alpha_composite(big.convert("RGBA"), ov).convert("RGB")
im2 = big.resize((w, h), Image.LANCZOS)
im2.save(OUT)
print("OK", OUT)

# ---- 448x403 卡图裁切 ----
W, H = 448, 403
c = im2.copy()
keep_h = int(round(h * 0.89))
c = c.crop((0, 0, w, keep_h))
target = W / H
cur = w / keep_h
if cur > target:
    nw = int(round(keep_h * target))
    x0 = (w - nw) // 2
    c = c.crop((x0, 0, x0 + nw, keep_h))
elif cur < target:
    nh = int(round(w / target))
    y0 = (keep_h - nh) // 2
    c = c.crop((0, y0, w, y0 + nh))
c = c.resize((W, H), Image.LANCZOS)
c.save(os.path.join(SRC, "裁切_赫卡同克瑞斯9136.png"))
print("OK card crop", c.size)
