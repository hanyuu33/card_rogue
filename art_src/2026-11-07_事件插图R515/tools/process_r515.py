# -*- coding: utf-8 -*-
"""R515 事件插图处理：裁水印 → 居中裁 4:3 → 640×480 → processed/ + assets/ui/。

水印是后端默认打的「AI生成 WORKBUDDY」，固定在右下角。先测出它的上边界，
再统一从底部切掉，然后居中裁成 4:3（左右各切一点），缩到 640×480。
"""
import os
import sys
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
RAW = os.path.join(ROOT, "art_src", "2026-11-07_事件插图R515", "raw")
PROC = os.path.join(ROOT, "art_src", "2026-11-07_事件插图R515", "processed")
UI = os.path.join(ROOT, "assets", "ui")

# kind -> raw 文件名（按生成时间）
JOBS = [
    ("delivery", "JAPANESE_ANIME_trading_card_il_2026-11-06T23-31-43.png"),
    ("arcane", "JAPANESE_ANIME_trading_card_il_2026-11-06T23-32-03.png"),
    ("lake_lady", "JAPANESE_ANIME_trading_card_il_2026-11-06T23-32-19.png"),
]

TARGET = (640, 480)


def watermark_top(im):
    """在右下角 220×110 区域里找高亮近白像素的最高行，返回水印上边界 y。"""
    w, h = im.size
    box = im.convert("RGB").crop((w - 220, h - 110, w, h))
    px = box.load()
    top = None
    for y in range(box.size[1]):
        cnt = 0
        for x in range(box.size[0]):
            r, g, b = px[x, y]
            if r > 232 and g > 232 and b > 232:
                cnt += 1
        if cnt >= 6:
            top = y
            break
    return None if top is None else (h - 110) + top


# 水印固定落在 y≈728~760。统一保留到 706：三张切得一样高，
# 不用逐张检测 —— lake_lady 的白色花瓣会把检测顶到 y=673，多切 39px。
KEEP_H = 706


def crop_wm(im):
    w, h = im.size
    y = watermark_top(im)
    print("  水印检测上边界 y=%s（仅日志；实际统一保留到 %d）" % (y, KEEP_H))
    return im.crop((0, 0, w, min(KEEP_H, h))), y, KEEP_H


def to_ratio(im, ratio=(4, 3)):
    w, h = im.size
    want = ratio[0] / ratio[1]
    cur = w / h
    if cur > want:          # 太宽 → 切左右
        nw = int(round(h * want))
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(round(w / want))   # 太高 → 切上下
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def main():
    os.makedirs(PROC, exist_ok=True)
    for kind, fname in JOBS:
        src = os.path.join(RAW, fname)
        im = Image.open(src).convert("RGB")
        print("[%s] 原图 %s" % (kind, im.size))
        im2, wy, cut = crop_wm(im)
        print("  水印上边界 y=%s → 切到 %d" % (wy, cut))
        im3 = to_ratio(im2)
        out = im3.resize(TARGET, Image.LANCZOS)
        # 小尺寸下补一点锐度（LANCZOS 缩放后会略肉）
        out = out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=55, threshold=2))
        p_proc = os.path.join(PROC, "event_%s.png" % kind)
        out.save(p_proc, "PNG", optimize=True)
        p_ui = os.path.join(UI, "event_%s.png" % kind)
        out.save(p_ui, "PNG", optimize=True)
        print("  → %s / %s  尺寸 %s" % (os.path.basename(p_proc), os.path.basename(p_ui), out.size))

    # 右下角再抽查一次（缩小后不该有任何白字）
    for kind, _ in JOBS:
        p = os.path.join(UI, "event_%s.png" % kind)
        im = Image.open(p).convert("RGB")
        crop = im.crop((im.size[0] - 120, im.size[1] - 40, im.size[0], im.size[1]))
        px = crop.load()
        cnt = 0
        for y in range(crop.size[1]):
            for x in range(crop.size[0]):
                r, g, b = px[x, y]
                if r > 240 and g > 240 and b > 240:
                    cnt += 1
        print("抽查 %s 右下角近白像素 %d（水印残留判断用，光照高光也会计入）" % (kind, cnt))


if __name__ == "__main__":
    sys.exit(main())
