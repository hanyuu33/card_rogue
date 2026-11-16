#!/usr/bin/env python3
"""燃烧「火焰」艺术字：字形锁死 + 明亮火焰 + 火烧特效（火光 / 火星）。

与 _compose_word.py 的区别（店长口径「太像熔岩、要更亮 + 火烧特效」）：
  * 字面不用「暗黑熔岩龟裂 × 渐变」的 multiply（越乘越暗、像石头），
    改用「明亮火焰渐变 + 火焰纹理 screen 叠加」——screen 只取火舌亮部提亮，黑底不压暗；
  * 加三层火光光晕（内亮黄 -> 外橙）+ 程序化火星粒子（向上飘）；
  * 末尾统一缩放：字高 750px、四周 15px padding（与其它状态词对齐，播放时统一缩放）。

用法：
  python tools/_compose_flame.py --out assets/fx/status_words/ranshao.png \
      --texture "<火焰纹理.png>" --word 燃烧
"""
import sys
import random
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

FONT = "assets/fonts/SourceHanSansCN-Bold.otf"
CANVAS = (1536, 1024)
TARGET_H = 750      # 统一字高（与 AI 整字对齐）
PAD = 15            # 统一四周留白
SEED = 7


def hex_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def render_mask(word, canvas, px):
    im = Image.new("L", canvas, 0)
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(FONT, px)
    bbox = d.textbbox((0, 0), word, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (canvas[0] - tw) / 2 - bbox[0]
    y = (canvas[1] - th) / 2 - bbox[1]
    d.text((x, y), word, font=font, fill=255)
    return im


def offset(img, dx, dy):
    out = Image.new(img.mode, img.size, 0)
    out.paste(img, (dx, dy))
    return out


def gradient(top, bottom, canvas):
    tc, bc = hex_rgb(top), hex_rgb(bottom)
    W, H = canvas
    im = Image.new("RGB", canvas)
    px = im.load()
    for y in range(H):
        t = y / max(1, H - 1)
        c = (int(tc[0] + (bc[0] - tc[0]) * t),
             int(tc[1] + (bc[1] - tc[1]) * t),
             int(tc[2] + (bc[2] - tc[2]) * t))
        for x in range(W):
            px[x, y] = c
    return im


def apply_alpha(rgb, mask):
    rgba = rgb.convert("RGBA")
    rgba.putalpha(mask)
    return rgba


def make_flame(word, texture_path, px=800, layers=14):
    canvas = CANVAS
    mask = render_mask(word, canvas, px)
    result = Image.new("RGBA", canvas, (0, 0, 0, 0))

    # 1. 火光光晕：mask 膨胀多层（外橙 -> 中橙黄 -> 内亮黄）
    glow_outer = mask.filter(ImageFilter.MaxFilter(31))
    glow_mid = mask.filter(ImageFilter.MaxFilter(17))
    glow_inner = mask.filter(ImageFilter.MaxFilter(7))
    for gm, col, al in [(glow_outer, "ff5a00", 0.28),
                        (glow_mid, "ffa200", 0.40),
                        (glow_inner, "ffd23e", 0.55)]:
        layer = apply_alpha(Image.new("RGB", canvas, hex_rgb(col)), gm)
        layer = Image.blend(Image.new("RGBA", canvas, (0, 0, 0, 0)), layer, al)
        result.alpha_composite(layer)

    # 2. 斜向挤出：深橙（比暗红棕亮，火才有温度）
    ec = hex_rgb("b83c00")
    extrude_mask = Image.new("L", canvas, 0)
    for i in range(layers):
        dx = i + 1
        dy = int(round((i + 1) * 1.2))
        extrude_mask = ImageChops.lighter(extrude_mask, offset(mask, dx, dy))
    result.alpha_composite(apply_alpha(Image.new("RGB", canvas, ec), extrude_mask))

    # 3. 字面：明亮火焰渐变 + 火焰纹理 screen 叠加（火舌亮部提亮）
    face = gradient("fffbe0", "ff7a00", canvas)
    if texture_path:
        tex = Image.open(texture_path).convert("RGB").resize(canvas, Image.LANCZOS)
        face = ImageChops.screen(face, tex)
    result.alpha_composite(apply_alpha(face, mask))

    # 4. 顶高光：白热
    hi_mask = offset(mask, 0, -2)
    hi_mask = ImageChops.subtract(hi_mask, ImageChops.darker(hi_mask, mask))
    hi_layer = apply_alpha(Image.new("RGB", canvas, (255, 255, 255)), hi_mask)
    hi_layer = Image.blend(Image.new("RGBA", canvas, (0, 0, 0, 0)), hi_layer, 0.6)
    result.alpha_composite(hi_layer)

    # 5. 火星：字形上方撒亮橙黄粒子
    rng = random.Random(SEED)
    bbox = mask.getbbox()
    d = ImageDraw.Draw(result)
    for _ in range(48):
        mx = rng.randint(bbox[0], bbox[2])
        my = rng.randint(bbox[1] - 70, bbox[1] + 14)
        r = rng.randint(2, 7)
        if rng.random() < 0.6:
            col = (255, 210, 60, rng.randint(180, 255))
        else:
            col = (255, 140, 20, rng.randint(160, 255))
        d.ellipse([mx - r, my - r, mx + r, my + r], fill=col)

    return result


def unify(im, target_h=TARGET_H, pad=PAD):
    bbox = im.getbbox()
    if bbox is None:
        return im
    crop = im.crop(bbox)
    w, h = crop.size
    nh = target_h
    nw = max(1, round(w * target_h / h))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (nw + pad * 2, nh + pad * 2), (0, 0, 0, 0))
    out.paste(crop, (pad, pad))
    return out


if __name__ == "__main__":
    d = {}
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i].startswith("--") and i + 1 < len(args):
            d[args[i]] = args[i + 1]
            i += 2
        else:
            i += 1
    word = d.get("--word", "燃烧")
    tex = d.get("--texture", "")
    out = d.get("--out", "assets/fx/status_words/ranshao.png")
    res = make_flame(word, tex)
    res = unify(res)
    res.save(out)
    print(f"[flame] {out} '{word}' {res.size[0]}x{res.size[1]}")
