# -*- coding: utf-8 -*-
"""R604 合成：黑底金线徽记 → 透明 PNG；主视觉 → 叠标题字成 1920×1080。

为什么不把字交给 AI：中文四字必糊（四个字错一个是常态），英文也会拼错。
所以图上不放字，回来用衬线体自己排 —— 字距、描边、金色渐变全可控，换名也不用重出图。
衬线体只在 Python 侧用（系统 NotoSerifSC-VF），**不新增游戏内字体资源**，包体零增长。

用法：
  python tools/_compose_r604_art.py --grid  <raw>                        # 打网格，量横幅位置
  python tools/_compose_r604_art.py --mark  <raw>                        # → assets/ui/studio_mark.png
  python tools/_compose_r604_art.py --art   <raw> --cy 300 [--dry]       # → assets/ui/title_art.png
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "assets", "ui")
ART_W, ART_H = 1920, 1080

SERIF = r"C:\Windows\Fonts\NotoSerifSC-VF.ttf"
SANS = r"C:\Windows\Fonts\msyhbd.ttc"

GOLD = [(255, 242, 202), (246, 216, 140), (230, 190, 100), (172, 118, 36)]
DARK = (40, 24, 10)


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


def _draw_line(draw, text, font, x, y, tracking, fill, stroke=0, stroke_fill=None):
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill, stroke_width=stroke,
                  stroke_fill=stroke_fill if stroke_fill is not None else fill)
        x += font.getlength(ch) + tracking


def render_gold_text(text, font, tracking=0.0, stroke=6, ss=2):
    """返回 (rgba 图层, w, h)：金渐变字 + 深色描边 + 柔影。ss = 超采样倍率。"""
    widths, total, line_h = _metrics(text, font, tracking)
    pad = stroke + 10
    W = int(total + pad * 2)
    H = int(line_h + pad * 2)

    big = ImageFont.truetype(font.path, font.size * ss)
    try:
        big.set_variation_by_axes([900])
    except Exception:                                         # noqa: BLE001
        pass

    outline = Image.new("L", (W * ss, H * ss), 0)
    core = Image.new("L", (W * ss, H * ss), 0)
    _draw_line(ImageDraw.Draw(outline), text, big, pad * ss, pad * ss, tracking * ss,
               255, stroke=stroke * ss)
    _draw_line(ImageDraw.Draw(core), text, big, pad * ss, pad * ss, tracking * ss, 255)

    out = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))

    # 1) 柔影
    shadow = outline.filter(ImageFilter.GaussianBlur(7 * ss)).point(lambda v: int(v * 0.55))
    sh = Image.new("RGBA", out.size, DARK + (0,))
    sh.putalpha(shadow)
    out.alpha_composite(sh, (2 * ss, 5 * ss))

    # 2) 描边
    edge = Image.new("RGBA", out.size, DARK + (0,))
    edge.putalpha(outline)
    out.alpha_composite(edge)

    # 3) 金色纵向渐变
    grad = Image.new("RGBA", out.size)
    gd = ImageDraw.Draw(grad)
    n = len(GOLD) - 1
    for yy in range(out.size[1]):
        t = yy / max(1, out.size[1] - 1) * n
        i = min(n - 1, int(t))
        k = t - i
        c = tuple(int(GOLD[i][j] + (GOLD[i + 1][j] - GOLD[i][j]) * k) for j in range(3))
        gd.line([(0, yy), (out.size[0], yy)], fill=c + (255,))
    fill = Image.new("RGBA", out.size, (0, 0, 0, 0))
    fill.paste(grad, (0, 0), core)
    out.alpha_composite(fill)

    return out.resize((W, H), Image.LANCZOS)


def fit_cover(im, w, h):
    w0, h0 = im.size
    s = max(w / w0, h / h0)
    im2 = im.resize((max(1, int(w0 * s + 0.5)), max(1, int(h0 * s + 0.5))), Image.LANCZOS)
    x = (im2.size[0] - w) // 2
    y = (im2.size[1] - h) // 2
    return im2.crop((x, y, x + w, y + h))


def do_grid(raw):
    im = fit_cover(Image.open(raw).convert("RGB"), ART_W, ART_H)
    d = ImageDraw.Draw(im)
    for x in range(0, ART_W, 120):
        d.line([(x, 0), (x, ART_H)], fill=(255, 0, 0), width=1)
        d.text((x + 2, 4), str(x), fill=(255, 0, 0))
    for y in range(0, ART_H, 90):
        d.line([(0, y), (ART_W, y)], fill=(0, 128, 255), width=1)
        d.text((4, y + 2), str(y), fill=(0, 128, 255))
    out = os.path.join(ROOT, "_review", "r604_grid.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out)
    print("grid ->", out)


def do_mark(raw):
    """黑底金线稿 → 透明 PNG。

    RGB 统一重建为金色纵向渐变，只用亮度当 alpha —— 这样 AI 的偏色、黑底残灰
    全部被消掉，缩到 512 也不出黑边（不会留下「半透明黑边」那种脏脏的轮廓）。
    """
    im = Image.open(raw).convert("RGB")
    lum = im.convert("L")
    a = lum.point(lambda v: 0 if v < 22 else min(255, int((v - 22) * 1.62)))

    side = max(im.size)
    sq = Image.new("L", (side, side), 0)
    sq.paste(a, ((side - im.size[0]) // 2, (side - im.size[1]) // 2))
    sq = sq.resize((512, 512), Image.LANCZOS)

    grad = Image.new("RGB", (512, 512))
    gd = ImageDraw.Draw(grad)
    n = len(GOLD) - 1
    for yy in range(512):
        t = yy / 511 * n
        i = min(n - 1, int(t))
        k = t - i
        c = tuple(int(GOLD[i][j] + (GOLD[i + 1][j] - GOLD[i][j]) * k) for j in range(3))
        gd.line([(0, yy), (512, yy)], fill=c)

    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    out.paste(grad, (0, 0), sq)
    dst = os.path.join(UI, "studio_mark.png")
    os.makedirs(UI, exist_ok=True)
    out.save(dst, optimize=True)
    # 统计不透明占比，粗略判断线稿是不是空的
    hist = sq.histogram()
    opaque = sum(hist[40:]) / float(512 * 512)
    print("mark -> %s  (线稿覆盖 %.1f%%)" % (dst, opaque * 100))


def do_art(raw, cx, cy, size, track, en_dy, en_size, en_track, dry, with_en=False):
    base = fit_cover(Image.open(raw).convert("RGB"), ART_W, ART_H).convert("RGBA")

    f = load_font(SERIF, size, 900)
    layer = render_gold_text("嘎嘎乱杀", f, tracking=track, stroke=max(4, size // 16))
    base.alpha_composite(layer, (int(cx - layer.size[0] / 2), int(cy - layer.size[1] / 2)))
    print("title  %dx%d at (%d,%d)" % (layer.size[0], layer.size[1],
                                       int(cx - layer.size[0] / 2), int(cy - layer.size[1] / 2)))

    # R607 店长口径：**全游戏不要副标题** —— 英文副标默认不画。
    # （R605 试过 4 个位置，横幅内外都会被按钮盖掉一半；且它本身就是副标题。）
    # 真要画必须显式 --with-en。英文名由窗口标题与 Steam 商店页承载。
    if with_en:
        fe = load_font(SANS, en_size)
        en = "QUACKILL"
        el = render_gold_text(en, fe, tracking=en_track, stroke=max(2, en_size // 12))
        ex = int(cx - el.size[0] / 2)
        ey = int(cy + layer.size[1] * 0.5 + en_dy)
        base.alpha_composite(el, (ex, ey))
        print("en     %dx%d at (%d,%d)" % (el.size[0], el.size[1], ex, ey))

    out = os.path.join(ROOT, "_review", "r604_art_dry.png") if dry else os.path.join(UI, "title_art.png")
    base.convert("RGB").save(out, optimize=True)
    print("art ->", out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grid", action="store_true")
    ap.add_argument("--mark", action="store_true")
    ap.add_argument("--art", action="store_true")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--with-en", action="store_true",
                    help="额外画英文副标 QUACKILL（默认不画：全游戏不设副标题）")
    ap.add_argument("raw", nargs="?", default="")
    ap.add_argument("--cx", type=float, default=ART_W / 2)
    ap.add_argument("--cy", type=float, default=300)
    ap.add_argument("--size", type=int, default=150)
    ap.add_argument("--track", type=float, default=26.0)
    ap.add_argument("--en-dy", type=float, default=24)
    ap.add_argument("--en-size", type=int, default=38)
    ap.add_argument("--en-track", type=float, default=9.0)
    a = ap.parse_args()
    if not a.raw or not os.path.exists(a.raw):
        sys.exit("need an existing raw png")
    if a.grid:
        do_grid(a.raw)
    elif a.mark:
        do_mark(a.raw)
    elif a.art:
        do_art(a.raw, a.cx, a.cy, a.size, a.track, a.en_dy, a.en_size, a.en_track,
               a.dry, a.with_en)
    else:
        sys.exit("pick one of --grid / --mark / --art")


if __name__ == "__main__":
    main()
