# -*- coding: utf-8 -*-
"""R841c：润滑油 7019 图标改机械风格 —— 抠白底 + 128×128 + 对比页。

⚠️ 不 import `_make_r755_icons`（那个模块没有 `__main__` 保护，import 会跑主流程
覆盖 assets/ui 图标 —— R836 实测）；`_bg_mask` / `cut` 在这里照抄一份。

只换 7019 一张：7016 爆炸蘑菇 / 7017 大蒜 / 7018 木锤 一律不碰。
"""
import os
import shutil

from PIL import Image, ImageChops, ImageFilter

BATCH = "art_src/2026-11-20_润滑油机械风_R841c/"
ROOT = "./"
SENTINEL = (255, 0, 255)
SENTINEL_SET = {SENTINEL}

JOBS = [
    ("7019_油壶机械", "trap_icon_7019.png"),
]


def _bg_mask(im, bright=200, satmax=45):
    """从四边向内 4-连通泛洪，返回「背景」掩膜（255 = 背景）。判据「亮且不饱和」。"""
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


def cut(src, out, pad_pct=0.01, work=512):
    # ⚠️ 留白比其他工具图标更小（1% vs 6%）：油壶是「宽而矮」的横向量，
    # 长弯嘴把包围盒撑宽 → 按宽度装进正方形时罐身被压小，44px 下一眼偏瘦。
    # 既有 7016~7018 都是顶边满幅，这里跟齐才不显得缩在格子里。
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bg = _bg_mask(im)
    fg = ImageChops.invert(bg)
    # 收 2px：描边外侧的抗锯齿像素「亮且不饱和」，不收会在圆图标外留一圈虚线亮边
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
    out_im.save(out)
    print("wrote %s %s" % (out, out_im.size))
    return out_im


def preview(paths, out, bg=(26, 26, 32, 255), scale=4, cell=44):
    ims = [Image.open(p).convert("RGBA").resize((cell, cell), Image.LANCZOS) for p in paths]
    w = cell * len(ims) + 20 * (len(ims) + 1)
    canvas = Image.new("RGBA", (w, cell + 40), bg)
    for i, im in enumerate(ims):
        canvas.paste(im, (20 + i * (cell + 20), 20), im)
    canvas.resize((canvas.width * scale, canvas.height * scale), Image.LANCZOS).save(out)
    print("preview", out)


def main():
    os.makedirs(BATCH + "processed", exist_ok=True)
    for raw, name in JOBS:
        out = BATCH + "processed/" + name
        im = cut(BATCH + "raw/" + raw + ".png", out)
        a = im.getchannel("A")
        corners = [a.getpixel((0, 0)), a.getpixel((127, 0)),
                   a.getpixel((0, 127)), a.getpixel((127, 127))]
        assert max(corners) == 0, "%s 四角还有不透明像素（背景没抠净）" % name
        assert a.getpixel((64, 64)) > 200, "%s 中心不透明度过低" % name
        shutil.copyfile(out, ROOT + "assets/ui/" + name)
        assert open(out, "rb").read() == open(ROOT + "assets/ui/" + name, "rb").read()
    # 同栏对比：看新油壶与既有三件是否还成一家
    sib = ["assets/ui/trap_icon_7016.png", "assets/ui/trap_icon_7017.png",
           "assets/ui/trap_icon_7018.png", "assets/ui/trap_icon_7019.png"]
    preview(sib, BATCH + "processed/_preview_44px.png", cell=44, scale=4)
    preview(sib, BATCH + "processed/_preview_88px.png", cell=128, scale=2)
    print("byte-identical + alpha OK")


if __name__ == "__main__":
    main()
