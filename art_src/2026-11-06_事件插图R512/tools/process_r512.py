# -*- coding: utf-8 -*-
"""R512 事件素材处理：出 5 张 bg_（1280×720）+ 1 张 event_gaze（640×480）。"""
import os
from PIL import Image, ImageFilter, ImageEnhance

RAW = 'D:/work/gen_raw'
OUT = 'D:/work/card_rogue/assets/ui'
W, H = 1280, 720

SRC = {
    'moon':          'Flat_cel_shaded_2D_game_backgr_2026-11-06T10-28-54.png',
    'gaze':          'Flat_cel_shaded_2D_illustratio_2026-11-06T10-29-09.png',
    'furnace':       'Flat_cel_shaded_2D_game_backgr_2026-11-06T10-29-25.png',
    'cave':          'Flat_cel_shaded_2D_game_backgr_2026-11-06T10-29-40.png',
    'card_merchant': 'Flat_cel_shaded_2D_game_backgr_2026-11-06T10-29-58.png',
    'core_contract': 'Flat_cel_shaded_2D_game_backgr_2026-11-06T10-30-15.png',
}


def mirror_fill_band(im, y_start, blur=20, darken=0.42):
    """把 y_start 以下的「死黑/死灰边框」换成上方内容镜像 + 模糊 + 压暗，
    看起来像前景暗部延续，而不是一条硬边。"""
    w, h = im.size
    band_h = h - y_start
    if band_h <= 0:
        return im
    src = im.crop((0, max(0, y_start - band_h), w, y_start)).transpose(Image.FLIP_TOP_BOTTOM)
    src = src.resize((w, band_h), Image.LANCZOS)
    src = src.filter(ImageFilter.GaussianBlur(blur))
    src = ImageEnhance.Brightness(src).enhance(darken)
    out = im.copy()
    out.paste(src, (0, y_start))
    return out


def fit_cover(im, tw, th, crop_top=80, crop_bottom=80):
    """1536×1024 → 先按「留出上下裁切余量」取其有效区，再等比缩到目标。"""
    w, h = im.size
    im = im.crop((0, crop_top, w, h - crop_bottom))
    w, h = im.size
    s = max(tw / w, th / h)
    nw, nh = int(round(w * s)), int(round(h * s))
    im = im.resize((nw, nh), Image.LANCZOS)
    x = (nw - tw) // 2
    y = (nh - th) // 2
    return im.crop((x, y, x + tw, y + th))


report = []

# ---- 横版背景（1536×1024）----
for kind, y_band in [('moon', 660), ('cave', 720), ('furnace', None),
                     ('card_merchant', None), ('core_contract', None)]:
    im = Image.open(os.path.join(RAW, SRC[kind])).convert('RGB')
    if y_band is not None:
        im = mirror_fill_band(im, y_band)
    im = fit_cover(im, W, H)
    out = os.path.join(OUT, 'bg_%s.png' % kind)
    im.save(out, optimize=True)
    report.append('bg_%s.png  %s  %d KB' % (kind, im.size, os.path.getsize(out) // 1024))

# ---- 鸭之凝视：方图 → 4:3，提亮 + 加饱和（黑底最容易糊成一团）----
g = Image.open(os.path.join(RAW, SRC['gaze'])).convert('RGB')
w, h = g.size                      # 1024×1024
g = g.crop((0, (h - w * 3 // 4) // 2, w, (h + w * 3 // 4) // 2))   # 1024×768
g = g.resize((640, 480), Image.LANCZOS)
g = ImageEnhance.Brightness(g).enhance(1.42)
g = ImageEnhance.Contrast(g).enhance(1.12)
g = ImageEnhance.Color(g).enhance(1.32)
out = os.path.join(OUT, 'event_gaze.png')
g.save(out, optimize=True)
report.append('event_gaze.png  %s  %d KB' % (g.size, os.path.getsize(out) // 1024))

print('\n'.join(report))
