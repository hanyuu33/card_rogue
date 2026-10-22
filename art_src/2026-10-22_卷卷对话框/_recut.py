# -*- coding: utf-8 -*-
"""重抠 UI 素材：加强洋红溢色清理（原来的阈值漏掉了粉边）。
规则：洋红量 d = min(r,b) - g
  d >= 96        → 直接透明（纯洋红底）
  40 <= d < 96   → 半透明边缘（按 d 衰减），并把 g 抬到 min(r,b)-10 去溢色
  其它           → 原样保留
"""
import os
from PIL import Image, ImageDraw

ROOT = r"E:/work/card_rogue"
SRC = os.path.join(ROOT, "art_src/2026-10-22_卷卷对话框")
UI = os.path.join(ROOT, "assets/ui")

JOBS = [
    ("FULL_BLEED_horizontal_dialogue_2026-10-22T07-47-57.png", "curtain_box.png", None),
    ("FULL_BLEED_small_horizontal_na_2026-10-22T07-48-30.png", "curtain_plate.png", None),
    ("EXACT_SAME_CHARACTER_as_the_re_2026-10-22T07-54-13.png", "curtain_hero_forest.png",
     (760, 1430, 1024, 1536)),
    ("EXACT_SAME_CHARACTER_as_the_re_2026-10-22T07-54-39.png", "curtain_hero_rogue.png",
     (760, 1430, 1024, 1536)),
    ("EXACT_SAME_CHARACTER_as_the_re_2026-10-22T07-55-07.png", "curtain_hero_mech.png",
     (760, 1430, 1024, 1536)),
]

TARGET = {
    "curtain_box.png": ("w", 1300),
    "curtain_plate.png": ("w", 520),
    "curtain_hero_forest.png": ("h", 760),
    "curtain_hero_rogue.png": ("h", 760),
    "curtain_hero_mech.png": ("h", 760),
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


def mat(src, dst, kill_rect=None, aggressive=False, trim_bottom=0.0):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    work = im.copy()
    MARK = (255, 0, 255)
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if work.getpixel(seed) != MARK:
            ImageDraw.floodfill(work, seed, MARK, thresh=52)
    if kill_rect is not None:
        x0, y0, x1, y1 = kill_rect
        ImageDraw.Draw(work).rectangle([x0, y0, min(x1, w - 1), min(y1, h - 1)], fill=MARK)

    px = work.load()
    src_px = im.load()
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

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        ly = min(y // ds, sh - 1)
        for x in range(w):
            if px[x, y] == MARK or lab[ly][min(x // ds, sw - 1)] != big:
                continue
            r, g, b = src_px[x, y]
            m = min(r, b)
            d = m - g
            if aggressive:
                # UI 素材（对话框 / 名称牌）本身没有紫色内容 → 洋红系可以放心全清：
                # 差值大的直接透明（底 + 投影），差值小的把绿拉平（残留的紫边变纸灰）
                if d > 62:
                    continue
                if d > 3:
                    opx[x, y] = (r, min(255, m - 6), b, 255)
                    continue
            if abs(r - b) < 34 and g < min(r, b) * 0.74 and m < 205:
                continue                    # 洋红底上的**投影/暗边**（紫红一坨，不是纸面）
            if d >= 128:
                continue                    # 纯洋红底 / 水印区
            if d >= 6:
                # 去溢色：洋红分量来自背景混色 —— 把绿抬回到 min(r,b) 附近，
                # 粉边就变成接近纸白的边缘，而不是一圈品红。alpha 只在最后一档收口。
                g2 = min(255, m - 4)
                a = 255 if d < 110 else int(255 * (1.0 - (d - 110) / 18.0))
                opx[x, y] = (r, g2, b, max(0, min(255, a)))
            else:
                opx[x, y] = (r, g, b, 255)

    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    if dst in ("curtain_box.png", "curtain_plate.png"):
        # 左右两端同样有 1~2px 的紫色投影，一起裁掉（撕边仍保留主体形状）
        sx = int(out.width * 0.012)
        out = out.crop((sx, 0, out.width - sx, out.height))
    if trim_bottom > 0.0:
        # 素材底边那条「洋红上画的投影」会被抠成暗紫红，洗不掉又不该留 ——
        # 直接沿底边裁掉一窄条（撕边造型不受影响）。
        out = out.crop((0, 0, out.width, max(1, int(out.height * (1.0 - trim_bottom)))))
    mode, val = TARGET.get(dst, ("", 0))
    if mode == "w" and out.width > val:
        out = out.resize((val, int(out.height * val / out.width)), Image.LANCZOS)
    elif mode == "h" and out.height > val:
        out = out.resize((int(out.width * val / out.height), val), Image.LANCZOS)
    out.save(os.path.join(UI, dst), optimize=True)
    return out.size, os.path.getsize(os.path.join(UI, dst)) // 1024


TRIM = {"curtain_box.png": 0.055, "curtain_plate.png": 0.10}
for src, dst, kill in JOBS:
    aggr = dst in ("curtain_box.png", "curtain_plate.png")
    print(dst, *mat(os.path.join(SRC, src), dst, kill, aggr, TRIM.get(dst, 0.0)))
print("DONE")
