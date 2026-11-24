# -*- coding: utf-8 -*-
"""调试：列出标题横幅里的深色连通块，确定主描边与分离的小鸭子。"""
import os
from collections import deque
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "release", "store", "quackill_title_en.png")


def main():
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    lum = im.convert("L").filter(ImageFilter.MaxFilter(3))
    px = lum.load()
    dark = bytearray(1 if px[x, y] < 150 else 0 for y in range(h) for x in range(w))
    seen = bytearray(w * h)
    comps = []
    for sy in range(h):
        for sx in range(w):
            si = sy * w + sx
            if seen[si] or not dark[si]:
                continue
            q = deque([si])
            seen[si] = 1
            n = 0
            minx = maxx = sx
            miny = maxy = sy
            while q:
                i = q.popleft()
                y, x = divmod(i, w)
                n += 1
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                if y < miny:
                    miny = y
                if y > maxy:
                    maxy = y
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
            if n >= 500:
                comps.append((n, minx, miny, maxx, maxy))
    comps.sort(reverse=True)
    for c in comps[:20]:
        print("dark area=%7d box=(%4d,%3d)-(%4d,%3d) size=%dx%d" % (
            c[0], c[1], c[2], c[3], c[4], c[3] - c[1] + 1, c[4] - c[2] + 1))

    rgb = im.load()
    warm = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            r, g, b = rgb[x, y]
            if r > 150 and r > b + 15 and g > b + 5 and r >= g - 10:
                warm[y * w + x] = 1
    seen = bytearray(w * h)
    comps = []
    for sy in range(h):
        for sx in range(w):
            si = sy * w + sx
            if seen[si] or not warm[si]:
                continue
            q = deque([si])
            seen[si] = 1
            n = 0
            minx = maxx = sx
            miny = maxy = sy
            while q:
                i = q.popleft()
                y, x = divmod(i, w)
                n += 1
                minx = min(minx, x)
                maxx = max(maxx, x)
                miny = min(miny, y)
                maxy = max(maxy, y)
                for dy in (-1, 0, 1):
                    yy = y + dy
                    if yy < 0 or yy >= h:
                        continue
                    for dx in (-1, 0, 1):
                        xx = x + dx
                        if xx < 0 or xx >= w:
                            continue
                        j = yy * w + xx
                        if not seen[j] and warm[j]:
                            seen[j] = 1
                            q.append(j)
            if n >= 500:
                comps.append((n, minx, miny, maxx, maxy))
    comps.sort(reverse=True)
    for c in comps[:30]:
        print("warm area=%7d box=(%4d,%3d)-(%4d,%3d) size=%dx%d" % (
            c[0], c[1], c[2], c[3], c[4], c[3] - c[1] + 1, c[4] - c[2] + 1))


if __name__ == "__main__":
    main()
