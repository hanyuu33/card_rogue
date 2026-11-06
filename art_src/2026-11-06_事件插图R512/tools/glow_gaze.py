import os
import shutil
from PIL import Image, ImageFilter, ImageChops, ImageDraw, ImageOps

SRC = r"D:/work/gen_raw/Flat_2D_game_illustration_in_n_2026-11-06T11-22-41.png"
DST = r"D:/work/card_rogue/assets/ui/event_gaze.png"
ARCH_RAW = r"D:/work/card_rogue/art_src/2026-11-06_事件插图R512/raw/event_gaze_发光版_原图.png"
ARCH_TOOL = r"D:/work/card_rogue/art_src/2026-11-06_事件插图R512/tools/glow_gaze.py"

im = Image.open(SRC).convert("RGB")
W, H = im.size
print("src", im.size)

# --- 1) 找右下角水印左边界 ---
g = ImageOps.grayscale(im)
px = g.load()
wm_x = W
for y in range(840, H):
    for x in range(1180, W):
        if px[x, y] > 92:
            if x < wm_x:
                wm_x = x
print("watermark left x =", wm_x)

# --- 2) 裁 4:3，避开右下角水印 ---
cw = min(1365, wm_x - 12)
ch = int(cw * 3 / 4)
if ch > H:
    ch = H
    cw = int(ch * 4 / 3)
top = 0
box = (0, top, cw, top + ch)
print("crop", box)
c = im.crop(box)

# 缩到 2 倍插槽 = 640x480
TW, TH = 640, 480
c = c.resize((TW, TH), Image.LANCZOS)
assert c.size == (TW, TH)
print("resized", c.size)

# --- 3) 压黑暗部：只留光，不要细节 ---
L = ImageOps.grayscale(c)


def body_curve(v):
    # 0..25 归零，其余平滑抬升；15 以下彻底黑掉，去掉"看得清的羽毛/脸"
    t = (v - 18) / 237.0
    if t <= 0:
        return 0
    return int(min(255, 255 * (t ** 1.22)))


Lc = L.point(lambda v: body_curve(v))
Lc_rgb = Image.merge("RGB", (Lc, Lc, Lc))
c = ImageChops.multiply(c, Lc_rgb)

# --- 4) 光渗（两层 bloom，screen 叠加） ---
g1 = c.filter(ImageFilter.GaussianBlur(9))
g2 = c.filter(ImageFilter.GaussianBlur(24))
g3 = c.filter(ImageFilter.GaussianBlur(52))
c = ImageChops.screen(c, ImageChops.multiply(g1, Image.new("RGB", c.size, (150, 150, 150))))
c = ImageChops.screen(c, ImageChops.multiply(g2, Image.new("RGB", c.size, (110, 110, 110))))
c = ImageChops.screen(c, ImageChops.multiply(g3, Image.new("RGB", c.size, (58, 58, 58))))

# --- 5) 核心推到近白（发光体，不是眼球） ---
L2 = ImageOps.grayscale(c)
hot = L2.point(lambda v: 0 if v < 196 else int(min(255, (v - 196) / 59.0 * 196)))
hot = hot.filter(ImageFilter.GaussianBlur(3))
c.paste(Image.new("RGB", c.size, (255, 247, 228)), (0, 0), hot)

# --- 6) 外圈紫红光晕（溢出到黑暗里，营造"光在散"） ---
halo = c.filter(ImageFilter.GaussianBlur(46))
halo = ImageChops.multiply(halo, Image.new("RGB", c.size, (96, 22, 46)))
c = ImageChops.screen(c, halo)

# --- 7) 暗角：四角彻底黑 ---
vig = Image.new("L", (TW, TH), 0)
d = ImageDraw.Draw(vig)
pad_x, pad_y = int(TW * 0.02), int(TH * 0.02)
d.ellipse((-TW * 0.10, -TH * 0.14, TW * 1.10, TH * 1.16), fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(int(TW * 0.075)))
vig_rgb = Image.merge("RGB", (vig, vig, vig))
c = ImageChops.multiply(c, vig_rgb)

# --- 8) alpha：边缘羽化，融进事件页黑底 ---
out = c.convert("RGBA")
a = Image.new("L", (TW, TH), 0)
da = ImageDraw.Draw(a)
px_, py_ = int(TW * 0.10), int(TH * 0.10)
da.rectangle((px_, py_, TW - px_, TH - py_), fill=255)
a = a.filter(ImageFilter.GaussianBlur(int(min(TW, TH) * 0.075)))
out.putalpha(a)

out.save(DST, optimize=True)
print("saved", DST, os.path.getsize(DST) // 1024, "KB")

os.makedirs(os.path.dirname(ARCH_RAW), exist_ok=True)
shutil.copyfile(SRC, ARCH_RAW)
shutil.copyfile(DST, r"D:/work/card_rogue/art_src/2026-11-06_事件插图R512/processed/event_gaze.png")
os.makedirs(os.path.dirname(ARCH_TOOL), exist_ok=True)
shutil.copyfile(os.path.abspath(__file__), ARCH_TOOL)
print("archived")
