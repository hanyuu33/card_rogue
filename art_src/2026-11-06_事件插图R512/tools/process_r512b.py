# -*- coding: utf-8 -*-
"""R512 事件素材处理 v2：moon 换新图、cave 用底部渐暗代替镜像补带、gaze 分层强化。"""
import os
from PIL import Image, ImageFilter, ImageEnhance, ImageChops

RAW = 'D:/work/gen_raw'
OUT = 'D:/work/card_rogue/assets/ui'
W, H = 1280, 720

SRC = {
    'moon':          ('Flat_cel_shaded_2D_game_backgr_2026-11-06T10-32-50.png', 0),
    'furnace':       ('Flat_cel_shaded_2D_game_backgr_2026-11-06T10-29-25.png', 80),
    'card_merchant': ('Flat_cel_shaded_2D_game_backgr_2026-11-06T10-29-58.png', 80),
    'core_contract': ('Flat_cel_shaded_2D_game_backgr_2026-11-06T10-30-15.png', 80),
    'cave':          ('Flat_cel_shaded_2D_game_backgr_2026-11-06T10-29-40.png', 0),
}


def crop_16x9(im, top=0):
    """1536×1024 → 取 y[top:top+864]，正好 16:9，再缩到 1280×720。"""
    w, h = im.size
    im = im.crop((0, top, w, top + 864))
    return im.resize((W, H), Image.LANCZOS)


def bottom_gradient(im, y_start, factor=0.30):
    """从 y_start 往下把亮度乘到 factor（不可见的「死灰边框」→ 自然的暗部）。"""
    w, h = im.size
    px = im.load()
    span = max(1, h - y_start)
    for y in range(y_start, h):
        t = (y - y_start) / span
        k = 1.0 - (1.0 - factor) * (t ** 0.8)
        for x in range(w):
            r, g, b = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k))
    return im


report = []
for kind, (fn, top) in SRC.items():
    im = Image.open(os.path.join(RAW, fn)).convert('RGB')
    im = crop_16x9(im, top)
    if kind == 'cave':
        im = bottom_gradient(im, 560, 0.26)
    out = os.path.join(OUT, 'bg_%s.png' % kind)
    im.save(out, optimize=True)
    report.append('bg_%s.png  %s  %d KB' % (kind, im.size, os.path.getsize(out) // 1024))

# ---- 鸭之凝视：4:3 → 640×480，红眼单独提饱和 + 外发光，外围压深 ----
g = Image.open(os.path.join(RAW, 'Flat_cel_shaded_2D_illustratio_2026-11-06T10-29-09.png')).convert('RGB')
w, h = g.size
g = g.crop((0, (h - w * 3 // 4) // 2, w, (h + w * 3 // 4) // 2))
g = g.filter(ImageFilter.GaussianBlur(0.6))          # 压掉 AI 的颗粒噪点
g = ImageEnhance.Brightness(g).enhance(1.30)
g = ImageEnhance.Contrast(g).enhance(1.18)

# 眼睛 mask：红通道明显高于绿蓝
r, gg, b = g.split()
redness = ImageChops.subtract(r, ImageChops.lighter(gg, b))
mask = redness.point(lambda v: 255 if v > 18 else 0).filter(ImageFilter.GaussianBlur(3))
glow = g.filter(ImageFilter.GaussianBlur(14))
glow = ImageEnhance.Color(glow).enhance(1.9)
glow = ImageEnhance.Brightness(glow).enhance(1.55)
g = Image.composite(Image.blend(g, glow, 0.55), g, mask)   # 眼睛区加红光
g = ImageEnhance.Color(g).enhance(1.22)
g = g.resize((640, 480), Image.LANCZOS)
out = os.path.join(OUT, 'event_gaze.png')
g.save(out, optimize=True)
report.append('event_gaze.png  %s  %d KB' % (g.size, os.path.getsize(out) // 1024))
print('\n'.join(report))
