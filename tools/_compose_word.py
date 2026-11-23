#!/usr/bin/env python3
"""字形蒙版 × 材质纹理 + 斜向立体挤出 + 边缘发光 → 正确且立体的艺术字。

管线（从底到顶）：
  1. 边缘发光：mask 膨胀 N px 的主题色光晕（字周辉光）
  2. 斜向挤出：字形向右下偏移累积成深色「厚度侧面」
  3. 字面：AI 材质纹理 × 顶亮底暗垂直渐变
  4. 顶高光：字形上移的半透明白，只露顶部
合成 alpha 取自字形蒙版 → 字形 100% 正确。

用法：
  python tools/_compose_word.py --word 燃烧 --texture <熔岩纹理.png> \
      --out <out.png> --top ffe08a --bottom 7a1803 --extrude 3c0d02 \
      --glow ff6a1f --px 420 --layers 12
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

FONT = "assets/fonts/SourceHanSansCN-Bold.otf"


def hex_rgb(h: str):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def render_mask(word: str, canvas, px: int) -> Image.Image:
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


def offset(img: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new(img.mode, img.size, 0)
    out.paste(img, (dx, dy))
    return out


def gradient(top, bottom, canvas) -> Image.Image:
    tc = hex_rgb(top)
    bc = hex_rgb(bottom)
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


def apply_alpha(rgb: Image.Image, mask: Image.Image) -> Image.Image:
    rgba = rgb.convert("RGBA")
    rgba.putalpha(mask)
    return rgba


def compose(word: str, texture_path: str, out: str, top: str, bottom: str,
            extrude: str, glow: str, px: int = 420, layers: int = 12,
            canvas=(1536, 1024)) -> None:
    mask = render_mask(word, canvas, px)
    tex = Image.open(texture_path).convert("RGB").resize(canvas, Image.LANCZOS)
    grad = gradient(top, bottom, canvas)
    face_color = ImageChops.multiply(tex, grad)

    result = Image.new("RGBA", canvas, (0, 0, 0, 0))

    # 1. 边缘发光：mask 膨胀，主题色半透明
    gc = hex_rgb(glow)
    glow_mask = mask.filter(ImageFilter.MaxFilter(9))  # 膨胀 ~4px
    glow_rgb = Image.new("RGB", canvas, gc)
    glow_layer = apply_alpha(glow_rgb, glow_mask)
    glow_layer = Image.blend(Image.new("RGBA", canvas, (0, 0, 0, 0)), glow_layer, 0.35)
    result.alpha_composite(glow_layer)

    # 2. 斜向挤出：向右下偏移累积，深色
    ec = hex_rgb(extrude)
    extrude_mask = Image.new("L", canvas, 0)
    for i in range(layers):
        dx = i + 1
        dy = int(round((i + 1) * 1.2))
        shifted = offset(mask, dx, dy)
        extrude_mask = ImageChops.lighter(extrude_mask, shifted)
    extrude_rgb = Image.new("RGB", canvas, ec)
    result.alpha_composite(apply_alpha(extrude_rgb, extrude_mask))

    # 3. 字面
    result.alpha_composite(apply_alpha(face_color, mask))

    # 4. 顶高光：上移 2px 的半透明白，只露顶部
    hi_mask = offset(mask, 0, -2)
    hi_mask = ImageChops.subtract(hi_mask, ImageChops.darker(hi_mask, mask))
    hi_rgb = Image.new("RGB", canvas, (255, 255, 255))
    hi_layer = apply_alpha(hi_rgb, hi_mask)
    hi_layer = Image.blend(Image.new("RGBA", canvas, (0, 0, 0, 0)), hi_layer, 0.5)
    result.alpha_composite(hi_layer)

    result = autocrop(result)
    result.save(out)
    print(f"[compose] {out} '{word}' {result.size[0]}x{result.size[1]}")


def autocrop(im: Image.Image, pad: int = 30) -> Image.Image:
    bbox = im.getbbox()
    if bbox is None:
        return im
    l = max(0, bbox[0] - pad)
    t = max(0, bbox[1] - pad)
    r = min(im.width, bbox[2] + pad)
    b = min(im.height, bbox[3] + pad)
    return im.crop((l, t, r, b))


if __name__ == "__main__":
    args = sys.argv[1:]
    d = {}
    i = 0
    while i < len(args):
        if args[i].startswith("--") and i + 1 < len(args):
            d[args[i]] = args[i + 1]
            i += 2
        else:
            i += 1
    compose(d["--word"], d["--texture"], d["--out"],
            d.get("--top", "ffffff"), d.get("--bottom", "1b5fc0"),
            d.get("--extrude", "0a2547"), d.get("--glow", "8ad4f0"),
            int(d.get("--px", 420)), int(d.get("--layers", 12)))
