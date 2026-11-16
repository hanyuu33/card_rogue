#!/usr/bin/env python3
"""能量「紫色能量光」艺术字：字形锁死 + 明亮紫光（店长口径「更亮」）。

与 _compose_word.py 的区别：字面不用 multiply 压暗，改用「明亮紫渐变 + 紫色能量纹理
screen 叠加」，三层紫色光晕（内亮紫 -> 外深紫），带能量光点。

用法：
  python tools/_compose_energy.py --out assets/fx/status_words/nengliang.png \
      --texture "<紫色能量纹理.png>" --word 能量
"""
import sys
import random
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

FONT = "assets/fonts/SourceHanSansCN-Bold.otf"
CANVAS = (1536, 1024)
TARGET_H = 750
PAD = 15
SEED = 11


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


def make_energy(word, texture_path, px=800, layers=14):
    canvas = CANVAS
    mask = render_mask(word, canvas, px)
    result = Image.new("RGBA", canvas, (0, 0, 0, 0))

    # 1. 紫色光晕：外深紫 -> 中紫 -> 内亮紫
    glow_outer = mask.filter(ImageFilter.MaxFilter(31))
    glow_mid = mask.filter(ImageFilter.MaxFilter(17))
    glow_inner = mask.filter(ImageFilter.MaxFilter(7))
    for gm, col, al in [(glow_outer, "6a2bff", 0.30),
                        (glow_mid, "9a5cff", 0.42),
                        (glow_inner, "c9a4ff", 0.58)]:
        layer = apply_alpha(Image.new("RGB", canvas, hex_rgb(col)), gm)
        layer = Image.blend(Image.new("RGBA", canvas, (0, 0, 0, 0)), layer, al)
        result.alpha_composite(layer)

    # 2. 斜向挤出：深紫
    ec = hex_rgb("3f1a8a")
    extrude_mask = Image.new("L", canvas, 0)
    for i in range(layers):
        dx = i + 1
        dy = int(round((i + 1) * 1.2))
        extrude_mask = ImageChops.lighter(extrude_mask, offset(mask, dx, dy))
    result.alpha_composite(apply_alpha(Image.new("RGB", canvas, ec), extrude_mask))

    # 3. 字面：明亮紫渐变 + 紫色能量纹理 screen
    face = gradient("f4ecff", "7a3cff", canvas)
    if texture_path:
        tex = Image.open(texture_path).convert("RGB").resize(canvas, Image.LANCZOS)
        face = ImageChops.screen(face, tex)
    result.alpha_composite(apply_alpha(face, mask))

    # 4. 顶高光：白紫
    hi_mask = offset(mask, 0, -2)
    hi_mask = ImageChops.subtract(hi_mask, ImageChops.darker(hi_mask, mask))
    hi_layer = apply_alpha(Image.new("RGB", canvas, (255, 255, 255)), hi_mask)
    hi_layer = Image.blend(Image.new("RGBA", canvas, (0, 0, 0, 0)), hi_layer, 0.6)
    result.alpha_composite(hi_layer)

    # 5. 能量光点：字周撒亮紫光点
    rng = random.Random(SEED)
    bbox = mask.getbbox()
    d = ImageDraw.Draw(result)
    for _ in range(36):
        mx = rng.randint(bbox[0], bbox[2])
        my = rng.randint(bbox[1] - 60, bbox[3] + 60)
        r = rng.randint(2, 6)
        col = (220, 190, 255, rng.randint(170, 255))
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
    word = d.get("--word", "能量")
    tex = d.get("--texture", "")
    out = d.get("--out", "assets/fx/status_words/nengliang.png")
    res = make_energy(word, tex)
    res = unify(res)
    res.save(out)
    print(f"[energy] {out} '{word}' {res.size[0]}x{res.size[1]}")
