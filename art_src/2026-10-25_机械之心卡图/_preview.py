import os
from PIL import Image, ImageDraw, ImageFont

SRC = os.path.join("art_src", "2026-10-25_机械之心卡图")
RAW = os.path.join(SRC, "raw")
W, H = 448, 403

JOBS = [
    ("赫尔墨斯 9140", "Japanese_anime_style_character_2026-10-25T02-10-51.png"),
    ("量产型赫尔墨斯（运输车）", "Japanese_anime_style_mechanica_2026-10-25T02-11-10.png"),
    ("量产型俄倪厄（机械犬）", "Japanese_anime_style_mecha_cre_2026-10-25T02-11-35.png"),
    ("俄倪俄 A（机械臂版）", "Japanese_anime_style_character_2026-10-25T02-11-54.png"),
    ("俄倪俄 B（人类手臂）", "Japanese_anime_style_character_2026-10-25T02-12-14.png"),
    ("俄倪俄 C（B+发光眼）", "Keep_this_exact_illustration___2026-10-25T02-12-37.png"),
]


def crop_card(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    keep_h = int(round(h * 0.89))          # 切底部水印
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


def font(size):
    for p in [r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\msyhbd.ttc",
              r"C:\Windows\Fonts\simhei.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


COL = 3
CELL_W = 340
CELL_H = int(CELL_W * H / W)
GAP = 16
LABEL_H = 30
HEAD = 46
SMALL_W = 104
SMALL_H = int(SMALL_W * H / W)
SMALL_HEAD = 34
PAD = 20

rows = (len(JOBS) + COL - 1) // COL
canvas_w = PAD * 2 + COL * CELL_W + (COL - 1) * GAP
canvas_h = HEAD + rows * (CELL_H + LABEL_H + GAP) + SMALL_HEAD + SMALL_H + PAD * 2 + 10

bg = (18, 20, 24)
cv = Image.new("RGB", (canvas_w, canvas_h), bg)
d = ImageDraw.Draw(cv)
f_head = font(22)
f_cell = font(17)
f_tag = font(15)

d.text((PAD, 14), "R372 机械之心卡图 第一批候选（448×403 裁切后）", font=f_head, fill=(240, 235, 220))

cards = []
y = HEAD
for i, (name, fn) in enumerate(JOBS):
    p = os.path.join(RAW, fn)
    im = crop_card(p)
    big = im.resize((CELL_W, CELL_H), Image.LANCZOS)
    cx = PAD + (i % COL) * (CELL_W + GAP)
    cy = y + (i // COL) * (CELL_H + LABEL_H + GAP)
    cv.paste(big, (cx, cy))
    d.rectangle([cx, cy, cx + CELL_W - 1, cy + CELL_H - 1], outline=(90, 96, 104))
    d.text((cx + 2, cy + CELL_H + 4), name, font=f_cell, fill=(226, 220, 205))
    cards.append(im)

# 小卡实感（≈100×110 在卡面上的大小）
sy = HEAD + rows * (CELL_H + LABEL_H + GAP) + 4
d.text((PAD, sy), "小卡尺寸（≈104 宽，战斗中实际辨识度）", font=font(16), fill=(200, 195, 180))
sy += SMALL_HEAD
for i, im in enumerate(cards):
    small = im.resize((SMALL_W, SMALL_H), Image.LANCZOS)
    sx = PAD + i * (SMALL_W + 10)
    cv.paste(small, (sx, sy))
    d.rectangle([sx, sy, sx + SMALL_W - 1, sy + SMALL_H - 1], outline=(80, 86, 94))

out = os.path.join(SRC, "预览_第一批.png")
cv.save(out)
for (name, fn), im in zip(JOBS, cards):
    safe = name.split("（")[0].strip()
    im.save(os.path.join(SRC, "裁切_%s.png" % safe))
print("OK", out, cv.size)
