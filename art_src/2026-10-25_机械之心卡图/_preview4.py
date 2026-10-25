import os
from PIL import Image, ImageDraw, ImageFont

SRC = os.path.join("art_src", "2026-10-25_机械之心卡图")
RAW = os.path.join(SRC, "raw")
W, H = 448, 403

JOBS = [
    ("A 修理工版（工装·扳手）", "Japanese_anime_style_character_2026-10-25T02-21-50.png"),
    ("B 医师版（白袍·浅底）", "Modern_Japanese_anime_style_ch_2026-10-25T02-22-11.png"),
    ("C 医师版（白袍·深底统一）", "Keep_the_character_exactly_as__2026-10-25T02-22-34.png"),
]


def crop_card(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    keep_h = int(round(h * 0.89))
    im = im.crop((0, 0, w, keep_h))
    target = W / H
    cur = w / keep_h
    if cur > target:
        nw = int(round(keep_h * target))
        x0 = (w - nw) // 2
        im = im.crop((x0, 0, x0 + nw, keep_h))
    elif cur < target:
        nh = int(round(w / target))
        y0 = (keep_h - nh) // 2
        im = im.crop((0, y0, w, y0 + nh))
    return im.resize((W, H), Image.LANCZOS)


def font(size, bold=False):
    ps = [r"C:\Windows\Fonts\msyhbd.ttc", r"C:\Windows\Fonts\msyh.ttc"] if bold \
        else [r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\msyhbd.ttc"]
    for p in ps:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


PAD = 20
COL = 3
CELL_W = 340
CELL_H = int(CELL_W * H / W)
GAP = 16
LABEL_H = 28
HEAD = 44
SMALL_W = 104
SMALL_H = int(SMALL_W * H / W)
SMALL_HEAD = 32

rows = (len(JOBS) + COL - 1) // COL
canvas_w = PAD * 2 + COL * CELL_W + (COL - 1) * GAP
canvas_h = HEAD + rows * (CELL_H + LABEL_H + GAP) + SMALL_HEAD + SMALL_H + PAD * 2

cv = Image.new("RGB", (canvas_w, canvas_h), (18, 20, 24))
d = ImageDraw.Draw(cv)
d.text((PAD, 12), "阿斯克勒庇厄斯 9141 候选（修理工装扮 · 医生气质）", font=font(21, True),
       fill=(240, 235, 220))

cards = []
y = HEAD
for i, (name, fn) in enumerate(JOBS):
    im = crop_card(os.path.join(RAW, fn))
    big = im.resize((CELL_W, CELL_H), Image.LANCZOS)
    cx = PAD + (i % COL) * (CELL_W + GAP)
    cy = y + (i // COL) * (CELL_H + LABEL_H + GAP)
    cv.paste(big, (cx, cy))
    d.rectangle([cx, cy, cx + CELL_W - 1, cy + CELL_H - 1], outline=(90, 96, 104))
    d.text((cx + 2, cy + CELL_H + 4), name, font=font(15), fill=(226, 220, 205))
    cards.append(im)

sy = HEAD + rows * (CELL_H + LABEL_H + GAP)
d.text((PAD, sy), "小卡尺寸（≈104 宽，战斗中实际辨识度）", font=font(15), fill=(200, 195, 180))
sy += SMALL_HEAD
for i, im in enumerate(cards):
    small = im.resize((SMALL_W, SMALL_H), Image.LANCZOS)
    sx = PAD + i * (SMALL_W + 12)
    cv.paste(small, (sx, sy))
    d.rectangle([sx, sy, sx + SMALL_W - 1, sy + SMALL_H - 1], outline=(80, 86, 94))

out = os.path.join(SRC, "预览_阿斯克勒庇厄斯.png")
cv.save(out)
for (name, fn), im in zip(JOBS, cards):
    im.save(os.path.join(SRC, "裁切_%(n)s.png" % {"n": name.split("（")[0].strip()}))
print("OK", out, cv.size)
