# -*- coding: utf-8 -*-
"""R835：空故事书图标 raw → 128×128 RGBA。

从 `tools/_make_r755_icons.py` 抄来的 `_bg_mask` / `cut`（那个脚本**不能 import**：
顶层会直接重写 trap_icon_7012.png / ui_tool_swap.png，R829 时踩过一次）。

用：python tools/_make_r835_icon.py
"""
import os

from PIL import Image, ImageChops, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
SENTINEL_SET = {(255, 0, 255)}
SRC = ROOT + "art_src/2026-11-20_空故事书_R835/raw/icon_6089.png"
OUT = "assets/ui/relic_icon_6089.png"
PREVIEW = ROOT + "art_src/2026-11-20_空故事书_R835/processed/_preview_icon_6089.png"


def _bg_mask(im, bright=200, satmax=45):
    """从四边向内做 4-连通泛洪，返回「背景」掩膜（255 = 背景）。

    判据是「亮且不饱和」——纯白背景与棋盘格两色都满足；
    书页内侧的暖白会被深色描边围住，从边界走不进去，不会被误抠。
    """
    w, h = im.size
    px = im.load()
    ok = bytearray(w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            r, g, b = px[x, y]
            if min(r, g, b) >= bright and max(r, g, b) - min(r, g, b) <= satmax:
                ok[base + x] = 1
    seen = bytearray(w * h)
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if ok[y * w + x]:
                stack.append(y * w + x)
    for y in range(h):
        for x in (0, w - 1):
            if ok[y * w + x]:
                stack.append(y * w + x)
    while stack:
        i = stack.pop()
        if seen[i]:
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
    return Image.frombytes("L", (w, h), bytes(255 if v else 0 for v in seen))


def cut(src, out, pad_pct=0.06, work=512, **bg_kw):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bg = _bg_mask(im, **bg_kw)
    fg = ImageChops.invert(bg)
    # 收 2px：描边外侧的抗锯齿像素「亮且不饱和」会被当前景 → 圆图标带亮边虚线
    for _ in range(2):
        fg = fg.filter(ImageFilter.MinFilter(3))
    darks = sorted([c for c in im.getdata() if c not in SENTINEL_SET and sum(c) < 210],
                   key=lambda c: sum(c))
    edge = darks[max(0, len(darks) // 20)] if darks else (30, 30, 36)
    rgb = Image.composite(im, Image.new("RGB", (w, h), edge), fg)
    alpha = fg.resize((work, work), Image.LANCZOS)
    rgb = rgb.resize((work, work), Image.LANCZOS)
    bb = alpha.point(lambda v: 255 if v >= 8 else 0).getbbox()
    side = max(bb[2] - bb[0], bb[3] - bb[1])
    side = int(side * (1.0 + pad_pct * 2))
    cx = (bb[0] + bb[2]) // 2
    cy = (bb[1] + bb[3]) // 2
    box = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    rgb = rgb.crop(box).resize((128, 128), Image.LANCZOS)
    alpha = alpha.crop(box).resize((128, 128), Image.LANCZOS)
    out_im = rgb.convert("RGBA")
    out_im.putalpha(alpha)
    out_im.save(ROOT + out)
    print("wrote", out, out_im.size)
    return out_im


if __name__ == "__main__":
    ic = cut(SRC, OUT)
    # 预览：贴在深色棋盘上，方便一眼看出边缘有没有白雾 / 缺角
    bgp = Image.new("RGB", (168, 168), (44, 48, 54))
    for yy in range(0, 168, 16):
        for xx in range(0, 168, 16):
            if (xx // 16 + yy // 16) % 2 == 0:
                bgp.paste((56, 60, 68), (xx, yy, xx + 16, yy + 16))
    bgp.paste(ic, (20, 20), ic)
    bgp.save(PREVIEW)
    print("preview", PREVIEW)
