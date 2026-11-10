# -*- coding: utf-8 -*-
"""R548：从设计稿里把「绿缎带 + 金色战斗胜利 + 顶部盾徽」整块裁下来，做成一体的 UI 素材。

思路（用户口径：「直接把素材图里绿色缎带和战斗胜利四个字绑定一起裁下来作为素材」）：
  1. 设计稿 exec-f8dca5cb（1536×1024，横版效果图）与空白底板 359ff0b3（1254×1254）
     是同一套设计的两个尺寸版本，缎带的绿色外接框几乎一样大（1024×207 vs 1038×205），
     所以可以把设计稿那块直接盖到空白底板上。
  2. 抠图不能只按颜色距离 —— 设计稿缎带上方有一片暖色光晕，会被整条带进来；
     字心离绿色太远，又会被当成背景挖空。最终用三路合并：
       (a) 逐列「最长连续绿段」填满 → 拿到缎带本体（含被字打断的列）
       (b) 金字 / 深描边（限制在缎带内部窗口） → 补齐四个字
       (c) 盾徽 / 月桂（限制在中心 x 范围） → 把顶部徽记一起带走
     再连通域过滤掉面板顶边框上的碎点，边缘羽化 1.4px。
  3. 抠好后按「绿色外接框对齐」缩放贴到空白底板，合成一张验证图；
     同时导出游戏素材（2x：1018×279，游戏里按 0.5 显示）。

产出：
  assets/ui/battle_win_ribbon.png      游戏素材
  _preview/r548_comp580.png            合成验证（580 面板尺寸）
用法：python _r548_make.py
"""
import os
from PIL import Image, ImageFilter

A = 'C:/Users/Administrator/.codex/generated_images/01a1c0c6-07c7-7b60-8d80-942b79b88c8a/exec-f8dca5cb-4a57-4490-b679-e15858921429.png'
B = 'art_src/2026-11-09_战斗结算UI_R546/raw/359ff0b3_胜利面板空白底板_原图.png'
CROP = (230, 20, 1300, 320)          # 设计稿里要抠的块
GREEN_A = (252, 88, 1276, 295)       # 设计稿缎带绿色外接框（原图坐标）
GREEN_B = (107, 180, 1145, 385)      # 空白底板缎带绿色外接框
GROW = 1.015                         # 略放大，盖住旧缎带边缘 1~2px 的错位
MIN_AREA = 140                       # 连通域面积下限（滤掉面板顶边框碎点）
OUT_W = 1018                         # 游戏素材宽（2x，游戏里按 0.5 显示）
OUT = 'assets/ui/battle_win_ribbon.png'
PREVIEW = '_preview/r548_comp580.png'


def isg(c):
    r, g, b = c
    return g > r + 6 and g > b + 6 and 25 < g < 185


def isgold(c):
    r, g, b = c
    return r >= 150 and g >= 110 and (r - b) >= 45 and b <= 168


def isdark(c):
    return max(c) <= 95


def cut_block():
    blk = Image.open(A).convert('RGBA').crop(CROP)
    w, h = blk.size
    px = blk.convert('RGB').load()

    # (a) 逐列最长连续绿段填满
    cols = Image.new('L', (w, h), 0)
    cp = cols.load()
    for x in range(w):
        runs, cur = [], None
        for y in range(h):
            if isg(px[x, y]):
                if cur is None:
                    cur = [y, y]
                else:
                    cur[1] = y
            elif cur:
                runs.append(tuple(cur))
                cur = None
        if cur:
            runs.append(tuple(cur))
        merged = []
        for r0, r1 in runs:
            if merged and r0 - merged[-1][1] <= 6:
                merged[-1] = (merged[-1][0], r1)
            else:
                merged.append((r0, r1))
        if not merged:
            continue
        best = max(merged, key=lambda t: t[1] - t[0])
        if best[1] - best[0] < 30:
            continue
        for y in range(best[0], best[1] + 1):
            cp[x, y] = 255

    # (b) 金字 / 描边
    extra = Image.new('L', (w, h), 0)
    ep = extra.load()
    for y in range(105, min(h, 290)):
        for x in range(10, min(w, 1060)):
            c = px[x, y]
            if isgold(c) or isdark(c):
                ep[x, y] = 255
    extra = extra.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(5))

    # (c) 盾徽 / 月桂
    shield = Image.new('L', (w, h), 0)
    shp = shield.load()
    for y in range(0, 205):
        for x in range(w):
            if 545 <= x + CROP[0] <= 980:
                c = px[x, y]
                if isgold(c) or isdark(c) or isg(c):
                    shp[x, y] = 255
    shield = shield.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(7))

    # 逐列缎带真实上下沿（该列所有绿像素首末，再 9 列中值平滑）
    raw_min, raw_max = [None] * w, [None] * w
    for x in range(w):
        ys = [y for y in range(h) if isg(px[x, y])]
        if ys:
            raw_min[x], raw_max[x] = ys[0], ys[-1]
    last = None
    for x in range(w):
        if raw_min[x] is None:
            if last is not None:
                raw_min[x], raw_max[x] = last
        else:
            last = (raw_min[x], raw_max[x])
    nxt = None
    for x in range(w - 1, -1, -1):
        if raw_min[x] is None:
            if nxt is not None:
                raw_min[x], raw_max[x] = nxt
        else:
            nxt = (raw_min[x], raw_max[x])

    def median_filter(arr, k=9):
        out, half = list(arr), k // 2
        for x in range(w):
            seg = [arr[min(w - 1, max(0, x + d))] for d in range(-half, half + 1)]
            seg = [v for v in seg if v is not None]
            if seg:
                out[x] = sorted(seg)[len(seg) // 2]
        return out

    col_min, col_max = median_filter(raw_min), median_filter(raw_max)

    m = Image.new('L', (w, h), 0)
    m.paste(cols, (0, 0))
    for src, lo_off, hi_off, xr, ycap in (
        (extra, 2, 14, None, h),
        (shield, -165, 14, (455, 815), 212),
    ):
        layer = Image.new('L', (w, h), 0)
        lp, sp2 = layer.load(), src.load()
        for y in range(h):
            for x in range(w):
                if not sp2[x, y] or col_min[x] is None:
                    continue
                if xr and not (xr[0] <= x + CROP[0] <= xr[1]):
                    continue
                lo, hi = col_min[x] + lo_off, min(col_max[x] + hi_off, ycap)
                if 0 <= lo <= y <= hi:
                    lp[x, y] = 255
        m.paste(layer, (0, 0), layer)

    m = m.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))

    # 连通域过滤
    mp = m.load()
    seen = bytearray(w * h)
    out = Image.new('L', (w, h), 0)
    op = out.load()
    for sy in range(h):
        for sx in range(w):
            i = sy * w + sx
            if seen[i] or mp[sx, sy] == 0:
                continue
            stack, pts = [(sx, sy)], []
            seen[i] = 1
            while stack:
                cx, cy = stack.pop()
                pts.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and mp[nx, ny]:
                            seen[j] = 1
                            stack.append((nx, ny))
            if len(pts) >= MIN_AREA:
                for cx, cy in pts:
                    op[cx, cy] = 255

    alpha = out.filter(ImageFilter.GaussianBlur(1.4)).point(
        lambda v: 255 if v > 100 else (int(v * 2.5) if v > 20 else 0))
    blk.putalpha(alpha)
    return blk


def main():
    blk = cut_block()
    w, h = blk.size
    gx0, gy0 = GREEN_A[0] - CROP[0], GREEN_A[1] - CROP[1]
    gx1, gy1 = GREEN_A[2] - CROP[0], GREEN_A[3] - CROP[1]

    oh = int(round(h * OUT_W / w))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    blk.resize((OUT_W, oh), Image.LANCZOS).save(OUT, optimize=True)
    print('[out] %s %dx%d' % (OUT, OUT_W, oh))

    sx = (GREEN_B[2] - GREEN_B[0]) / (gx1 - gx0) * GROW
    sy = (GREEN_B[3] - GREEN_B[1]) / (gy1 - gy0) * GROW
    blk2 = blk.resize((int(w * sx), int(h * sy)), Image.LANCZOS)
    cx = (GREEN_B[0] + GREEN_B[2]) / 2
    cy = (GREEN_B[1] + GREEN_B[3]) / 2
    px_ = int(round(cx - (gx0 + gx1) / 2 * sx))
    py_ = int(round(cy - (gy0 + gy1) / 2 * sy))
    comp = Image.open(B).convert('RGBA').copy()
    comp.alpha_composite(blk2, (px_, py_))
    comp.convert('RGB').resize((580, 580), Image.LANCZOS).save(PREVIEW)
    K = 580.0 / 1254.0
    print('[game] pos=(%.1f, %.1f) size=(%.1f, %.1f) 素材按 0.5 显示'
          % (px_ * K, py_ * K, OUT_W * 0.5, oh * 0.5))
    print('[preview] %s' % PREVIEW)


if __name__ == '__main__':
    main()
