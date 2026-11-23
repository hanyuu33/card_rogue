# -*- coding: utf-8 -*-
"""把商店标题横幅抠成透明 PNG。

思路：标题连续深棕描边是图中最大的深色连通块，先锁定它（排除银杏、
房屋和栅栏），再把被描边包围的内部填成前景；外扩 2px 保住金色细边，
最后只对最外 1px 做轻微柔化。不会把天空、云或树叶带进结果。
"""
import os
from collections import deque
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "release", "store", "quackill_title_en.png")
OUT = os.path.join(ROOT, "release", "store", "quackill_title_en_alpha.png")
EDGE_DARK = (88, 47, 19)
EDGE_GOLD = (205, 151, 59)
CLOSE_KERNEL = 3


def _flood_unselected(mask, w, h):
    """返回从画布边缘可达的非前景区域。"""
    outside = bytearray(w * h)
    q = deque()

    def seed(i):
        if not mask[i] and not outside[i]:
            outside[i] = 1
            q.append(i)

    for x in range(w):
        seed(x)
        seed((h - 1) * w + x)
    for y in range(h):
        seed(y * w)
        seed(y * w + w - 1)
    while q:
        i = q.popleft()
        y, x = divmod(i, w)
        if x > 0:
            j = i - 1
            if not mask[j] and not outside[j]:
                outside[j] = 1
                q.append(j)
        if x + 1 < w:
            j = i + 1
            if not mask[j] and not outside[j]:
                outside[j] = 1
                q.append(j)
        if y > 0:
            j = i - w
            if not mask[j] and not outside[j]:
                outside[j] = 1
                q.append(j)
        if y + 1 < h:
            j = i + w
            if not mask[j] and not outside[j]:
                outside[j] = 1
                q.append(j)
    return outside


def _largest_dark_component(im):
    w, h = im.size
    lum = im.convert("L").filter(ImageFilter.MaxFilter(CLOSE_KERNEL))
    lp = lum.load()
    dark = bytearray(1 if lp[x, y] < 150 else 0 for y in range(h) for x in range(w))
    seen = bytearray(w * h)
    best = None
    for sy in range(h):
        for sx in range(w):
            si = sy * w + sx
            if seen[si] or not dark[si]:
                continue
            q = deque([si])
            seen[si] = 1
            pix = []
            while q:
                i = q.popleft()
                pix.append(i)
                y, x = divmod(i, w)
                for dy in (-1, 0, 1):
                    yy = y + dy
                    if yy < 0 or yy >= h:
                        continue
                    for dx in (-1, 0, 1):
                        xx = x + dx
                        if xx < 0 or xx >= w:
                            continue
                        j = yy * w + xx
                        if not seen[j] and dark[j]:
                            seen[j] = 1
                            q.append(j)
            if best is None or len(pix) > len(best):
                best = pix
    if not best:
        raise SystemExit("no dark title outline found")
    mask = bytearray(w * h)
    for i in best:
        mask[i] = 1
    return mask


def main():
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    lum = im.convert("L")
    mask = _largest_dark_component(im)
    outside = _flood_unselected(mask, w, h)
    # 被外轮廓包围的区域全部属于标题（棕阴影、奶油字面、鸭头和鸭掌）。
    for i in range(w * h):
        if not outside[i]:
            mask[i] = 1
    # 末尾 L 的奶油字面与小鸭、鸭掌有少量开口没被描边围住；
    # 只在收窄后的局部按奶油/橙色补回，绿色树叶和蓝天不满足条件。
    rgb = im.load()
    for x0, y0, x1, y1, kind in (
            (1370, 160, 1645, 500, "cream"),
            (1440, 30, 1720, 210, "duck"),
            (1550, 360, 1720, 490, "foot")):
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, b = rgb[x, y]
                hit = False
                if kind == "foot":
                    hit = r > 180 and g > 90 and b < 150 and r > g + 45
                elif kind == "duck":
                    hit = ((r > 170 and g > 130 and b > 80 and r > g + 2)
                           or lum.getpixel((x, y)) < 150)
                else:
                    hit = r > 170 and g > 120 and b > 60 and r > g + 4 and g > b + 3
                if hit:
                    mask[y * w + x] = 1
    # 去掉云边、飞叶等孤立小岛，只保留标题主体和完整小鸭。
    seen = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            si = sy * w + sx
            if seen[si] or not mask[si]:
                continue
            q = deque([si])
            seen[si] = 1
            comp = []
            while q:
                i = q.popleft()
                comp.append(i)
                y, x = divmod(i, w)
                for dy in (-1, 0, 1):
                    yy = y + dy
                    if yy < 0 or yy >= h:
                        continue
                    for dx in (-1, 0, 1):
                        xx = x + dx
                        if xx < 0 or xx >= w:
                            continue
                        j = yy * w + xx
                        if not seen[j] and mask[j]:
                            seen[j] = 1
                            q.append(j)
            if len(comp) < 2000:
                for i in comp:
                    mask[i] = 0
    # 外扩 2px 保住深棕描边外侧的暖金细边。
    alpha = Image.frombytes("L", (w, h), bytes(255 if v else 0 for v in mask))
    alpha = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(0.55))
    bbox = alpha.getbbox()
    if not bbox:
        raise SystemExit("empty alpha")
    pad = 6
    crop = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
            min(w, bbox[2] + pad), min(h, bbox[3] + pad))
    im = im.crop(crop)
    alpha = alpha.crop(crop)
    out = im.convert("RGBA")
    ap = alpha.load()
    op = out.load()
    ow, oh = out.size
    # 外缘 2px 改回深棕/暖金，去掉原背景带来的浅蓝天光白边。
    core1 = alpha.filter(ImageFilter.MinFilter(3)).load()
    core2 = alpha.filter(ImageFilter.MinFilter(5)).load()
    for y in range(oh):
        for x in range(ow):
            a = ap[x, y]
            if a == 0:
                continue
            if core1[x, y] == 0:
                op[x, y] = EDGE_DARK + (a,)
            elif core2[x, y] == 0:
                op[x, y] = EDGE_GOLD + (a,)
    out.putalpha(alpha)
    out.save(OUT, optimize=True)
    print("%s  %dx%d  bbox=%s  crop=%s" % (OUT, out.width, out.height, bbox, crop))


if __name__ == "__main__":
    main()
