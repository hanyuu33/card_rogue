import os
import math
from PIL import Image, ImageFilter, ImageChops

OUT = r"D:/work/gen_raw/_gaze_v17.png"
PREV = r"D:/work/gen_raw/_gaze_v17_onpaper.png"
SMALL = r"D:/work/gen_raw/_gaze_v17_half.png"
TW, TH = 640, 480

# (cx, cy, 半宽, 半高, 相位, 上眼睑压暗, 瞳倾角)
EYES = [
    (196.0, 212.0, 92.0, 81.0, 0.00, 0.62, -0.055),
    (445.0, 216.0, 94.0, 82.0, 1.95, 0.44, 0.040),
]
PUP_H = 0.80
PUP_W = 0.150

STOPS = [
    (0.000, (0, 0, 0)),
    (0.030, (30, 4, 10)),
    (0.090, (78, 10, 22)),
    (0.180, (140, 22, 32)),
    (0.300, (196, 52, 40)),
    (0.450, (236, 98, 52)),
    (0.600, (255, 156, 84)),
    (0.760, (255, 206, 142)),
    (0.890, (255, 240, 204)),
    (1.000, (255, 254, 248)),
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


def smooth(e0, e1, x):
    k = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return k * k * (3 - 2 * k)


def pupil_mask(dx, dyt):
    t = abs(dyt) / PUP_H
    if t >= 1.0:
        return 0.0
    hw = PUP_W * math.sqrt(max(0.0, 1.0 - t * t))
    if hw <= 1e-4:
        return 0.0
    return 1.0 - smooth(0.70, 1.05, abs(dx) / hw)


img = Image.new("RGB", (TW, TH), (0, 0, 0))
px = img.load()
pupil = Image.new("L", (TW, TH), 0)
pp = pupil.load()

for y in range(TH):
    for x in range(TW):
        acc = 0.0
        pm = 0.0
        for (cx, cy, ea, eb, ph, lidk, slope) in EYES:
            dx = (x - cx) / ea
            dy = (y - cy) / eb
            r = math.hypot(dx, dy)
            if r > 2.6:
                continue
            th = math.atan2(dy, dx)
            base = math.exp(-2.75 * (r ** 1.50))
            wob = 1.0 + 0.075 * math.sin(3.1 * th + ph) * min(1.0, r) \
                      + 0.042 * math.sin(5.7 * th + 0.6 * ph) * min(1.0, r)
            I = base * wob
            I *= 1.0 - 0.28 * smooth(0.70, 0.99, r) * (1.0 - smooth(1.02, 1.30, r))  # 角膜缘暗环
            I *= 1.0 - lidk * smooth(0.22, 0.98, -dy)                                  # 上眼睑压暗
            I *= 1.0 + 0.07 * max(0.0, -dy)                                            # 上部略亮
            m = pupil_mask(dx, dy + slope * dx)
            I *= (1.0 - 0.95 * m)
            if m > pm:
                pm = m
            if I > acc:
                acc = I
        if acc > 0.002:
            px[x, y] = tuple(int(c) for c in colormap(min(1.0, acc)))
        pp[x, y] = int(pm * 255)

g1 = img.filter(ImageFilter.GaussianBlur(7))
img = ImageChops.screen(img, ImageChops.multiply(g1, Image.new("RGB", (TW, TH), (108, 108, 108))))
g2 = img.filter(ImageFilter.GaussianBlur(22))
img = ImageChops.screen(img, ImageChops.multiply(g2, Image.new("RGB", (TW, TH), (54, 54, 54))))

pupil = pupil.filter(ImageFilter.GaussianBlur(3))
img = Image.composite(Image.new("RGB", (TW, TH), (9, 2, 6)), img,
                      pupil.point(lambda v: int(v * 0.94)))

# 瞳缝边缘绕射暖光
rim = Image.new("L", (TW, TH), 0)
rp = rim.load()
for (cx, cy, ea, eb, ph, lidk, slope) in EYES:
    for y in range(max(0, int(cy - 75)), min(TH, int(cy + 75))):
        for x in range(max(0, int(cx - 32)), min(TW, int(cx + 32))):
            dx = (x - cx) / ea
            dy = (y - cy) / eb
            dyt = dy + slope * dx
            t = abs(dyt) / PUP_H
            if t >= 1.0:
                continue
            hw = PUP_W * math.sqrt(max(0.0, 1.0 - t * t))
            if hw <= 1e-4:
                continue
            q = abs(dx) / hw
            v = smooth(0.90, 1.08, q) * (1.0 - smooth(1.08, 1.45, q))
            if v > 0:
                rp[x, y] = max(rp[x, y], int(min(255, v * 140)))
rim = rim.filter(ImageFilter.GaussianBlur(4))
img = ImageChops.screen(img, ImageChops.multiply(
    Image.merge("RGB", (rim, rim, rim)), Image.new("RGB", (TW, TH), (255, 174, 92))))

# 中心刺眼点
hot = Image.new("L", (TW, TH), 0)
hp = hot.load()
for (cx, cy, ea, eb, ph, lidk, slope) in EYES:
    for y in range(max(0, int(cy - 42)), min(TH, int(cy + 42))):
        for x in range(max(0, int(cx - 48)), min(TW, int(cx + 48))):
            ox = cx + (0.22 * ea if cx < 320 else -0.22 * ea)
            r2 = math.hypot((x - ox) / (ea * 0.30), (y - cy + eb * 0.10) / (eb * 0.30))
            v = max(0.0, 1.0 - r2)
            if v > 0:
                hp[x, y] = max(hp[x, y], int(min(255, v ** 1.7 * 235)))
hot = hot.filter(ImageFilter.GaussianBlur(6))
img.paste(Image.new("RGB", (TW, TH), (255, 250, 232)), (0, 0), hot)

mask = Image.new("L", (TW, TH), 0)
mp = mask.load()
CX, CY, A, B = 320.0, 216.0, 302.0, 230.0
for y in range(TH):
    for x in range(TW):
        rr = math.hypot((x - CX) / A, (y - CY) / B)
        mp[x, y] = int(255 * (1.0 - smooth(0.50, 1.02, rr)))
mask = mask.filter(ImageFilter.GaussianBlur(16))

out = img.convert("RGBA")
out.putalpha(mask)
out.save(OUT, optimize=True)

paper = Image.new("RGB", (TW, TH), (243, 237, 225))
paper.paste(out, (0, 0), out)
paper.save(PREV)
paper.resize((320, 240), Image.LANCZOS).save(SMALL)
print("saved", OUT, os.path.getsize(OUT) // 1024, "KB")
