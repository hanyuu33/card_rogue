# -*- coding: utf-8 -*-
"""R847 场地边框：抠白底（外圈 + 内圈两道泛洪）→ 248×220 → 落地 assets/ui。

⚠️ 与图标抠图最大的不同：**边框中间是空的，而且必须真的透**。
   只从四边泛洪只能去掉外部背景，中间那块白会留下来；单位卡画在边框**下面**，
   留着白底等于给每个站上去的单位盖一层白膜。
   所以这里跑两道泛洪：① 从四条边种子（外部）② 从正中心种子（内部）。

⚠️ 不 `from _make_r755_icons import ...`：那个模块没有 `__main__` 保护，
   import 会整段跑掉主流程（R836 实测）。泛洪照抄一份，判据一致。
"""
import os
import sys

from PIL import Image

BATCH = os.path.dirname(os.path.abspath(__file__))
ROOT = r"E:\work\card_rogue"
OUT_W, OUT_H = 248, 220          # 格子 124×110 的 2×
DEST_DIR = os.path.join(ROOT, "assets", "ui")

JOBS = [("8028", "8028_spring"), ("8036", "8036_repair"), ("8037", "8037_factory"),
        ("9186", "9186_vortex"), ("8082", "8082_poison"), ("9224", "9224_mark")]


def _flood(ok, w, h, seeds):
    seen = bytearray(w * h)
    stack = list(seeds)
    while stack:
        i = stack.pop()
        if seen[i] or not ok[i]:
            continue
        seen[i] = 1
        x = i % w
        if x > 0 and ok[i - 1] and not seen[i - 1]:
            stack.append(i - 1)
        if x < w - 1 and ok[i + 1] and not seen[i + 1]:
            stack.append(i + 1)
        if i >= w and ok[i - w] and not seen[i - w]:
            stack.append(i - w)
        if i + w < w * h and ok[i + w] and not seen[i + w]:
            stack.append(i + w)
    return seen


def cut_frame(src_path, bright=205, satmax=40):
    im = Image.open(src_path).convert("RGB")
    w, h = im.size
    px = im.load()

    white = bytearray(w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            r, g, b = px[x, y]
            if min(r, g, b) >= bright and max(r, g, b) - min(r, g, b) <= satmax:
                white[base + x] = 1

    outer = [x for x in range(w)]
    seeds = []
    for x in range(w):
        seeds.append(x)
        seeds.append((h - 1) * w + x)
    for y in range(h):
        seeds.append(y * w)
        seeds.append(y * w + w - 1)
    seen = _flood(white, w, h, seeds)

    # 内圈：从正中心种子；中心不在白区（画糊了）就按 3×3 邻域找第一个白像素
    cx, cy = w // 2, h // 2
    inner_seeds = []
    for dy in (0, -1, 1, -2, 2):
        for dx in (0, -1, 1, -2, 2):
            x, y = cx + dx, cy + dy
            if 0 <= x < w and 0 <= y < h and white[y * w + x]:
                inner_seeds.append(y * w + x)
    if not inner_seeds:
        raise RuntimeError("%s：中心不是白底（画糊了？）" % os.path.basename(src_path))
    inner = _flood(white, w, h, inner_seeds)

    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        base = y * w
        for x in range(w):
            i = base + x
            op[x, y] = (0, 0, 0, 0) if (seen[i] or inner[i]) else (px[x, y][0], px[x, y][1], px[x, y][2], 255)

    # ⚠️ bbox **必须只按 alpha 通道取**：`Image.getbbox()` 在 RGBA 上会把 RGB 也算进去，
    #    而下面还要往透明区做血边扩散（RGB 非 0、alpha = 0）→ 用 getbbox() 会框住整张图，
    #    缩完边框只剩一小圈、四周全透（R847 第一次跑就是这么炸的：上/左/右边 alpha=0）。
    bbox = out.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("%s：抠完是空图" % os.path.basename(src_path))
    out = out.crop(bbox)
    w, h = out.size

    # 透明区 RGB 血边：把相邻不透明像素的颜色扩散进去，缩小后不留白/黑边。
    # 放在 crop **之后**：血边要一路爬到新边界，否则缩放到格子尺寸时外圈仍会带一像素白线。
    px2 = out.load()
    for _ in range(4):
        add = []
        for y in range(h):
            for x in range(w):
                if px2[x, y][3] != 0:
                    continue
                acc = [0, 0, 0]
                n = 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px2[nx, ny][3] != 0:
                        acc[0] += px2[nx, ny][0]
                        acc[1] += px2[nx, ny][1]
                        acc[2] += px2[nx, ny][2]
                        n += 1
                if n:
                    add.append((x, y, acc[0] // n, acc[1] // n, acc[2] // n))
        for x, y, r, g, b in add:
            px2[x, y] = (r, g, b, 0)

    return out.resize((OUT_W, OUT_H), Image.LANCZOS)


def _longest_clear(alphas, thr=40):
    """中线上一段最长「透明区」（连续 alpha<=thr）的长度 —— 就是框的开口。"""
    best = cur = 0
    for a in alphas:
        if a <= thr:
            cur += 1
            best = max(best, cur)
        else:
            cur = 0
    return best


def self_check(im, name):
    """四角 / 中心必须全透，四条边「向内扫一段」必须撞到边框。

    ⚠️ 不能要求「边中点那一像素是实心的」：这批边框的四角是**外凸**的，
    bbox 由最凸处决定，于是边中点会缩进来几个像素（R847 第一次跑就是这么误报的）。
    判据改成「从各边中点向内扫 15% 宽度内必须撞到不透明像素」—— 撞不到才算边框没画满那一侧。
    """
    w, h = im.size
    px = im.load()
    bad = []
    for tx, ty, label in ((0, 0, "左上"), (w - 1, 0, "右上"), (0, h - 1, "左下"), (w - 1, h - 1, "右下")):
        if px[tx, ty][3] != 0:
            bad.append("%s角 alpha=%d" % (label, px[tx, ty][3]))
    cx, cy = w // 2, h // 2
    if px[cx, cy][3] != 0:
        bad.append("中心 alpha=%d" % px[cx, cy][3])
    span = max(4, int(w * 0.15))
    probes = [("上边", [(cx, y) for y in range(0, span)]),
              ("下边", [(cx, h - 1 - y) for y in range(0, span)]),
              ("左边", [(x, cy) for x in range(0, span)]),
              ("右边", [(w - 1 - x, cy) for x in range(0, span)])]
    for label, pts in probes:
        if not any(px[x, y][3] >= 200 for x, y in pts):
            bad.append("%s：向内扫 %dpx 没撞到边框" % (label, span))

    # ⚠️ 开口必须装得下卡面（R847b 店长反馈「卡片超出了框」）。
    #    格子 110 高、场上单位卡 92.4 高 → 开口高度必须 ≥ 92.4/110 = 84%。
    #    实测「正方形画布」出的边框开口只有 60%~82%，横画布（113:100）能到 91%。
    #    这条是**硬闸门**：不达标就把该张的 prompt 改回去重出，不要靠绘制侧放大硬撑。
    gw = _longest_clear([px[x, h // 2][3] for x in range(w)])
    gh = _longest_clear([px[w // 2, y][3] for y in range(h)])
    if gh < h * 0.84:
        bad.append("开口高 %.1f%% < 84%%（缩到格子只有 %.1fpx，卡面要 92.4px）"
                   % (100.0 * gh / h, gh * 110.0 / h))
    if gw < w * 0.62:
        bad.append("开口宽 %.1f%% < 62%%（卡面宽要 76.6px）" % (100.0 * gw / w))

    if bad:
        raise RuntimeError("%s 自检失败：%s" % (name, "; ".join(bad)))


def main():
    want = sys.argv[1:] or [j[0] for j in JOBS]
    proc = os.path.join(BATCH, "processed")
    os.makedirs(proc, exist_ok=True)
    done = []
    for cid, stem in JOBS:
        if cid not in want:
            continue
        src = os.path.join(BATCH, "raw", stem + ".png")
        if not os.path.exists(src):
            print("MISS raw/%s.png" % stem)
            continue
        im = cut_frame(src)
        self_check(im, stem)
        out = os.path.join(proc, "field_frame_%s.png" % cid)
        im.save(out)
        dst = os.path.join(DEST_DIR, "field_frame_%s.png" % cid)
        im.save(dst)
        done.append((cid, stem))
        print("OK   field_frame_%s.png  %d KB" % (cid, os.path.getsize(dst) // 1024))

    # 实尺寸对比页：124×110 铺在木色底上（模拟棋盘），下面接一张 2×
    if len(done) >= 2:
        cols = 3
        rows = (len(done) + cols - 1) // cols
        row_h = 110 + 8 + OUT_H + 12
        sheet = Image.new("RGBA", (cols * (OUT_W + 12) + 12, rows * row_h + 12), (60, 52, 42, 255))
        for i, (cid, _stem) in enumerate(done):
            im = Image.open(os.path.join(proc, "field_frame_%s.png" % cid)).convert("RGBA")
            real = im.resize((124, 110), Image.LANCZOS)
            gx = 12 + (i % cols) * (OUT_W + 12)
            gy = 12 + (i // cols) * row_h
            sheet.alpha_composite(real, (gx, gy))
            sheet.alpha_composite(im, (gx, gy + 118))
        sheet.save(os.path.join(proc, "_preview_sheet.png"))
        print("OK   _preview_sheet.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
