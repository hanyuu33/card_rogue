# -*- coding: utf-8 -*-
"""R810：四件新道具图标 1024 → 128×128 真透明 PNG。

复用 R755 的 `cut()`（亮且不饱和 → 4-连通泛洪取背景 → bbox 居中 → 128）。
⚠️ **别给 `cut()` 传 `bright=`** —— 那是「成品亮度增强」的开关，不是背景阈值；
    传 190 会把整张图乘爆成纯白（R810 第一版踩过）。背景阈值只能走 `**bg_kw`，
    而那个参数恰好同名，所以这批一律用默认值（生成图底子是 254~255 的浅暖白，够用）。

太阳指环 6082 额外一步「填内孔」：戒指的圈内空腔是**被前景包围**的白色，
从四边泛洪永远走不进去 → 会留下一块白饼（深色道具栏上一眼就看出来）。
所以对这张单独做一次「从孔心种子泛洪白色 → alpha 归 0」。
"""
import sys

sys.path.insert(0, "E:/work/card_rogue/tools")
from PIL import Image, ImageDraw  # noqa: E402
from _make_r755_icons import cut, preview  # noqa: E402

RAW = "art_src/2026-11-19_四件道具图标_R810/raw/"
JOBS = [
    ("A_cute_hand_drawn_cartoon_game_2026-11-19T06-05-46.png", "assets/ui/relic_icon_6081.png"),
    ("A_cute_hand_drawn_cartoon_game_2026-11-19T06-06-02.png", "assets/ui/relic_icon_6082.png"),
    ("A_cute_hand_drawn_cartoon_game_2026-11-19T06-06-19.png", "assets/ui/relic_icon_6083.png"),
    ("A_cute_hand_drawn_cartoon_game_2026-11-19T06-07-04.png", "assets/ui/relic_icon_6084.png"),
]
HOLE_SEED = {6082: (512, 560)}   # 6082 的圈内空腔种子（1024 原图坐标）


def punch_hole(dst, seed):
    """把被前景包围的白色空腔挖成透明（只对需要的那几张调）。"""
    im = Image.open(dst).convert("RGBA")
    w, h = im.size
    scaled = (int(seed[0] * w / 1024.0), int(seed[1] * h / 1024.0))
    px = im.load()
    sx, sy = scaled
    if px[sx, sy][3] == 0:
        print("hole: 种子已经是透明的，跳过", dst)
        return
    # 先用「白且不饱和 且 不透明」标出空腔候选（金戒指本体饱和度高，不会被吃），
    # 再从孔心泛洪 → 只挖与孔心连通的那一片，不会误伤别处的白色高光。
    probe = Image.new("RGB", (w, h), (0, 0, 0))
    pp = probe.load()
    for y in range(h):
        for x in range(w):
            r0, g0, b0, a0 = px[x, y]
            if a0 > 0 and min(r0, g0, b0) >= 236 and (max(r0, g0, b0) - min(r0, g0, b0)) <= 14:
                pp[x, y] = (255, 255, 255)
    ImageDraw.floodfill(probe, scaled, (255, 0, 0), thresh=0)
    n = 0
    for y in range(h):
        for x in range(w):
            if pp[x, y] == (255, 0, 0):
                px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
                n += 1
    im.save(dst)
    print("hole punched:", dst, n, "px")


outs = []
for src, dst in JOBS:
    cut(RAW + src, dst, pad_pct=0.06)
    for rid, seed in HOLE_SEED.items():
        if dst.endswith("relic_icon_%d.png" % rid):
            punch_hole(dst, seed)
    outs.append(dst)

preview(outs, "art_src/2026-11-19_四件道具图标_R810/processed/_preview_128.png", scale=3)
