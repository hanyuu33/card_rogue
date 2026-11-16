# -*- coding: utf-8 -*-
"""R768 配色试验：同一个火柴人剪影，只换「底 / 图」两色，并排比。

为什么要单独做这一步：
    原图是「深紫底 + 纯黑剪影」，实测糊成一团 —— 交通标志象形图的可读性来自
    **高明度底 + 低明度图**，白盘被换掉后必须同时把剪影提亮，只换底色等于把对比度
    一起换没了。所以配色要成对定，不能只定底。

做法：像素级重映射，不动构图。
    · 背景通道 = 四边中位色；前景通道 = 面积第二大的低饱和色（黑剪影）
    · 每个像素按「到背景距离 / (到背景距离 + 到前景距离)」做软插值 -> 抗锯齿边缘不出锯齿
    · **高饱和像素原样保留** —— 麻痹的黄闪电 / 破绽的青裂缝 / 代偿的灰石不能跟着变色

用法：
    python _recolor.py regret_v2
    python _recolor.py regret_v2 paralysis compensation flaw
"""
import sys
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-16_诅咒火柴人_R768"
PROC = D / "processed"
OUT = D / "recolor"

# 方案 = (代号, 说明, 底色, 图色)
# ⚠️ 不能只挑「好看的两色」。四张卡里三张带第三个颜色（青裂缝 / 黄闪电 / 灰石块），
#    符号色是原样保留的，所以**底色和剪影色必须留出符号的生存空间**：
#    · 破绽的青白裂缝 (#DFF7FA) 在白/亮剪影上约 1.0:1 —— 直接消失，那一片就白画了
#    · 代偿的灰石块 (#8C8C96) 同理，压在浅剪影上也糊
#    结论：**剪影必须深、底必须亮**，也就是回到交通标志原本的对比关系。
# 店长反馈「紫色太深、容易看不清」后，保留「亮紫底 + 墨黑剪影」这一层关系
# （只有它能让青裂缝 / 黄闪电 / 灰石头三类符号同时活着），只把底色亮度往上推四档。
# F = 原方案，作对照基准；G/H/I/J 依次更亮，图色同步微调以保持墨黑层次。
SCHEMES = [
    ("F", "紫底 + 墨黑图", (0x9A, 0x7B, 0xC4), (0x12, 0x0C, 0x18)),
    ("G", "亮紫底 + 墨黑图", (0xAE, 0x92, 0xD2), (0x14, 0x0D, 0x1C)),
    ("H", "浅紫底 + 墨黑图", (0xC2, 0xAA, 0xE0), (0x16, 0x0F, 0x20)),
    ("I", "淡紫底 + 墨黑图", (0xD5, 0xC2, 0xEE), (0x18, 0x0F, 0x22)),
    ("J", "藕荷底 + 墨黑图", (0xE6, 0xDB, 0xF6), (0x1A, 0x11, 0x24)),
]


def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lum(rgb):
    r, g, b = (_lin(v) for v in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def sat(rgb):
    r, g, b = rgb[:3]
    mx, mn = max(r, g, b), min(r, g, b)
    return 0 if mx == 0 else (mx - mn) / float(mx)


def border_color(im):
    w, h = im.size
    px = im.load()
    pts = []
    step = max(1, w // 40)
    for x in range(0, w, step):
        pts += [px[x, 0], px[x, h - 1]]
    for y in range(0, h, step):
        pts += [px[0, y], px[w - 1, y]]
    ch = []
    for c in range(3):
        v = sorted(p[c] for p in pts)
        ch.append(v[len(v) // 2])
    return tuple(ch)


def fg_color(im, bg):
    """**最暗的**低饱和色 = 火柴人剪影。

    不能取「面积最大的低饱和色」：代偿那张里灰石块比剪影还大，会把它选成前景，
    结果石头被染成剪影色、人反而被保留成原色 —— 画面直接反过来。
    剪影在原始图里一定是黑，所以按亮度取最暗的那个，面积只是用来过滤噪声。
    """
    cnt = Counter()
    for p in im.getdata():
        if sat(p) > 0.35:
            continue
        q = (p[0] // 8 * 8, p[1] // 8 * 8, p[2] // 8 * 8)
        if abs(q[0] - bg[0]) + abs(q[1] - bg[1]) + abs(q[2] - bg[2]) < 30:
            continue
        cnt[q] += 1
    if not cnt:
        return (0, 0, 0)
    floor = im.width * im.height * 0.005
    cands = [(c, n) for c, n in cnt.items() if n >= floor] or list(cnt.items())
    cands.sort(key=lambda t: (lum(t[0]), -t[1]))
    return cands[0][0]


def remap(im, new_bg, new_fg):
    bg = border_color(im)
    fg = fg_color(im, bg)
    src = im.load()
    out = Image.new("RGBA", im.size, (0, 0, 0, 255))
    dst = out.load()
    keep = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = src[x, y]
            db = ((r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2) ** 0.5
            df = ((r - fg[0]) ** 2 + (g - fg[1]) ** 2 + (b - fg[2]) ** 2) ** 0.5
            # 「第三种颜色」= 离底色和前景色都远（黄闪电 / 青裂缝 / 灰石块）。
            # ⚠️ 不能用「饱和度 > x」判：近黑噪点 (1,0,0) 饱和度是 1.0，
            #    一提亮就变成满身黑芝麻 —— R768 第一版就是这么糊的。
            if db > 60 and df > 60:
                dst[x, y] = (r, g, b, a)
                keep += 1
                continue
            t = 0.0 if (db + df) == 0 else db / (db + df)
            dst[x, y] = (
                int(round(new_bg[0] + (new_fg[0] - new_bg[0]) * t)),
                int(round(new_bg[1] + (new_fg[1] - new_bg[1]) * t)),
                int(round(new_bg[2] + (new_fg[2] - new_bg[2]) * t)),
                255,
            )
    return out, bg, fg


def hexs(rgb):
    return "#%02X%02X%02X" % rgb[:3]


def main(keys):
    OUT.mkdir(parents=True, exist_ok=True)
    report = []
    for key in keys:
        src = next(PROC.glob("card_*_%s.png" % key), None)
        if src is None:
            print("跳过 %s（processed 里没有）" % key)
            continue
        im = Image.open(src).convert("RGBA")
        made = []
        for code, desc, bg, fg in SCHEMES:
            out, obg, ofg = remap(im, bg, fg)
            p = OUT / ("%s_%s.png" % (key, code))
            out.save(p)
            cr = contrast(bg, fg)
            made.append((code, desc, bg, fg, cr, p))
            print("%-13s %s %-22s 底%s 图%s 对比 %.1f:1" % (
                key, code, desc, hexs(bg), hexs(fg), cr))
        report.append((key, made))
    if not report:
        return 1

    # 对比页：每行一张卡，每列一个配色；底部标对比度
    rows_html = []
    for key, made in report:
        cells = "".join(
            '<figure><img src="%s"><figcaption><b>%s</b> %s<br>%s / %s<br>'
            '<span class="%s">对比 %.1f:1</span></figcaption></figure>' % (
                p.as_posix(), c, d, hexs(b), hexs(f), "good" if cr >= 4.5 else "warn", cr)
            for c, d, b, f, cr, p in made)
        rows_html.append('<section class="cell"><h2>%s</h2><div class="row">%s</div></section>'
                         % (key, cells))

    html = """<!doctype html><meta charset="utf-8">
<title>R768 配色试验</title>
<style>
 body{margin:0;padding:26px;background:#1b1420;color:#efe7f3;
      font:14px/1.6 "Microsoft YaHei",system-ui,sans-serif}
 h1{font-size:19px;margin:0 0 6px}
 .lead{color:#b9a9c4;margin:0 0 18px}
 .hint{background:#2d2136;border-left:3px solid #9a6fbd;padding:10px 14px;border-radius:6px;
       color:#cfc0d9;margin:0 0 22px;font-size:13px}
 .cell{background:#241b2b;border:1px solid #3a2c44;border-radius:14px;padding:16px 18px;margin:0 0 18px}
 .cell h2{font-size:14px;margin:0 0 12px;letter-spacing:.5px;color:#cdb9dd}
 .row{display:flex;gap:16px;flex-wrap:wrap}
 figure{margin:0;text-align:center;width:172px}
 figure img{display:block;width:172px;border-radius:6px;box-shadow:0 3px 14px rgba(0,0,0,.5)}
 figcaption{color:#a596b0;font-size:11.5px;margin-top:7px;line-height:1.55}
 .good{color:#8fd6a0}.warn{color:#e8b96a}
</style>
<h1>R768 配色试验 — 同一个火柴人，只换底/图两色</h1>
<p class="lead">底色的白被换掉之后，「图色」必须同时调亮，否则对比度一起没了。</p>
<p class="hint">对比度按 WCAG 算：<b>≥4.5:1</b> 才算小尺寸可读。
卡图会缩到约 150px 宽看，低于这条线的在小图上会糊。</p>
%s
""" % ("".join(rows_html))
    p = OUT / "schemes.html"
    p.write_text(html, encoding="utf-8", newline="\n")
    print("配色页 ->", p)
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        args = [f.stem.replace("card_", "").rsplit("_", 1)[-1] for f in PROC.glob("card_*.png")]
    raise SystemExit(main(args))
