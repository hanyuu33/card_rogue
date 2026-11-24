# -*- coding: utf-8 -*-
"""R826：吟游诗人卡图区边框 art_frame_bard.png（青碧 · 音律主题）。

复用 R498 边框规范：200x160、中心全透明、最外 1px 有颜色、主环 8px。
"""
import os
from PIL import Image, ImageDraw

ROOT = r"E:\work\card_rogue"
W, H = 200, 160
T = 8

CLEAR = (0, 0, 0, 0)


def ring(col, t=T):
    im = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W - 1, H - 1], outline=col, width=t)
    return im, d


def make_bard():
    main = (31, 143, 138, 255)    # 青碧（= UiTheme.CLASS_BARD 同色 #1f8f8a）
    edge = (10, 55, 53, 255)      # 深青
    lit = (90, 210, 200, 255)     # 亮青
    leaf = (150, 230, 220, 255)   # 浅青

    im, d = ring(main)
    d.rectangle([T, T, W - 1 - T, H - 1 - T], outline=lit, width=1)
    d.rectangle([2, 2, W - 3, H - 3], outline=edge, width=1)

    def note(cx, cy, s, col, ol):
        # 八分音符：左下圆头 + 竖线 + 旗
        d.ellipse([cx - s, cy + int(s * 0.1), cx, cy + int(s * 1.1)],
                  fill=col, outline=ol)
        d.line([(cx, cy + s), (cx, cy - s)], fill=col, width=max(1, s // 2))
        d.line([(cx, cy - s), (cx + int(s * 0.85), cy - int(s * 0.45))],
               fill=col, width=max(1, s // 2))

    # 四角音符
    for cx, cy in [(10, 10), (W - 11, 10), (10, H - 11), (W - 11, H - 11)]:
        note(cx, cy, 7, leaf, edge)

    # 边中点小音符头
    for cx, cy in [(W // 2, 4), (W // 2, H - 5), (4, H // 2), (W - 5, H // 2)]:
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=leaf, outline=edge)

    d.rectangle([0, 0, W - 1, H - 1], outline=(8, 45, 43, 255), width=1)

    p = os.path.join(ROOT, "assets", "ui", "art_frame_bard.png")
    im.save(p)
    a = im.getchannel("A")
    assert a.getpixel((W // 2, H // 2)) == 0, "中心不透明"
    assert a.getpixel((W // 2, 0)) > 200, "上缘透明"
    assert a.getpixel((0, H // 2)) > 200, "左缘透明"
    print("->", p)


make_bard()
print("完成")
