# -*- coding: utf-8 -*-
"""R839b：大蒜 7017 图标落地 —— 抠白底 + 出 128×128 + 对比预览。

⚠️ 不 `from _make_r755_icons import ...`：那个模块没有 `__main__` 保护，
import 时会把主流程整段跑掉、覆盖两张 assets/ui 图标（R836 实测）。
所以 `_bg_mask` / `cut` 在这里照抄一份（同判据，改的是 ROOT）。
"""
import io
import os
import shutil

from PIL import Image, ImageChops, ImageFilter

BATCH = "E:/work/card_rogue/art_src/2026-11-20_大蒜图标_R839b/"
ROOT = "E:/work/card_rogue/"
SRC = BATCH + "raw/7017_大蒜.png"
OUT = BATCH + "processed/trap_icon_7017.png"
DEST = "assets/ui/trap_icon_7017.png"

SENTINEL = (255, 0, 255)
SENTINEL_SET = {SENTINEL}


def _bg_mask(im, bright=200, satmax=45):
    """从四边向内 4-连通泛洪，返回「背景」掩膜（255 = 背景）。

    判据「亮且不饱和」：白底 / 棋盘格两色都满足；物体内部的高光被深描边围住，从边界走不进去。
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


def cut(src, out, pad_pct=0.06, bright=1.0, sat=1.0, work=512, **bg_kw):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bg = _bg_mask(im, **bg_kw)
    fg = ImageChops.invert(bg)
    # 收 2px：描边外侧的抗锯齿像素「亮且不饱和」会被判成前景 → 圆图标带一圈虚线亮边
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
    if bright != 1.0:
        from PIL import ImageEnhance
        rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    if sat != 1.0:
        from PIL import ImageEnhance
        rgb = ImageEnhance.Color(rgb).enhance(sat)
    out_im = rgb.convert("RGBA")
    out_im.putalpha(alpha)
    out_im.save(out)
    print("wrote %s %s" % (out, out_im.size))
    return out_im


def preview(paths, out, bg=(26, 26, 32, 255), scale=3, cell=128):
    ims = [Image.open(p).convert("RGBA") for p in paths]
    w = cell * len(ims) + 20 * (len(ims) + 1)
    canvas = Image.new("RGBA", (w, cell + 40), bg)
    for i, im in enumerate(ims):
        im = im.resize((cell, cell), Image.LANCZOS)
        canvas.paste(im, (20 + i * (cell + 20), 20), im)
    canvas.resize((canvas.width * scale, canvas.height * scale), Image.LANCZOS).save(out)
    print("preview", out)


def main():
    os.makedirs(BATCH + "processed", exist_ok=True)
    im = cut(SRC, OUT)
    # 自检：四角必须真透明，中心必须不透明
    a = im.getchannel("A")
    corners = [a.getpixel((0, 0)), a.getpixel((127, 0)), a.getpixel((0, 127)), a.getpixel((127, 127))]
    print("corner alpha", corners, "center alpha", a.getpixel((64, 64)))
    assert max(corners) == 0, "四角还有不透明像素（背景没抠净）"
    assert a.getpixel((64, 64)) > 200, "中心不透明度过低"

    shutil.copyfile(OUT, ROOT + DEST)
    print("copied ->", DEST)

    sibs = ["assets/ui/trap_icon_7001.png", "assets/ui/trap_icon_7016.png",
            "assets/ui/trap_icon_7013.png", "assets/ui/trap_icon_7017.png"]
    for f in sibs:
        assert os.path.exists(ROOT + f), f
    preview([ROOT + p for p in sibs], BATCH + "processed/_preview_88px.png", cell=128, scale=2)
    preview([ROOT + p for p in sibs], BATCH + "processed/_preview_44px.png", cell=44, scale=4)

    # 与 assets 同字节
    assert open(OUT, "rb").read() == open(ROOT + DEST, "rb").read()
    print("byte-identical OK")


if __name__ == "__main__":
    main()
