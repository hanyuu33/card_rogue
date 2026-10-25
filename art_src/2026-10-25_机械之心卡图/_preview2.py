import os
from PIL import Image, ImageDraw, ImageFont

SRC = os.path.join("art_src", "2026-10-25_机械之心卡图")
RAW = os.path.join(SRC, "raw")
W, H = 448, 403

# 第二批（按用户四条意见重画）
JOBS = [
    ("赫尔墨斯 9140（无外套 · 欧美脸）", "Japanese_anime_style_character_2026-10-25T02-13-36.png"),
    ("量产型赫尔墨斯（加宽加厚）", "Japanese_anime_style_mechanica_2026-10-25T02-14-24.png"),
    ("量产型俄倪厄（机械犬）", "Japanese_anime_style_mecha_cre_2026-10-25T02-11-35.png"),
    ("俄倪俄 9132（自然肤色 · 战斗架势）", "Japanese_anime_style_character_2026-10-25T02-15-05.png"),
]

# 改动前后
CMP = [
    ("赫尔墨斯", "Japanese_anime_style_character_2026-10-25T02-10-51.png",
     "Japanese_anime_style_character_2026-10-25T02-13-36.png"),
    ("运输车", "Japanese_anime_style_mechanica_2026-10-25T02-11-10.png",
     "Japanese_anime_style_mechanica_2026-10-25T02-14-24.png"),
    ("俄倪俄", "Keep_this_exact_illustration___2026-10-25T02-12-37.png",
     "Japanese_anime_style_character_2026-10-25T02-15-05.png"),
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
COL = 2
CELL_W = 420
CELL_H = int(CELL_W * H / W)
GAP = 14
LABEL_H = 28
HEAD = 44
SMALL_W = 104
SMALL_H = int(SMALL_W * H / W)
SMALL_HEAD = 32
CMP_W = 190
CMP_H = int(CMP_W * H / W)
CMP_HEAD = 34

rows = (len(JOBS) + COL - 1) // COL
canvas_w = PAD * 2 + COL * CELL_W + (COL - 1) * GAP
canvas_h = (HEAD + rows * (CELL_H + LABEL_H + GAP)
            + SMALL_HEAD + SMALL_H + GAP
            + CMP_HEAD + len(CMP) * (CMP_H + 22) + PAD * 2)

cv = Image.new("RGB", (canvas_w, canvas_h), (18, 20, 24))
d = ImageDraw.Draw(cv)
d.text((PAD, 12), "第一批修正版（按你的四条意见重画）", font=font(22, True), fill=(240, 235, 220))

cards = []
y = HEAD
for i, (name, fn) in enumerate(JOBS):
    im = crop_card(os.path.join(RAW, fn))
    big = im.resize((CELL_W, CELL_H), Image.LANCZOS)
    cx = PAD + (i % COL) * (CELL_W + GAP)
    cy = y + (i // COL) * (CELL_H + LABEL_H + GAP)
    cv.paste(big, (cx, cy))
    d.rectangle([cx, cy, cx + CELL_W - 1, cy + CELL_H - 1], outline=(90, 96, 104))
    d.text((cx + 2, cy + CELL_H + 4), name, font=font(16), fill=(226, 220, 205))
    cards.append(im)

sy = HEAD + rows * (CELL_H + LABEL_H + GAP)
d.text((PAD, sy), "小卡尺寸（≈104 宽，战斗中实际辨识度）", font=font(15), fill=(200, 195, 180))
sy += SMALL_HEAD
for i, im in enumerate(cards):
    small = im.resize((SMALL_W, SMALL_H), Image.LANCZOS)
    sx = PAD + i * (SMALL_W + 10)
    cv.paste(small, (sx, sy))
    d.rectangle([sx, sy, sx + SMALL_W - 1, sy + SMALL_H - 1], outline=(80, 86, 94))

cy2 = sy + SMALL_H + GAP
d.text((PAD, cy2), "改动前后（左 = 上一版，右 = 这一版）", font=font(16, True), fill=(220, 210, 190))
cy2 += CMP_HEAD
for name, old, new in CMP:
    x = PAD
    for label, fn in (("旧", old), ("新", new)):
        im = crop_card(os.path.join(RAW, fn)).resize((CMP_W, CMP_H), Image.LANCZOS)
        cv.paste(im, (x, cy2))
        d.rectangle([x, cy2, x + CMP_W - 1, cy2 + CMP_H - 1], outline=(80, 86, 94))
        d.text((x + 5, cy2 + 4), label, font=font(16, True),
               fill=(255, 210, 140) if label == "新" else (150, 150, 150))
        x += CMP_W + 8
    d.text((x + 4, cy2 + CMP_H // 2 - 10), name, font=font(17), fill=(215, 208, 190))
    cy2 += CMP_H + 22

out = os.path.join(SRC, "预览_第二批_修正.png")
cv.save(out)
for (name, fn), im in zip(JOBS, cards):
    im.save(os.path.join(SRC, "裁切_%s.png" % name.split("（")[0].strip()))
print("OK", out, cv.size)
