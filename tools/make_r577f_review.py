# -*- coding: utf-8 -*-
"""R577f 实机验收页：base64 内嵌 HTML + 右栏 3× 放大 + 2×2 对比拼图。

输入全部来自 _preview/ 的带窗口实机截图（非 headless，dummy 渲染器拿不到图）。
产物同样写回 _preview/，保持 untracked。可重跑。
"""
import base64
import io
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = r'E:/work/card_rogue'
OUT = os.path.join(ROOT, '_preview')
# 道具区 Rect2(794,348,338,232)，左右上下各留一点余量
CROP = (780, 330, 1150, 600)
ZOOM = 3

OLD_R314 = 'r577e_before_r314.png'      # R577e 期间拍的旧版（中心亮斑 + 完整硬环）
CASES = [
    ('旧版 R314（R577e）', OLD_R314, '中心亮斑柔光 + 完整青白硬环 + 同相齐闪，图标本体泛青白'),
    ('新版 R314', 'r577f_r314.png', '同一演示口：只剩冷蓝轮廓边 + 暖黄拖尾弧，无圆盘无硬环'),
    ('--relichl 时刻 A', 'r577f_relichl_a.png', '12 件 = 上排 6 亮 / 下排 6 灭，弧角度 A'),
    ('--relichl 时刻 B', 'r577f_relichl_b.png', '同一批道具，弧已转过一段；下排仍保持原色'),
    ('--reliccount 12', 'r577f_count12.png', '按件数自适应排版的 6+6，与高亮互不干扰'),
]


def font(sz):
    for p in ('C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf'):
        if os.path.isfile(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def zoom(name):
    im = Image.open(os.path.join(OUT, name)).convert('RGB')
    c = im.crop(CROP)
    return c.resize((c.width * ZOOM, c.height * ZOOM), Image.LANCZOS)


def data_uri(im_or_path):
    """整页缩到 960x540、统一转 JPEG 内嵌 —— 原 PNG 直塞会让 HTML 涨到 14MB。"""
    if isinstance(im_or_path, str):
        im = Image.open(os.path.join(OUT, im_or_path)).convert('RGB')
        im = im.resize((960, 540), Image.LANCZOS)
    else:
        im = im_or_path.convert('RGB')
    buf = io.BytesIO()
    im.save(buf, format='JPEG', quality=88, optimize=True)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')


def make_compare():
    picks = CASES[:4]
    tiles = [(label, zoom(name), desc) for label, name, desc in picks]
    tw, th = tiles[0][1].size
    gap, top, cap = 18, 40, 34
    w = tw * 2 + gap * 3
    h = (th + cap) * 2 + top + gap * 2
    out = Image.new('RGB', (w, h), (250, 247, 238))
    d = ImageDraw.Draw(out)
    f = font(15)
    for j, (label, tile, desc) in enumerate(tiles):
        ox = gap + (j % 2) * (tw + gap)
        oy = top + (j // 2) * (th + cap + gap)
        d.text((ox + 4, oy - 26), label, font=f, fill=(90, 74, 46))
        out.paste(tile, (ox, oy))
    p = os.path.join(OUT, 'r577f_compare.png')
    out.save(p)
    return p


HTML_TPL = '''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R577f · 暖黄转动弧 + 蓝色边缘光 · 实机验收</title>
<style>
*{box-sizing:border-box}
body{margin:0;padding:20px;background:#faf7ef;color:#3b3226;font:14px/1.6 "Microsoft YaHei",sans-serif}
h1{font-size:19px;font-weight:500;margin:0 0 6px}
.note{color:#7a6d55;font-size:13px;margin:0 0 16px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:16px}
.card{background:#fffdf6;border:1px solid #d8cba9;border-radius:10px;padding:12px}
.card h2{font-size:15px;font-weight:500;margin:0 0 4px}
.card p{font-size:12px;color:#8a7c60;margin:0 0 8px}
.card img{width:100%;display:block;border-radius:6px;margin-bottom:8px}
.tag{display:inline-block;font-size:11px;color:#8a6a2a;background:#f4ead0;border-radius:4px;padding:1px 6px;margin-bottom:8px}
</style></head><body>
<h1>R577f · 单层暖黄转动弧 + 蓝色边缘光（实机）</h1>
<p class="note">带窗口 Godot 1280×720 实拍；每组上半是整页，下半是右栏道具区 3× 放大。转动层保持预览默认「P1 原黄」档，未加深。</p>
<div class="grid">__CARDS__</div>
</body></html>'''

CARD_TPL = '''<div class="card"><h2>__LABEL__</h2><p>__DESC__</p>
<span class="tag">整页 1280×720</span><img src="__FULL__" alt="__LABEL__ 整页">
<span class="tag">右栏道具区 3× 放大</span><img src="__ZOOM__" alt="__LABEL__ 放大"></div>'''


def main():
    cards = []
    for label, name, desc in CASES:
        p = os.path.join(OUT, name)
        if not os.path.isfile(p):
            print('SKIP (missing)', name)
            continue
        z = zoom(name)
        if label.startswith('--relichl 时刻 A'):
            zp = os.path.join(OUT, 'r577f_zoom_relichl.png')
            z.save(zp)
            print('ZOOM', zp, os.path.getsize(zp) // 1024, 'KB')
        cards.append(CARD_TPL.replace('__LABEL__', label)
                     .replace('__DESC__', desc)
                     .replace('__FULL__', data_uri(name))
                     .replace('__ZOOM__', data_uri(z)))
    hp = os.path.join(OUT, 'r577f_review.html')
    with open(hp, 'wb') as f:
        f.write(HTML_TPL.replace('__CARDS__', '\n'.join(cards)).encode('utf-8'))
    print('HTML', hp, os.path.getsize(hp) // 1024, 'KB')
    cp = make_compare()
    print('COMPARE', cp, os.path.getsize(cp) // 1024, 'KB')


if __name__ == '__main__':
    main()
