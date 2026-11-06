# -*- coding: utf-8 -*-
"""R512 素材打磨：熔炉底部黑框拉平成地面、鸭之凝视做「只有眼睛亮」的径向分层。"""
import os
from PIL import Image, ImageFilter, ImageEnhance, ImageChops, ImageDraw

OUT = 'D:/work/card_rogue/assets/ui'


def extend_floor(im, y0, dark_to=0.26, blur=10):
    """用 y0 上方一小条地面色向下拉伸 + 压暗，替掉 AI 画的拱形黑框。"""
    w, h = im.size
    strip = im.crop((0, y0 - 8, w, y0)).resize((w, h - y0), Image.LANCZOS)
    strip = strip.filter(ImageFilter.GaussianBlur(blur))
    px = strip.load()
    hp = h - y0
    for y in range(hp):
        k = 1.0 - (1.0 - dark_to) * ((y / max(1, hp)) ** 0.7)
        for x in range(w):
            r, g, b = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k))
    # 接缝羽化：把交界上下 24px 混合
    seam = 24
    top = im.crop((0, y0 - seam, w, y0)).filter(ImageFilter.GaussianBlur(6))
    bottom = strip.crop((0, 0, w, seam)).filter(ImageFilter.GaussianBlur(6))
    im.paste(Image.blend(top, bottom, 0.5), (0, y0 - seam))
    im.paste(strip.crop((0, seam, w, hp)), (0, y0))
    return im


# ---- 熔炉：底部拱形黑框拉平 ----
p = os.path.join(OUT, 'bg_furnace.png')
im = Image.open(p).convert('RGB')
im = extend_floor(im, 372, 0.22)
im.save(p, optimize=True)
print('bg_furnace.png 底部拉平 ok')

# ---- 鸭之凝视：中间留亮、四周压到近乎全黑 ----
p = os.path.join(OUT, 'event_gaze.png')
im = Image.open(p).convert('RGB')
w, h = im.size                       # 640×480
mask = Image.new('L', (w, h), 0)
d = ImageDraw.Draw(mask)
cx, cy = 308, 188
d.ellipse((cx - 236, cy - 150, cx + 236, cy + 150), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(56))
dark = ImageEnhance.Brightness(im).enhance(0.34)
im = Image.composite(im, dark, mask)
im = ImageEnhance.Contrast(im).enhance(1.10)
im = ImageEnhance.Brightness(im).enhance(1.06)
im.save(p, optimize=True)
print('event_gaze.png 径向分层 ok')
