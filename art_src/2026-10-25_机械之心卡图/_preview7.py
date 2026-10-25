import os
from PIL import Image, ImageDraw, ImageFont

SRC = os.path.join("art_src", "2026-10-25_机械之心卡图")
RAW = os.path.join(SRC, "raw")
W, H = 448, 403

PAIR = [
    ("纯人眼", "Keep_the_pose__the_powered_arm_2026-10-25T02-38-49.png"),
    ("纯人眼 + 瞳孔青环", "91936_pupil_ring.png"),
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
        span = keep_h - nh
        y0 = span // 2
        im = im.crop((0, y0, w, y0 + nh))
    return im.resize((W, H), Image.LANCZOS)


def font(size, bold=False):
    ps = [r"C:\Windows\Fonts\msyhbd.ttc", r"C:\Windows\Fonts\msyh.ttc"] if bold \
        else [r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\msyhbd.ttc"]
    for p in ps:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


EYE_BOX = (472, 88, 588, 138)     # 1024 原图眼部
PAD = 18
GAP = 16
CELL_W = 380
CELL_H = int(CELL_W * H / W)
CARD_W = 190
CARD_H = int(CARD_W * H / W)
SMALL_W = 104
SMALL_H = int(SMALL_W * H / W)
HEAD = 46
LAB = 26

colw = max(CELL_W, CARD_W + 12 + SMALL_W)
canvas_w = PAD * 2 + colw * 2 + GAP
eye_h = int((EYE_BOX[3] - EYE_BOX[1]) * CELL_W / (EYE_BOX[2] - EYE_BOX[0]))
canvas_h = HEAD + eye_h + LAB + CARD_H + LAB + SMALL_H + LAB + PAD

cv = Image.new("RGB", (canvas_w, canvas_h), (18, 20, 24))
d = ImageDraw.Draw(cv)
d.text((PAD, 12), "赫卡同克瑞斯：纯人眼 vs 瞳孔加青环（上=眼部放大，中=448 卡图，下=104 小卡）",
       font=font(19, True), fill=(240, 235, 220))

y = HEAD
for i, (name, fn) in enumerate(PAIR):
    p = os.path.join(RAW, fn)
    x = PAD + i * (colw + GAP)
    src = Image.open(p).convert("RGB")
    eye = src.crop(EYE_BOX).resize((CELL_W, eye_h), Image.LANCZOS)
    cv.paste(eye, (x, y))
    d.rectangle([x, y, x + CELL_W - 1, y + eye_h - 1], outline=(90, 96, 104))
    d.text((x + 2, y + eye_h + 3), name, font=font(17), fill=(226, 220, 205))

    yc = y + eye_h + LAB
    card = crop_card(p).resize((CARD_W, CARD_H), Image.LANCZOS)
    cv.paste(card, (x, yc))
    d.rectangle([x, yc, x + CARD_W - 1, yc + CARD_H - 1], outline=(80, 86, 94))
    small = crop_card(p).resize((SMALL_W, SMALL_H), Image.LANCZOS)
    cv.paste(small, (x + CARD_W + 12, yc + (CARD_H - SMALL_H) // 2))
    d.rectangle([x + CARD_W + 12, yc + (CARD_H - SMALL_H) // 2,
                 x + CARD_W + 12 + SMALL_W - 1, yc + (CARD_H - SMALL_H) // 2 + SMALL_H - 1],
                outline=(80, 86, 94))

out = os.path.join(SRC, "预览_赫卡同_瞳孔方案.png")
cv.save(out)
for i, (name, fn) in enumerate(PAIR):
    crop_card(os.path.join(RAW, fn)).save(os.path.join(SRC, "裁切_赫卡同克瑞斯9136_%s.png" % ("A" if i == 0 else "B")))
print("OK", out, cv.size)
