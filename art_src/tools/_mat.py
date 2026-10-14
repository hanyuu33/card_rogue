# -*- coding: utf-8 -*-
# 第三轮：抠透明 / 赫菲斯托斯卡图裁到游戏内卡图窗精确比例 1.1125（63/(76*0.745)）并去水印 / CG 去水印 / 头部标记 64x64。
from PIL import Image, ImageDraw
import os

BASE = r"D:\work\gen_raw"
F = {
    "forest_cg": "Japanese_anime_style_illustrat_2026-10-14T02-32-16.png",
    "forest_standing": "Japanese_anime_style_illustrat_2026-10-14T02-30-05.png",
    "forest_head": "head_only_icon_of_the_same_ani_2026-10-14T02-32-54.png",
    "hephaestus_card": "Japanese_anime_style_illustrat_2026-10-14T02-33-37.png",
    "hephaestus_standing": "Japanese_anime_style_illustrat_2026-10-14T02-30-58.png",
}
CARD_RATIO = 63.0 / (76.0 * 0.745)   # 游戏内卡图窗真实宽高比 ≈ 1.1125

def largest_label(fg, sw, sh):
    lab = [[0]*sw for _ in range(sh)]; cur = 0; sizes = {}
    for y in range(sh):
        for x in range(sw):
            if fg[y][x] and lab[y][x] == 0:
                cur += 1; cnt = 0; st = [(x, y)]; lab[y][x] = cur
                while st:
                    cx, cy = st.pop(); cnt += 1
                    for nx, ny in ((cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1)):
                        if 0 <= nx < sw and 0 <= ny < sh and fg[ny][nx] and lab[ny][nx] == 0:
                            lab[ny][nx] = cur; st.append((nx, ny))
                sizes[cur] = cnt
    big = max(sizes, key=sizes.get) if sizes else 0
    return lab, big

def mat(src, dst, thresh=40):
    im = Image.open(src).convert("RGB"); w, h = im.size
    work = im.copy(); MARK = (255, 0, 255)
    for seed in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]:
        if work.getpixel(seed) != MARK:
            ImageDraw.floodfill(work, seed, MARK, thresh=thresh)
    px = work.load(); ds = 4; sw, sh = max(1, w//ds), max(1, h//ds)
    fg = [[False]*sw for _ in range(sh)]
    for y in range(sh):
        for x in range(sw):
            found = False
            for yy in range(y*ds, min((y+1)*ds, h)):
                for xx in range(x*ds, min((x+1)*ds, w)):
                    if px[xx, yy] != MARK:
                        found = True; break
                if found: break
            fg[y][x] = found
    lab, big = largest_label(fg, sw, sh)
    srcpx = im.load(); out = Image.new("RGBA", (w, h), (0,0,0,0)); opx = out.load()
    for y in range(h):
        ly = min(y//ds, sh-1)
        for x in range(w):
            if px[x, y] != MARK and lab[ly][min(x//ds, sw-1)] == big:
                opx[x, y] = srcpx[x, y] + (255,)
    bbox = out.getbbox()
    if bbox: out = out.crop(bbox)
    out.save(dst); return out.size

def dewm(im, frac=0.045):
    w, h = im.size
    return im.crop((0, 0, w, int(h*(1.0-frac))))

def to_ratio(im, ratio):
    w, h = im.size; cur = w/h
    if cur < ratio:
        nh = int(w/ratio); y0 = (h-nh)//2; return im.crop((0, y0, w, y0+nh))
    nw = int(h*ratio); x0 = (w-nw)//2; return im.crop((x0, 0, x0+nw, h))

print("forest_standing", mat(os.path.join(BASE,F["forest_standing"]), os.path.join(BASE,"forest_standing_t.png")))
print("forest_head", mat(os.path.join(BASE,F["forest_head"]), os.path.join(BASE,"forest_head_t.png")))
print("heph_standing", mat(os.path.join(BASE,F["hephaestus_standing"]), os.path.join(BASE,"hephaestus_standing_t.png")))

# 赫菲斯托斯卡图：去水印 → 裁到游戏内精确比例 1.1125
card = dewm(Image.open(os.path.join(BASE,F["hephaestus_card"])).convert("RGB"))
card = to_ratio(card, CARD_RATIO)
card.save(os.path.join(BASE,"hephaestus_card.png"))
print("heph_card", card.size, "ratio=%.4f" % (card.size[0]/card.size[1]))

# 森林 CG：去水印（保持竖版插画）
cg = dewm(Image.open(os.path.join(BASE,F["forest_cg"])).convert("RGB"))
cg.save(os.path.join(BASE,"forest_cg.png")); print("forest_cg", cg.size)

# 头部标记 64x64 图标
ic = Image.open(os.path.join(BASE,"forest_head_t.png")).convert("RGBA")
ic.thumbnail((int(64*0.92), int(64*0.92)), Image.LANCZOS)
cv = Image.new("RGBA",(64,64),(0,0,0,0)); cv.paste(ic,((64-ic.width)//2,(64-ic.height)//2),ic)
cv.save(os.path.join(BASE,"forest_head_icon64.png")); print("icon64 done")
print("ALL DONE")
