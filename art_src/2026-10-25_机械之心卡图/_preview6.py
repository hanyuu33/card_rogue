import os
from PIL import Image, ImageDraw, ImageFont

SRC = os.path.join("art_src", "2026-10-25_机械之心卡图")
RAW = os.path.join(SRC, "raw")
W, H = 448, 403

VARIANTS = [
    ("A 原版（发光盘·不像人）", "Modern_Japanese_anime_style_ch_2026-10-25T02-34-28.png"),
    ("B 纯人眼（无科技感）", "Keep_everything_identical__sam_2026-10-25T02-36-10.png"),
    ("C 人眼 + 青虹膜（推荐）", "Keep_everything_identical__sam_2026-10-25T02-36-33.png"),
]

FACE_BOX = (330, 0, 700, 300)      # 1024 尺度下的头部区域


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
FACE_W = 340
FACE_H = 260
CARD_W = 170
CARD_H = int(CARD_W * H / W)
GAP = 16
LABEL_H = 28
HEAD = 44

canvas_w = PAD * 2 + COL * FACE_W + (COL - 1) * GAP
canvas_h = HEAD + FACE_H + LABEL_H + CARD_H + 40 + PAD

cv = Image.new("RGB", (canvas_w, canvas_h), (18, 20, 24))
d = ImageDraw.Draw(cv)
d.text((PAD, 12), "只有眼睛不同（脸部 2× 放大）", font=font(21, True), fill=(240, 235, 220))

y = HEAD
for i, (name, fn) in enumerate(VARIANTS):
    p = os.path.join(RAW, fn)
    im = Image.open(p).convert("RGB")
    face = im.crop(FACE_BOX).resize((FACE_W, FACE_H), Image.LANCZOS)
    cx = PAD + i * (FACE_W + GAP)
    cv.paste(face, (cx, y))
    d.rectangle([cx, y, cx + FACE_W - 1, y + FACE_H - 1], outline=(90, 96, 104))
    d.text((cx + 2, y + FACE_H + 4), name, font=font(15), fill=(226, 220, 205))
    card = crop_card(p).resize((CARD_W, CARD_H), Image.LANCZOS)
    cy = y + FACE_H + LABEL_H + 6
    cv.paste(card, (cx, cy))
    d.rectangle([cx, cy, cx + CARD_W - 1, cy + CARD_H - 1], outline=(80, 86, 94))

out = os.path.join(SRC, "预览_赫卡同_眼睛三版.png")
cv.save(out)
print("OK", out, cv.size)
