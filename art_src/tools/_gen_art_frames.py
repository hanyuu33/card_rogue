# -*- coding: utf-8 -*-
"""R498：卡图区窄边框素材生成（五类归属）。

输出：assets/ui/art_frame_<kind>.png  （kind = forest / shadow / mech / common / enemy）
画幅：200 x 160（= 卡图窗宽高比 1.25，绘制时整张拉伸到卡图区，**不是九宫格**）

设计约束（改图时必须守住，否则运行时会出问题）：
1. **中心必须全透明** —— 这张图盖在卡图之上，中心有任何底色都会遮住卡图。
2. **最外 1px 必须有颜色** —— 卡图区是「出血到卡边」的，边框外缘留透明会在
   纸底上露出一条缝。
3. **画幅比例 1.25** —— 卡图区宽高比 = rect.w / (rect.h * 0.662)，所有调用方
   都约等于 1.244~1.255；素材按这个比例画，拉伸时几乎不变形。
4. 边框**薄**：主环厚度 10px / 200 宽 = 5%，观感是「细线 + 角落小装饰」。
   装饰最多向卡图内探 6px（2%），别做大块花纹。

用法：python _gen_art_frames.py [--preview]
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = r'D:/work/card_rogue'
OUT_DIR = os.path.join(ROOT, 'assets/ui')
PREVIEW_DIR = r'D:/work/gen_raw/r498'

W, H = 200, 160
T = 8           # 主环厚度
CORNER = 30     # 角落装饰的避让区（沿边方向）

CLEAR = (0, 0, 0, 0)


# ---------------------------------------------------------------- 基础工具

def new_layer():
    return Image.new('RGBA', (W, H), CLEAR)


def ring(col, t=T):
    im = new_layer()
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W - 1, H - 1], outline=col, width=t)
    return im, d


def leaf_pts(cx, cy, ln, wd, ang):
    """叶形：沿主轴 ln、最大半宽 wd 的尖椭圆，绕中心转 ang 弧度。"""
    pts = []
    n = 14
    for i in range(n + 1):
        u = i / n
        v = wd * math.sin(math.pi * u) ** 0.75
        pts.append((u * ln - ln / 2.0, v))
    for i in range(n, -1, -1):
        u = i / n
        v = wd * math.sin(math.pi * u) ** 0.75
        pts.append((u * ln - ln / 2.0, -v))
    ca, sa = math.cos(ang), math.sin(ang)
    return [(cx + p[0] * ca - p[1] * sa, cy + p[0] * sa + p[1] * ca) for p in pts]


def overlay_outline(im, col):
    """最外 1px 描边（保证拉伸后边缘不透明、有轮廓）。"""
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W - 1, H - 1], outline=col, width=1)


def save(im, name):
    p = os.path.join(OUT_DIR, name)
    im.save(p)
    a = im.getchannel('A')
    # 自检：中心透明 / 外缘不透明
    assert a.getpixel((W // 2, H // 2)) == 0, '%s 中心不透明！会遮住卡图' % name
    assert a.getpixel((W // 2, 0)) > 200, '%s 上缘透明！' % name
    assert a.getpixel((0, H // 2)) > 200, '%s 左缘透明！' % name
    print('  -> %-26s %d x %d' % (name, im.size[0], im.size[1]))


# ---------------------------------------------------------------- 森林精魄

def make_forest():
    """藤蔓 + 绿叶：深绿环，环上一条亮绿藤蔓，沿藤蔓挂小叶，四角一簇三叶。"""
    main = (44, 82, 51, 255)
    edge = (16, 30, 19, 255)
    vine = (104, 150, 62, 255)
    leaf_a = (128, 176, 74, 255)
    leaf_b = (158, 199, 96, 255)

    im, d = ring(main)
    # 内缘压线
    d.rectangle([T, T, W - 1 - T, H - 1 - T], outline=edge, width=1)

    mid = (T - 1) / 2.0          # 环中线（藤蔓基线）
    amp = 2.0

    def wave_h(y_base, x0, x1, phase):
        pts = []
        for x in range(int(x0), int(x1) + 1):
            t = (x - x0) / 13.0
            pts.append((x, y_base + amp * math.sin(t + phase)))
        return pts

    def wave_v(x_base, y0, y1, phase):
        pts = []
        for y in range(int(y0), int(y1) + 1):
            t = (y - y0) / 13.0
            pts.append((x_base + amp * math.sin(t + phase), y))
        return pts

    segs = [
        (wave_h(mid, CORNER, W - CORNER, 0.0), 'h'),
        (wave_h(H - 1 - mid, CORNER, W - CORNER, math.pi), 'h'),
        (wave_v(mid, CORNER, H - CORNER, math.pi / 2), 'v'),
        (wave_v(W - 1 - mid, CORNER, H - CORNER, -math.pi / 2), 'v'),
    ]
    for pts, _o in segs:
        d.line(pts, fill=vine, width=2, joint='curve')

    # 叶片：沿藤蔓每 ~24px 一片，交替上下
    for pts, orient in segs:
        flip = 1
        for i in range(8, len(pts) - 8, 30):
            x, y = pts[i]
            if orient == 'h':
                ang = math.radians(28 * flip)
            else:
                ang = math.radians(90 + 28 * flip)
            col = leaf_a if flip > 0 else leaf_b
            d.polygon(leaf_pts(x, y, 9.0, 2.8, ang), fill=col,
                      outline=(22, 46, 26, 255))
            flip = -flip

    # 四角：三片叶成簇（略向卡内探，把直角软化）
    for cx, cy, base in [(4, 4, 45), (W - 5, 4, 135),
                         (4, H - 5, -45), (W - 5, H - 5, -135)]:
        for k, (dl, dw, da, cc) in enumerate([
                (15.0, 4.0, 0.0, leaf_b),
                (13.0, 3.4, 38.0, leaf_a),
                (13.0, 3.4, -38.0, leaf_a)]):
            d.polygon(leaf_pts(cx, cy, dl, dw, math.radians(base + da)), fill=cc,
                      outline=(18, 38, 22, 255))
        d.ellipse([cx - 1.8, cy - 1.8, cx + 1.8, cy + 1.8], fill=(196, 224, 140, 255))

    overlay_outline(im, (11, 21, 13, 255))
    save(im, 'art_frame_forest.png')


# ---------------------------------------------------------------- 暗影刺客

def make_shadow():
    """黑影：近黑环，内缘撕裂成雾齿，四角尖爪。"""
    main = (20, 18, 28, 255)
    edge = (8, 7, 12, 255)
    mist = (44, 34, 60, 255)
    glow = (64, 50, 86, 255)

    im, d = ring(main)
    rnd = random.Random(498)
    inner = T

    # 内缘雾齿：沿四边随机三角，朝卡内探 0~5px
    def teeth_h(y, direction, x0, x1):
        x = x0
        while x < x1:
            wgt = rnd.randint(5, 12)
            dep = rnd.choice([0, 1, 2, 3, 4, 3, 2])
            if dep:
                d.polygon([(x, y), (x + wgt, y), (x + wgt / 2.0, y + dep * direction)],
                          fill=mist if rnd.random() < 0.7 else glow)
            x += wgt + rnd.randint(2, 7)

    teeth_h(inner, 1, CORNER - 8, W - CORNER + 8)
    teeth_h(H - 1 - inner, -1, CORNER - 8, W - CORNER + 8)

    def teeth_v(x, direction, y0, y1):
        y = y0
        while y < y1:
            hgt = rnd.randint(5, 12)
            dep = rnd.choice([0, 1, 2, 3, 4, 3, 2])
            if dep:
                d.polygon([(x, y), (x, y + hgt), (x + dep * direction, y + hgt / 2.0)],
                          fill=mist if rnd.random() < 0.7 else glow)
            y += hgt + rnd.randint(2, 7)

    teeth_v(inner, 1, CORNER - 8, H - CORNER + 8)
    teeth_v(W - 1 - inner, -1, CORNER - 8, H - CORNER + 8)

    # 外缘随机凸起（烟雾撕开的感觉）
    for _i in range(90):
        if rnd.random() < 0.5:
            x = rnd.randrange(4, W - 4)
            y = rnd.choice([0, 1])
            d.rectangle([x, y, x + rnd.randint(0, 2), y + rnd.randint(0, 1)], fill=edge)
        else:
            x = rnd.choice([0, 1])
            y = rnd.randrange(4, H - 4)
            d.rectangle([x, y, x + rnd.randint(0, 1), y + rnd.randint(0, 2)], fill=edge)

    # 四角尖爪：沿对角线朝卡内
    for cx, cy in [(0, 0), (W, 0), (0, H), (W, H)]:
        sx = 1 if cx == 0 else -1
        sy = 1 if cy == 0 else -1
        d.polygon([(cx, cy),
                   (cx + sx * 22, cy + sy * 4),
                   (cx + sx * 4, cy + sy * 22)],
                  fill=(12, 10, 17, 255))
        d.polygon([(cx + sx * 1, cy + sy * 1),
                   (cx + sx * 14, cy + sy * 3),
                   (cx + sx * 3, cy + sy * 14)],
                  fill=glow if False else (34, 27, 48, 255))

    overlay_outline(im, (4, 3, 6, 220))
    save(im, 'art_frame_shadow.png')


# ---------------------------------------------------------------- 机械之心

def make_mech():
    """齿轮：铜色环，内缘一圈方齿，四角螺栓 + 边中点铆钉。"""
    main = (122, 92, 51, 255)
    tooth = (156, 120, 66, 255)
    edge = (54, 38, 19, 255)
    bolt = (201, 163, 92, 255)
    bolt_d = (72, 54, 26, 255)

    im, d = ring(main)

    # 内缘方齿（朝卡内凸 4px）
    def teeth_h(y, direction):
        step = 27
        x = CORNER - 6
        while x < W - CORNER + 6:
            d.rectangle([x, min(y, y + 3 * direction), x + 9,
                         max(y, y + 3 * direction)], fill=tooth)
            d.rectangle([x, min(y, y + 3 * direction), x + 9,
                         max(y, y + 3 * direction)], outline=edge)
            x += step

    teeth_h(T, 1)
    teeth_h(H - 1 - T, -1)

    def teeth_v(x, direction):
        step = 27
        y = CORNER - 6
        while y < H - CORNER + 6:
            d.rectangle([min(x, x + 3 * direction), y,
                         max(x, x + 3 * direction), y + 9], fill=tooth)
            d.rectangle([min(x, x + 3 * direction), y,
                         max(x, x + 3 * direction), y + 9], outline=edge)
            y += step

    teeth_v(T, 1)
    teeth_v(W - 1 - T, -1)

    # 内缘压线
    d.rectangle([T, T, W - 1 - T, H - 1 - T], outline=edge, width=1)

    # 四角螺栓
    for cx, cy in [(10, 10), (W - 11, 10), (10, H - 11), (W - 11, H - 11)]:
        d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=bolt, outline=edge)
        d.ellipse([cx - 2.6, cy - 2.6, cx + 2.6, cy + 2.6], fill=bolt_d)
        for dx, dy in [(-4.5, 0), (4.5, 0), (0, -4.5), (0, 4.5)]:
            d.line([(cx + dx * 0.55, cy + dy * 0.55), (cx + dx, cy + dy)],
                   fill=edge, width=1)

    # 边中点铆钉
    for cx, cy in [(W // 2, 4), (W // 2, H - 5), (4, H // 2), (W - 5, H // 2)]:
        d.ellipse([cx - 3.0, cy - 3.0, cx + 3.0, cy + 3.0], fill=bolt, outline=edge)

    overlay_outline(im, (38, 26, 12, 255))
    save(im, 'art_frame_mech.png')


# ---------------------------------------------------------------- 公用

def make_common():
    """白色细框：白环 + 灰外缘/内缘 + 环中线 + 四角小菱形。"""
    main = (246, 249, 252, 255)
    mid = (211, 219, 229, 255)
    edge_o = (116, 126, 140, 255)
    edge_i = (166, 176, 188, 255)

    im, d = ring(main, t=7)
    d.rectangle([7, 7, W - 1 - 7, H - 1 - 7], outline=edge_i, width=1)
    d.rectangle([3, 3, W - 4, H - 4], outline=mid, width=1)

    # 四角小菱形
    for cx, cy in [(8, 8), (W - 9, 8), (8, H - 9), (W - 9, H - 9)]:
        d.polygon([(cx, cy - 6), (cx + 6, cy), (cx, cy + 6), (cx - 6, cy)],
                  fill=main, outline=edge_o)

    overlay_outline(im, edge_o)
    save(im, 'art_frame_common.png')


# ---------------------------------------------------------------- 敌人

def make_enemy():
    """红色框：暗红环 + 亮内缘 + 四角尖刺 + 边中点小三角。"""
    main = (138, 28, 28, 255)
    dark = (72, 12, 12, 255)
    lit = (214, 74, 60, 255)

    im, d = ring(main)
    d.rectangle([T, T, W - 1 - T, H - 1 - T], outline=lit, width=1)
    d.rectangle([2, 2, W - 3, H - 3], outline=dark, width=1)

    # 四角尖刺（沿对角线朝卡内）
    for cx, cy in [(0, 0), (W, 0), (0, H), (W, H)]:
        sx = 1 if cx == 0 else -1
        sy = 1 if cy == 0 else -1
        d.polygon([(cx + sx * 3, cy + sy * 3),
                   (cx + sx * 22, cy + sy * 3),
                   (cx + sx * 3, cy + sy * 22)], fill=lit)
        d.polygon([(cx + sx * 3, cy + sy * 3),
                   (cx + sx * 16, cy + sy * 3),
                   (cx + sx * 3, cy + sy * 16)], fill=main)

    # 边中点朝内小三角
    for cx, cy, dx, dy in [(W // 2, T, 0, 1), (W // 2, H - 1 - T, 0, -1),
                           (T, H // 2, 1, 0), (W - 1 - T, H // 2, -1, 0)]:
        d.polygon([(cx - 5, cy), (cx + 5, cy), (cx, cy + dy * 4 if dy else cy + 4)],
                  fill=lit)

    overlay_outline(im, dark)
    save(im, 'art_frame_enemy.png')


# ---------------------------------------------------------------- 预览合成

def _fit_cover(img, w, h):
    iw, ih = img.size
    s = max(w / iw, h / ih)
    r = img.resize((max(1, int(iw * s + 0.5)), max(1, int(ih * s + 0.5))), Image.LANCZOS)
    x = (r.size[0] - w) // 2
    y = (r.size[1] - h) // 2
    return r.crop((x, y, x + w, y + h))


def preview():
    """把边框贴到真实卡图 + 纸底上，按两种实际尺寸输出对比图。"""
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    paper = Image.open(os.path.join(OUT_DIR, 'card_paper.png')).convert('RGBA')
    ratio = 0.662
    samples = [
        ('forest', 8003, '树人'),
        ('shadow', 8005, '幽影'),
        ('mech', 8025, '素体'),
        ('common', 8001, '木栅栏'),
        ('enemy', 1011, '铁壁卫兵'),
    ]
    for size in [(216, 260), (58, 70)]:
        cw, ch = size
        gap = 10
        sheet = Image.new('RGBA', (len(samples) * (cw + gap) + gap,
                                   ch + gap * 2 + 16), (34, 36, 42, 255))
        d = ImageDraw.Draw(sheet)
        for i, (kind, cid, name) in enumerate(samples):
            card = Image.new('RGBA', size, CLEAR)
            card.alpha_composite(paper.resize(size, Image.LANCZOS))
            box_h = int(round(ch * ratio))
            art = Image.open(os.path.join(ROOT, 'assets/pics/%d.png' % cid)).convert('RGBA')
            card.paste(_fit_cover(art, cw, box_h), (0, 0))
            fr = Image.open(os.path.join(OUT_DIR, 'art_frame_%s.png' % kind)).convert('RGBA')
            card.alpha_composite(fr.resize((cw, box_h), Image.LANCZOS), (0, 0))
            # 文字区占位条
            d.rectangle([cw * i + gap * (i + 1) + 2, box_h + 3,
                         cw * i + gap * (i + 1) + cw - 2,
                         ch - 4], fill=(74, 62, 48, 255))
            sheet.alpha_composite(card, (gap * (i + 1) + cw * i, gap))
            d.text((gap * (i + 1) + cw * i + 4, ch + gap + 2), '%s(%d)' % (kind, cid),
                   fill=(210, 216, 224, 255))
        out = os.path.join(PREVIEW_DIR, '_preview_%dx%d.png' % (cw, ch))
        sheet.save(out)
        print('  preview ->', out)


if __name__ == '__main__':
    print('生成卡图边框素材：')
    make_forest()
    make_shadow()
    make_mech()
    make_common()
    make_enemy()
    if '--preview' in sys.argv:
        preview()
    print('完成。')
