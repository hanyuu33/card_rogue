import os
from PIL import Image, ImageDraw, ImageFont

SRC = os.path.join("art_src", "2026-10-25_机械之心卡图")
RAW = os.path.join(SRC, "raw")
W, H = 448, 403

JOBS = [
    ("① 初版（冷静复仇）", "Keep_the_EXACT_same_cute_chibi_2026-10-25T03-10-30.png"),
    ("② 站桩怒吼", "Keep_the_EXACT_same_cute_chibi_2026-10-25T03-13-43.png"),
    ("③ 前倾咆哮（推荐）", "Same_chibi_duck_character__cha_2026-10-25T03-14-10.png"),
]
FACE = [("② 站桩怒吼", JOBS[1][1]), ("③ 前倾咆哮", JOBS[2][1])]
FACE_BOX = (340, 180, 780, 500)


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


PAD = 20
COL = 3
CELL_W = 340
CELL_H = int(CELL_W * H / W)
GAP = 16
LAB = 28
HEAD = 44
SMALL_W = 104
SMALL_H = int(SMALL_W * H / W)
SMALL_HEAD = 30
FACE_W = 460
FACE_H = int(FACE_W * (FACE_BOX[3] - FACE_BOX[1]) / (FACE_BOX[2] - FACE_BOX[0]))
FACE_HEAD = 34

canvas_w = PAD * 2 + COL * CELL_W + (COL - 1) * GAP
canvas_h = (HEAD + CELL_H + LAB + SMALL_HEAD + SMALL_H + GAP
            + FACE_HEAD + FACE_H + LAB + PAD)

cv = Image.new("RGB", (canvas_w, canvas_h), (18, 20, 24))
d = ImageDraw.Draw(cv)
d.text((PAD, 12), "恶魔鸭（复仇）：愤怒三版", font=font(21, True), fill=(240, 235, 220))

cards = []
y = HEAD
for i, (name, fn) in enumerate(JOBS):
    p = os.path.join(RAW, fn)
    im = crop_card(p)
    big = im.resize((CELL_W, CELL_H), Image.LANCZOS)
    cx = PAD + (i % COL) * (CELL_W + GAP)
    cv.paste(big, (cx, y))
    d.rectangle([cx, y, cx + CELL_W - 1, y + CELL_H - 1], outline=(90, 96, 104))
    d.text((cx + 2, y + CELL_H + 3), name, font=font(15), fill=(226, 220, 205))
    cards.append(im)

sy = y + CELL_H + LAB
d.text((PAD, sy), "小卡尺寸", font=font(14), fill=(200, 195, 180))
sy += SMALL_HEAD
for i, im in enumerate(cards):
    small = im.resize((SMALL_W, SMALL_H), Image.LANCZOS)
    sx = PAD + i * (SMALL_W + 12)
    cv.paste(small, (sx, sy))
    d.rectangle([sx, sy, sx + SMALL_W - 1, sy + SMALL_H - 1], outline=(80, 86, 94))

fy = sy + SMALL_H + GAP
d.text((PAD, fy), "脸部特写：愤怒表达对比", font=font(16, True), fill=(220, 210, 190))
fy += FACE_HEAD
for i, (name, fn) in enumerate(FACE):
    src = Image.open(os.path.join(RAW, fn)).convert("RGB")
    face = src.crop(FACE_BOX).resize((FACE_W, FACE_H), Image.LANCZOS)
    fx = PAD + i * (FACE_W + GAP)
    cv.paste(face, (fx, fy))
    d.rectangle([fx, fy, fx + FACE_W - 1, fy + FACE_H - 1], outline=(90, 96, 104))
    d.text((fx + 2, fy + FACE_H + 3), name, font=font(15), fill=(226, 220, 205))

out = os.path.join(SRC, "预览_复仇鸭_愤怒三版.png")
cv.save(out)
for (name, fn), im in zip(JOBS, cards):
    tag = name.split("（")[0].strip("①②③ ")
    im.save(os.path.join(SRC, "裁切_9118恶魔鸭复仇_%s.png" % tag))
print("OK", out, cv.size)
