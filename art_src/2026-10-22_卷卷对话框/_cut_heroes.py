# -*- coding: utf-8 -*-
"""立绘（洋红底）抠图 + 名称牌粉边清理。覆盖 assets/ui/curtain_hero_*.png。"""
import os
from PIL import Image, ImageDraw

ROOT = r"E:/work/card_rogue"
SRC = os.path.join(ROOT, "art_src/2026-10-22_卷卷对话框")
UI = os.path.join(ROOT, "assets/ui")

HEROES = {
    "forest": "EXACT_SAME_CHARACTER_as_the_re_2026-10-22T07-54-13.png",
    "rogue": "EXACT_SAME_CHARACTER_as_the_re_2026-10-22T07-54-39.png",
    "mech": "EXACT_SAME_CHARACTER_as_the_re_2026-10-22T07-55-07.png",
}


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


def mat(src, dst, thresh=52, pink_clean=True, kill_rect=None):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    work = im.copy()
    MARK = (255, 0, 255)
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if work.getpixel(seed) != MARK:
            ImageDraw.floodfill(work, seed, MARK, thresh=thresh)
    if kill_rect is not None:
        # 右下角水印直接整块抹掉（它在洋红区里、颜色是灰白，抠不掉也留不得）
        x0, y0, x1, y1 = kill_rect
        ImageDraw.Draw(work).rectangle([x0, y0, min(x1, w - 1), min(y1, h - 1)], fill=MARK)
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
            if px[x, y] == MARK or lab[ly][min(x // ds, sw - 1)] != big:
                continue
            r, g, b = srcpx[x, y]
            if pink_clean and r > 175 and b > 175 and g < 130 and (r - g) > 70 and (b - g) > 70:
                continue          # 洋红溢色（含名称牌上的粉边）
            opx[x, y] = (r, g, b, 255)
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    out.save(dst)
    return out.size


# 1) 名称牌重抠（去掉右/下沿那圈粉边）
print("curtain_plate", mat(os.path.join(SRC, "FULL_BLEED_small_horizontal_na_2026-10-22T07-48-30.png"),
                          os.path.join(UI, "curtain_plate.png")))
# 2) 对话框重抠（同一套规则，粉边一起清）
print("curtain_box", mat(os.path.join(SRC, "FULL_BLEED_horizontal_dialogue_2026-10-22T07-47-57.png"),
                         os.path.join(UI, "curtain_box.png")))
# 3) 立绘
for key, fn in HEROES.items():
    sz = mat(os.path.join(SRC, fn), os.path.join(UI, "curtain_hero_%s.png" % key),
             kill_rect=(760, 1430, 1024, 1536))
    print("curtain_hero_%s" % key, sz)
print("DONE")
