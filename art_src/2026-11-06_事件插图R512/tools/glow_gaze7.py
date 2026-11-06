import os
from PIL import Image, ImageFilter, ImageChops, ImageDraw, ImageOps

BASE = r"D:/work/gen_raw/_gaze_base640.png"
OUT = r"D:/work/gen_raw/_gaze_v7.png"
PREV = r"D:/work/gen_raw/_gaze_v7_preview.png"
PREV2 = r"D:/work/gen_raw/_gaze_v7_half.png"
TW, TH = 640, 480

STOPS = [
    (0.00, (0, 0, 0)),
    (0.06, (40, 5, 12)),
    (0.18, (132, 18, 30)),
    (0.34, (206, 58, 40)),
    (0.52, (248, 126, 56)),
    (0.68, (255, 192, 116)),
    (0.84, (255, 240, 208)),
    (1.00, (255, 254, 248)),
]


def lerp(a, b, t):
    return a + (b - a) * t


def colormap(t):
    if t <= 0:
        return STOPS[0][1]
    for i in range(len(STOPS) - 1):
        t0, c0 = STOPS[i]
        t1, c1 = STOPS[i + 1]
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            return (lerp(c0[0], c1[0], k), lerp(c0[1], c1[1], k), lerp(c0[2], c1[2], k))
    return STOPS[-1][1]


base = Image.open(BASE).convert("RGB")
L = ImageOps.grayscale(base)
Lf = L.filter(ImageFilter.GaussianBlur(6))
LP = Lf.load()

canvas = Image.new("RGB", (TW, TH), (0, 0, 0))
cp = canvas.load()
hot = Image.new("L", (TW, TH), 0)
hp = hot.load()
for y in range(TH):
    for x in range(TW):
        v = LP[x, y] / 255.0
        t = (v ** 2.25) * 1.12
        if t < 0.026:
            continue
        t = min(1.0, t)
        cp[x, y] = tuple(int(c) for c in colormap(t))
        if t > 0.74:
            hp[x, y] = int(min(255, (t - 0.74) / 0.26 * 255))

# 白热核心稍微过曝，形成"刺眼"的中心
hot = hot.filter(ImageFilter.GaussianBlur(4))
canvas.paste(Image.new("RGB", (TW, TH), (255, 251, 238)), (0, 0), hot.point(lambda v: int(v * 0.55)))

# 三层光渗
h1 = canvas.filter(ImageFilter.GaussianBlur(7))
h2 = canvas.filter(ImageFilter.GaussianBlur(20))
h3 = canvas.filter(ImageFilter.GaussianBlur(52))
canvas = ImageChops.screen(canvas, ImageChops.multiply(h1, Image.new("RGB", (TW, TH), (140, 140, 140))))
canvas = ImageChops.screen(canvas, ImageChops.multiply(h2, Image.new("RGB", (TW, TH), (96, 96, 96))))
canvas = ImageChops.screen(canvas, ImageChops.multiply(h3, Image.new("RGB", (TW, TH), (48, 48, 48))))

# 紫红环境光
amb = canvas.filter(ImageFilter.GaussianBlur(80))
amb = ImageChops.multiply(amb, Image.new("RGB", (TW, TH), (108, 42, 66)))
canvas = ImageChops.screen(canvas, amb)

# 暗角
vig = Image.new("L", (TW, TH), 0)
d = ImageDraw.Draw(vig)
d.ellipse((-TW * 0.20, -TH * 0.24, TW * 1.20, TH * 1.26), fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(56))
canvas = ImageChops.multiply(canvas, Image.merge("RGB", (vig, vig, vig)))

out = canvas.convert("RGBA")
al = Image.new("L", (TW, TH), 0)
da = ImageDraw.Draw(al)
da.ellipse((-TW * 0.06, -TH * 0.08, TW * 1.06, TH * 1.10), fill=255)
al = al.filter(ImageFilter.GaussianBlur(64))
out.putalpha(al)
out.save(OUT, optimize=True)

bgc = Image.new("RGB", (TW, TH), (13, 13, 15))
bgc.paste(out, (0, 0), out)
bgc.save(PREV)
bgc.resize((320, 240), Image.LANCZOS).save(PREV2)
print("saved", OUT, os.path.getsize(OUT) // 1024, "KB")
