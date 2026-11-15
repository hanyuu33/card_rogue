# -*- coding: utf-8 -*-
"""R752：把 AI 出的三张新工具图处理成 128x128 透明底图标。

口径沿用 R751 踩出来的三条（别退化）：
  ① **逐像素** `d = 255 - min(r,g,b)` → `a = d / EDGE`，半透明处做**反预乘去白**
     （只吃纯白的 flood fill 会在描边外侧留一圈灰雾，深色槽底上尤其明显）；
  ② 必须有 `d <= 3` 的下限 —— AI 的「白」常常不是 255，剩一丝 alpha 就会让
     bbox 撑满整图、主体缩成半个图标；
  ③ bbox 用 `alpha >= 8` 的掩膜取，不用 alpha > 0。

用法：python tools/_make_r752_icons.py
输出：assets/ui/trap_icon_7009/7010/7011.png + _preview/r752_icons/*.png 对比页
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_src", "r752_icons")
OUT_UI = os.path.join(ROOT, "assets", "ui")
OUT_PREV = os.path.join(ROOT, "_preview", "r752_icons")

# 原始图 -> 目标 id（快送鸭试用第二版：鸭子抱着纸箱）
JOBS = [
    ("Game_item_icon__single_object__2026-11-15T08-14-16.png", 7009),
    ("Game_item_icon__single_object__2026-11-15T08-15-07.png", 7010),
    ("Game_item_icon__single_object__2026-11-15T08-14-42.png", 7011),
]
EDGE = 22.0          # 白→透明的过渡宽度（像素级色差）
WHITE_FLOOR = 3      # d <= 这个值直接判为纯背景（R751 的坑）
ALPHA_MASK = 8       # bbox 用的 alpha 门槛
CANVAS = 128
PAD = 3
## 只保留「最大连通块」的那几张：神秘牌 7011 的四周散着一圈星屑，全是实心，
## 算进 bbox 会把牌身压小一圈；45px 下星屑也只读成噪点。野生牌 / 快送鸭的主体
## 本身就是一整块，留着星屑反而更好看，所以只对 7011 开。
KEEP_MAIN = {7011}


def cut_white(im):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            d = 255 - min(r, g, b)
            if d <= WHITE_FLOOR:
                px[x, y] = (r, g, b, 0)
                continue
            alpha = min(255.0, (d / EDGE) * 255.0)
            if alpha >= 254.0:
                px[x, y] = (r, g, b, 255)
                continue
            # 反预乘：把「白底混进去的那一份」扣掉，否则半透明边缘会发灰
            k = alpha / 255.0
            nr = int(max(0.0, min(255.0, (r - 255.0 * (1.0 - k)) / k)))
            ng = int(max(0.0, min(255.0, (g - 255.0 * (1.0 - k)) / k)))
            nb = int(max(0.0, min(255.0, (b - 255.0 * (1.0 - k)) / k)))
            px[x, y] = (nr, ng, nb, int(alpha))
    return im


def bbox_of(im):
    a = im.split()[3].point(lambda v: 255 if v >= ALPHA_MASK else 0)
    box = a.getbbox()
    return box


def keep_main_blob(im):
    """只留中心所在的连通块（4 邻接），其余像素 alpha 清零。"""
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    cx, cy = w // 2, h // 2
    if px[cx, cy][3] < ALPHA_MASK:
        # 中心恰好落在镂空里（牌面挖空的那种）——退回全图找第一个前景点
        found = None
        for y in range(0, h):
            for x in range(0, w):
                if px[x, y][3] >= ALPHA_MASK:
                    found = (x, y)
                    break
            if found:
                break
        if not found:
            return im
        cx, cy = found
    stack = [(cx, cy)]
    seen[cy * w + cx] = 1
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nx < 0 or ny < 0 or nx >= w or ny >= h:
                continue
            if seen[ny * w + nx]:
                continue
            if px[nx, ny][3] < ALPHA_MASK:
                continue
            seen[ny * w + nx] = 1
            stack.append((nx, ny))
    # 连通块之外：整块清零（连半透明的过渡像素一起清，免得留下孤立灰点）
    for y in range(h):
        row = y * w
        for x in range(w):
            if not seen[row + x]:
                r, g, b, _a = px[x, y]
                px[x, y] = (r, g, b, 0)
    return im


def fit(im, box, tall_target=0.96, wide_target=0.96):
    """裁 bbox → 等比缩放到画布内 → 居中。竖长主体按高度填满，方形按长边填满。"""
    crop = im.crop(box)
    inner = CANVAS - PAD * 2
    cw, ch = crop.size
    aspect = ch / float(cw)
    if aspect >= 1.15:
        # 竖长（牌）：按高度吃到 tall_target，宽度跟着走（不够宽就退回按宽度约束）
        scale = (inner * tall_target) / ch
        if cw * scale > inner:
            scale = inner / float(cw)
        # 竖长主体看起来偏瘦 → 横向补 10%，与旁边方形图标视觉重量对齐（R751）
        new_w = max(1, int(round(cw * scale * 1.10)))
        new_h = max(1, int(round(ch * scale)))
        new_w = min(new_w, inner)
    else:
        scale = (inner * wide_target) / ch
        if cw * scale > inner:
            scale = inner / float(cw)
        new_w = max(1, int(round(cw * scale)))
        new_h = max(1, int(round(ch * scale)))
    small = crop.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(small, ((CANVAS - new_w) // 2, (CANVAS - new_h) // 2), small)
    return canvas


def alpha_cov(im):
    a = im.split()[3]
    tot = sum(a.getdata())
    return tot / (255.0 * CANVAS * CANVAS)


def main():
    os.makedirs(OUT_PREV, exist_ok=True)
    made = []
    for name, tid in JOBS:
        src = os.path.join(SRC, name)
        im = Image.open(src)
        cut = cut_white(im)
        if tid in KEEP_MAIN:
            cut = keep_main_blob(cut)
        box = bbox_of(cut)
        if box is None:
            raise SystemExit("%s: 抠完没有前景，检查 WHITE_FLOOR / EDGE" % name)
        out = fit(cut, box)
        dst = os.path.join(OUT_UI, "trap_icon_%d.png" % tid)
        out.save(dst)
        made.append((tid, dst))
        print("%d  <- %s  bbox=%s  cov=%.3f  -> %s" % (
            tid, name, box, alpha_cov(out), os.path.relpath(dst, ROOT)))

    # 对比页：128 原尺寸 + 槽内实况 45px（深色底，最接近战斗里看到的样子）
    sheet = Image.new("RGB", (40 + len(made) * 150, 210), (26, 28, 33))
    for i, (_tid, p) in enumerate(made):
        ic = Image.open(p)
        sheet.paste(ic, (24 + i * 150, 24), ic)
        slot = Image.new("RGBA", (56, 56), (15, 18, 26, 255))
        s45 = ic.resize((45, 45), Image.LANCZOS)
        slot.paste(s45, (6, 6), s45)
        sheet.paste(slot.convert("RGB"), (24 + i * 150 + 36, 165))
    sheet.save(os.path.join(OUT_PREV, "r752_icons_128_45.png"))
    print("sheet ->", os.path.join(OUT_PREV, "r752_icons_128_45.png"))


main()
