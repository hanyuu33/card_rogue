# -*- coding: utf-8 -*-
"""修熔炉底部填充：上一版最后 24px 没覆盖（残留水印），且压暗太慢显得发灰。"""
import os
from PIL import Image, ImageFilter

P = 'D:/work/card_rogue/assets/ui/bg_furnace.png'
im = Image.open(P).convert('RGB')
w, h = im.size
y0, seam, dark_to = 372, 24, 0.16

strip = im.crop((0, y0 - 8, w, y0)).resize((w, h - y0), Image.LANCZOS)
strip = strip.filter(ImageFilter.GaussianBlur(14))
px = strip.load()
hp = h - y0
for y in range(hp):
    k = 1.0 - (1.0 - dark_to) * ((y / max(1, hp)) ** 0.55)
    for x in range(w):
        r, g, b = px[x, y]
        px[x, y] = (int(r * k), int(g * k), int(b * k))

top = im.crop((0, y0 - seam, w, y0)).filter(ImageFilter.GaussianBlur(6))
bottom = strip.crop((0, 0, w, seam)).filter(ImageFilter.GaussianBlur(6))
im.paste(strip, (0, y0))                       # 整段覆盖（含最后几行）
im.paste(Image.blend(top, bottom, 0.5), (0, y0 - seam))
im.save(P, optimize=True)
print('bg_furnace.png ok', im.size, os.path.getsize(P) // 1024, 'KB')
