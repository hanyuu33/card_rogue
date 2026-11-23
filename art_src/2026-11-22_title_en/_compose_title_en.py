# -*- coding: utf-8 -*-
"""英文版主视觉合成：无字背景 + 立体奶油 QUACKILL → assets/ui/title_art_en.png

三种字形（--font）：
  black = Arial Black 超粗 + 奶油立体渲染（默认，最接近中文手绘卡通字）
  sans  = 微软雅黑粗体 + 原版金渐变（备选）
  serif = NotoSerif 900 + 原版金渐变（备选，偏古典）

R607 口径：**全游戏不设副标题** —— QUACKILL 是主标题本体，只有一行。

立体奶油渲染 = 顶部奶油白高光 + 中段暖金渐变 + 底部暖棕内阴影 + 深棕厚描边 + 外柔影，
对应中文 title_art 里那四个字的层次，不是简单给黑体刷个渐变。

用法：
    python _compose_title_en.py                 # Arial Black + 奶油立体
    python _compose_title_en.py --font sans
    python _compose_title_en.py --font serif
"""
import argparse
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(ROOT, "assets", "ui")
D = os.path.join(ROOT, "art_src", "2026-11-22_title_en")
RAW = os.path.join(D, "raw", "bg_title_en.png")

ART_W, ART_H = 1920, 1080
SAFE_W = 0.80           # 标题最宽占画面 80%，两侧留呼吸
TITLE_CY = 300          # 标题中心纵向位置（与中文版一致）
TRACK_RATIO = 0.030     # 英文连写，字距只做轻微松开

SERIF = r"C:\Windows\Fonts\NotoSerifSC-VF.ttf"
SANS = r"C:\Windows\Fonts\msyhbd.ttc"
BLACK = r"C:\Windows\Fonts\ariblk.ttf"

GOLD = [(255, 242, 202), (246, 216, 140), (230, 190, 100), (172, 118, 36)]
DARK = (40, 24, 10)

# 奶油立体：上白 → 暖金 → 底橙棕
CREAM = [
    (0.00, (255, 253, 244)),
    (0.13, (255, 247, 214)),
    (0.34, (249, 221, 150)),
    (0.60, (230, 187, 100)),
    (0.84, (194, 135, 50)),
    (1.00, (146, 88, 26)),
]
STROKE_DARK = (54, 29, 12)


def load_font(path, size, weight=None):
    f = ImageFont.truetype(path, size)
    if weight is not None:
        try:
            f.set_variation_by_axes([weight])
        except Exception:                                     # noqa: BLE001
            pass
    return f


def _metrics(text, font, tracking):
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + tracking * max(0, len(text) - 1)
    asc, desc = font.getmetrics()
    return widths, total, asc + desc


def _draw_line(draw, text, font, x, y, tracking, fill, stroke=0, stroke_fill=None, dys=None):
    for i, ch in enumerate(text):
        dy = 0.0 if dys is None else dys[i]
        draw.text((x, y + dy), ch, font=font, fill=fill, stroke_width=stroke,
                  stroke_fill=stroke_fill if stroke_fill is not None else fill)
        x += font.getlength(ch) + tracking


def _vertical_gradient(stops, w, h):
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    n = len(stops) - 1
    for y in range(h):
        t = y / max(1, h - 1)
        i = 0
        while i < n - 1 and t > stops[i + 1][0]:
            i += 1
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        k = 0.0 if t1 <= t0 else max(0.0, min(1.0, (t - t0) / (t1 - t0)))
        c = tuple(int(c0[j] + (c1[j] - c0[j]) * k) for j in range(3))
        d.line([(0, y), (w, y)], fill=c + (255,))
    return img


def _masks(text, font, tracking, stroke, ss, dys=None):
    widths, total, line_h = _metrics(text, font, tracking)
    pad = stroke + 12
    W = int(total + pad * 2)
    H = int(line_h + pad * 2)
    big = ImageFont.truetype(font.path, font.size * ss)
    try:
        big.set_variation_by_axes([900])
    except Exception:                                         # noqa: BLE001
        pass
    dd = None if dys is None else [d * ss for d in dys]
    outline = Image.new("L", (W * ss, H * ss), 0)
    core = Image.new("L", (W * ss, H * ss), 0)
    _draw_line(ImageDraw.Draw(outline), text, big, pad * ss, pad * ss, tracking * ss,
               255, stroke=stroke * ss, dys=dd)
    _draw_line(ImageDraw.Draw(core), text, big, pad * ss, pad * ss, tracking * ss, 255, dys=dd)
    return outline, core, W, H


def render_gold_text(text, font, tracking=0.0, stroke=6, ss=2):
    """R604 原版：金渐变 + 深棕描边 + 柔影。"""
    outline, core, W, H = _masks(text, font, tracking, stroke, ss)
    out = Image.new("RGBA", core.size, (0, 0, 0, 0))

    shadow = outline.filter(ImageFilter.GaussianBlur(7 * ss)).point(lambda v: int(v * 0.55))
    sh = Image.new("RGBA", out.size, DARK + (0,))
    sh.putalpha(shadow)
    out.alpha_composite(sh, (2 * ss, 5 * ss))

    edge = Image.new("RGBA", out.size, DARK + (0,))
    edge.putalpha(outline)
    out.alpha_composite(edge)

    grad = _vertical_gradient([(i / (len(GOLD) - 1), c) for i, c in enumerate(GOLD)],
                              out.size[0], out.size[1])
    fill = Image.new("RGBA", out.size, (0, 0, 0, 0))
    fill.paste(grad, (0, 0), core)
    out.alpha_composite(fill)
    return out.resize((W, H), Image.LANCZOS)


def render_cream_text(text, font, tracking=0.0, stroke=6, ss=2, dys=None):
    """奶油立体：高光 + 暖金渐变 + 内白亮边 + 底部内阴影 + 深棕厚描边 + 外柔影。"""
    outline, core, W, H = _masks(text, font, tracking, stroke, ss, dys)
    hh = core.size[1]
    out = Image.new("RGBA", core.size, (0, 0, 0, 0))

    shadow = outline.filter(ImageFilter.GaussianBlur(8 * ss)).point(lambda v: int(v * 0.52))
    sh = Image.new("RGBA", out.size, STROKE_DARK + (0,))
    sh.putalpha(shadow)
    out.alpha_composite(sh, (2 * ss, 6 * ss))

    edge = Image.new("RGBA", out.size, STROKE_DARK + (0,))
    edge.putalpha(outline)
    out.alpha_composite(edge)

    grad = _vertical_gradient(CREAM, out.size[0], hh)
    fill = Image.new("RGBA", out.size, (0, 0, 0, 0))
    fill.paste(grad, (0, 0), core)
    out.alpha_composite(fill)

    # 内白亮边：贴着笔画内侧一圈更亮的奶油白，中文那四个字都有这层
    er = core.filter(ImageFilter.MinFilter(5))
    ring = ImageChops.subtract(core, er)
    ring = ring.filter(ImageFilter.GaussianBlur(1.1 * ss)).point(lambda v: int(v * 0.52))
    wl = Image.new("RGBA", out.size, (255, 255, 250, 0))
    wl.putalpha(ring)
    out.alpha_composite(wl)

    band_hi = Image.new("L", out.size, 0)
    ImageDraw.Draw(band_hi).rectangle([0, 0, out.size[0], int(hh * 0.30)], fill=255)
    band_hi = band_hi.filter(ImageFilter.GaussianBlur(6 * ss))
    hi_mask = ImageChops.multiply(core, band_hi).point(lambda v: int(v * 0.66))
    hi = Image.new("RGBA", out.size, (255, 255, 248, 0))
    hi.putalpha(hi_mask)
    out.alpha_composite(hi)

    band_lo = Image.new("L", out.size, 0)
    ImageDraw.Draw(band_lo).rectangle([0, int(hh * 0.78), out.size[0], hh], fill=255)
    band_lo = band_lo.filter(ImageFilter.GaussianBlur(5 * ss))
    lo_mask = ImageChops.multiply(core, band_lo).point(lambda v: int(v * 0.42))
    lo = Image.new("RGBA", out.size, (118, 62, 16, 0))
    lo.putalpha(lo_mask)
    out.alpha_composite(lo)

    return out.resize((W, H), Image.LANCZOS)


def fit_cover(im, w, h):
    w0, h0 = im.size
    s = max(w / w0, h / h0)
    im2 = im.resize((max(1, int(w0 * s + 0.5)), max(1, int(h0 * s + 0.5))), Image.LANCZOS)
    x = (im2.size[0] - w) // 2
    y = (im2.size[1] - h) // 2
    return im2.crop((x, y, x + w, y + h))


def pick_size(font_path, text, max_w, weight):
    max_w = max_w * SAFE_W
    for size in range(330, 60, -4):
        f = load_font(font_path, size, weight)
        _, total, _ = _metrics(text, f, size * TRACK_RATIO)
        if total <= max_w:
            return size
    return 60


def build(font_choice, wobble=True):
    if not os.path.exists(RAW):
        raise SystemExit("缺背景图：%s（先跑 _run_codex.py）" % RAW)
    base = fit_cover(Image.open(RAW).convert("RGB"), ART_W, ART_H).convert("RGBA")

    text = "QUACKILL"
    if font_choice == "black":
        fpath, weight, renderer = BLACK, None, render_cream_text
        stroke_div = 17
    elif font_choice == "serif":
        fpath, weight, renderer = SERIF, 900, render_gold_text
        stroke_div = 16
    else:
        fpath, weight, renderer = SANS, 900, render_gold_text
        stroke_div = 16

    size = pick_size(fpath, text, ART_W, weight)
    track = size * TRACK_RATIO
    stroke = max(6, size // stroke_div)

    # 手绘错落：中文那四个字高低不一；英文按固定节奏做极小幅上下偏移，
    # 幅度只有字号的 3.5%，近看才察觉，远看是「不是电脑排的」那点人味。
    dys = None
    if font_choice == "black" and wobble:
        pat = [0.00, -0.55, 0.30, -0.34, 0.46, -0.40, 0.16, -0.20]
        if len(pat) == len(text):
            dys = [p * size * 0.035 for p in pat]

    f = load_font(fpath, size, weight)
    if font_choice == "black":
        layer = renderer(text, f, tracking=track, stroke=stroke, dys=dys)
    else:
        layer = renderer(text, f, tracking=track, stroke=stroke)
    x = int(ART_W / 2 - layer.size[0] / 2)
    y = int(TITLE_CY - layer.size[1] / 2)
    base.alpha_composite(layer, (x, y))
    print("title  %dx%d at (%d,%d)  size=%d track=%.1f stroke=%d  font=%s" % (
        layer.size[0], layer.size[1], x, y, size, track, stroke, font_choice))

    out = os.path.join(UI, "title_art_en.png")
    base.convert("RGB").save(out, optimize=True)
    print("art ->", out)

    zh = Image.open(os.path.join(UI, "title_art.png")).convert("RGB")
    tw = 960
    th = int(tw * ART_H / ART_W)
    pair = Image.new("RGB", (tw, th * 2), (255, 255, 255))
    pair.paste(zh.resize((tw, th), Image.LANCZOS), (0, 0))
    pair.paste(base.convert("RGB").resize((tw, th), Image.LANCZOS), (0, th))
    pp = os.path.join(D, "preview_zh_vs_en.png")
    pair.save(pp, optimize=True)
    print("pair ->", pp)

    import shutil
    tag = font_choice + ("_wobble" if (font_choice == "black" and wobble) else "")
    shutil.copyfile(out, os.path.join(D, "title_en_%s.png" % tag))
    shutil.copyfile(pp, os.path.join(D, "preview_%s.png" % tag))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", choices=("black", "sans", "serif"), default="black")
    ap.add_argument("--no-wobble", action="store_true", help="取消字母手绘错落")
    a = ap.parse_args()
    build(a.font, not a.no_wobble)


if __name__ == "__main__":
    main()
