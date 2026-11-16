#!/usr/bin/env python3
"""英文状态词素材后处理：黑底抠透明 -> 连通域去水印 -> 统一大小 -> 重命名。

图生图产物带右下角「AI生成 / WORKBUDDY」小水印。英文单词字母之间有空隙，连通域会
拆成多个独立字母，所以**不能只取最大连通域**，要把「所有非水印连通域」合并（水印在
右下角、主体字母在中心，按 bbox 位置区分）。

输入：assets/fx/status_words_en/ 下图生图长文件名（黑底 + 英文艺术字）
输出：assets/fx/status_words_en/<标准名>.png（透明背景，字高 750、四周 15px）
"""
import os
import glob
from PIL import Image

SRC = "assets/fx/status_words_en"
TARGET_H = 750
PAD = 15
LO, HI = 0.055, 0.28

# 英文词 -> 输出文件名 -> 文件名匹配片段（图生图文件名会截断，Frozen 截成 Froze）
MAPPING = [
    ("Frozen", "frozen", "Froze"),
    ("Burn", "burn", "Burn"),
    ("Poison", "poison", "Poison"),
    ("Shock", "shock", "Shock"),
    ("Barrier", "barrier", "Barrier"),
    ("Heal", "heal", "Heal"),
    ("Power", "power", "Power"),
    ("Death", "death", "Death"),
    ("Energy", "energy", "Energy"),
    ("Stun", "stun", "Stun"),
    ("Taunt", "taunt", "Taunt"),
]


def matte(im):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            mx = max(r, g, b) / 255.0
            if mx >= HI:
                na = 255
            elif mx > LO:
                na = int(round((mx - LO) / (HI - LO) * 255))
            else:
                na = 0
            px[x, y] = (r, g, b, na)
    return im


def word_bbox(im):
    """合并所有非水印连通域，返回原图坐标 bbox。"""
    w, h = im.size
    sw, sh = w // 2, h // 2
    spx = im.load()

    # 降采样 alpha mask
    small = Image.new("L", (sw, sh), 0)
    opx = small.load()
    for y in range(sh):
        for x in range(sw):
            hit = False
            for dx in (0, 1):
                for dy in (0, 1):
                    nx, ny = x * 2 + dx, y * 2 + dy
                    if nx < w and ny < h and spx[nx, ny][3] > 0:
                        hit = True
                        break
                if hit:
                    break
            if hit:
                opx[x, y] = 1

    # BFS 找连通域，记录每个的 bbox（降采样坐标）
    visited = bytearray(sw * sh)
    comps = []
    for sy in range(sh):
        for sx in range(sw):
            idx = sy * sw + sx
            if visited[idx] or not opx[sx, sy]:
                continue
            stack = [(sx, sy)]
            visited[idx] = 1
            minx = maxx = sx
            miny = maxy = sy
            while stack:
                cx, cy = stack.pop()
                if cx < minx:
                    minx = cx
                if cx > maxx:
                    maxx = cx
                if cy < miny:
                    miny = cy
                if cy > maxy:
                    maxy = cy
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < sw and 0 <= ny < sh:
                        nidx = ny * sw + nx
                        if not visited[nidx] and opx[nx, ny]:
                            visited[nidx] = 1
                            stack.append((nx, ny))
            comps.append((minx, miny, maxx, maxy))

    # 排除水印：降采样 bbox 左上角在右下角（x0 > 0.75*sw 且 y0 > 0.75*sh）
    main = [c for c in comps if not (c[0] > 0.75 * sw and c[1] > 0.75 * sh)]
    if not main:
        return im.getbbox()

    minx = min(c[0] for c in main)
    miny = min(c[1] for c in main)
    maxx = max(c[2] for c in main)
    maxy = max(c[3] for c in main)
    return (minx * 2, miny * 2, maxx * 2 + 1, maxy * 2 + 1)


def unify(im, bbox):
    l, t, r, b = bbox
    l = max(0, l)
    t = max(0, t)
    r = min(im.width, r)
    b = min(im.height, b)
    if r - l < 2 or b - t < 2:
        return im
    crop = im.crop((l, t, r, b))
    w, h = crop.size
    nh = TARGET_H
    nw = max(1, round(w * TARGET_H / h))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (nw + PAD * 2, nh + PAD * 2), (0, 0, 0, 0))
    out.paste(crop, (PAD, PAD))
    return out


def pick_latest(frag):
    """找包含匹配片段的最新原始图（排除已处理的标准名文件）。"""
    cands = glob.glob(os.path.join(SRC, f"*{frag}*.png"))
    std_names = {m[1] for m in MAPPING}
    cands = [c for c in cands if os.path.basename(c).split(".")[0] not in std_names]
    if not cands:
        return None
    cands.sort(key=lambda p: os.path.getmtime(p))
    return cands[-1]


def main():
    for en_word, std, frag in MAPPING:
        src = pick_latest(frag)
        if not src:
            print(f"[en] 缺 {en_word}")
            continue
        im = Image.open(src).convert("RGBA")
        im = matte(im)
        bbox = word_bbox(im)
        out = unify(im, bbox)
        dst = os.path.join(SRC, f"{std}.png")
        out.save(dst)
        print(f"[en] {en_word} -> {std}.png {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    main()
