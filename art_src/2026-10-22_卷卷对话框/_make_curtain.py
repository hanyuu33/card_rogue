# -*- coding: utf-8 -*-
"""R310 卷卷事件素材：① 对话框/名称牌洋红抠图；② 三职业立绘（从 class_cg 裁切羽化）。
产出：
  assets/ui/curtain_box.png    羊皮纸对话框（透明底，中心留白）
  assets/ui/curtain_plate.png  名称牌（透明底）
  assets/ui/curtain_hero_<key>.png  职业立绘（柔边）
"""
import os
from PIL import Image, ImageDraw

ROOT = r"E:/work/card_rogue"
SRC = os.path.join(ROOT, "art_src/2026-10-22_卷卷对话框")
UI = os.path.join(ROOT, "assets/ui")


def largest_label(fg, sw, sh):
    lab = [[0] * sw for _ in range(sh)]
    cur = 0
    sizes = {}
    for y in range(sh):
        for x in range(sw):
            if fg[y][x] and lab[y][x] == 0:
                cur += 1
                cnt = 0
                st = [(x, y)]
                lab[y][x] = cur
                while st:
                    cx, cy = st.pop()
                    cnt += 1
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < sw and 0 <= ny < sh and fg[ny][nx] and lab[ny][nx] == 0:
                            lab[ny][nx] = cur
                            st.append((nx, ny))
                sizes[cur] = cnt
    big = max(sizes, key=sizes.get) if sizes else 0
    return lab, big


def mat(src, dst, thresh=52):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    work = im.copy()
    MARK = (255, 0, 255)
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if work.getpixel(seed) != MARK:
            ImageDraw.floodfill(work, seed, MARK, thresh=thresh)
    px = work.load()
    ds = 4
    sw, sh = max(1, w // ds), max(1, h // ds)
    fg = [[False] * sw for _ in range(sh)]
    for y in range(sh):
        for x in range(sw):
            found = False
            for yy in range(y * ds, min((y + 1) * ds, h)):
                for xx in range(x * ds, min((x + 1) * ds, w)):
                    if px[xx, yy] != MARK:
                        found = True
                        break
                if found:
                    break
            fg[y][x] = found
    lab, big = largest_label(fg, sw, sh)
    srcpx = im.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        ly = min(y // ds, sh - 1)
        for x in range(w):
            if px[x, y] != MARK and lab[ly][min(x // ds, sw - 1)] == big:
                opx[x, y] = srcpx[x, y] + (255,)
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    out.save(dst)
    return out.size


box = mat(os.path.join(SRC, "FULL_BLEED_horizontal_dialogue_2026-10-22T07-47-57.png"),
          os.path.join(UI, "curtain_box.png"))
print("curtain_box", box, "ratio=%.2f" % (box[0] / box[1]))
plate = mat(os.path.join(SRC, "FULL_BLEED_small_horizontal_na_2026-10-22T07-48-30.png"),
            os.path.join(UI, "curtain_plate.png"))
print("curtain_plate", plate, "ratio=%.2f" % (plate[0] / plate[1]))

# ── 职业立绘：从 class_cg 裁角色区 → 左/右/上三边羽化 → 缩放 ──
CROPS = {
    "forest": (500, 0, 900, 676),
    "rogue": (600, 0, 1060, 676),
    "mech": (740, 0, 1280, 680),
}
FEATHER_SIDE = 84
FEATHER_TOP = 44


def feather(im, side=FEATHER_SIDE, top=FEATHER_TOP):
    w, h = im.size
    mask = Image.new("L", (w, h), 255)
    d = ImageDraw.Draw(mask)
    for i in range(side):
        v = int(255 * (i / float(side)) ** 1.35)
        d.line([(i, 0), (i, h)], fill=v)
        d.line([(w - 1 - i, 0), (w - 1 - i, h)], fill=v)
    for i in range(top):
        v = int(255 * (i / float(top)) ** 1.2)
        d.line([(0, i), (w, i)], fill=v)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


for key, box_ in CROPS.items():
    src = Image.open(os.path.join(UI, "class_cg_%s.png" % key)).convert("RGB")
    cut = src.crop(box_)
    cut = feather(cut)
    nh = 660
    nw = int(round(cut.width * nh / float(cut.height)))
    cut = cut.resize((nw, nh), Image.LANCZOS)
    dst = os.path.join(UI, "curtain_hero_%s.png" % key)
    cut.save(dst)
    print("curtain_hero_%s" % key, cut.size)
print("DONE")
