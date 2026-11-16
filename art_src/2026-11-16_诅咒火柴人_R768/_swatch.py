# -*- coding: utf-8 -*-
"""R768 配色挑选图：四张卡 × 五套配色，一格一张，全部按**卡面实宽 150px** 出。

选颜色在对话里看一张图最快，所以单出 PNG 不走 HTML。
尺寸按实际卡片显示宽度缩，判的是「小图上还认不认得出」，不是大图好不好看。

用法：
    python _swatch.py                   # 四张全出
    python _swatch.py regret_v2         # 只出某一张
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-16_诅咒火柴人_R768"
REC = D / "recolor"

KEYS = [("regret_v2", 9265, "懊悔"), ("flaw", 9154, "破绽"),
        ("paralysis", 9185, "麻痹"), ("compensation", 9252, "代偿")]
CODES = ["F", "G", "H", "I", "J"]

# 底/图色与 _recolor.py 的 SCHEMES 同源；对比度实时算，不写死数字
# （改一次底色就要改一遍硬编码，早晚过期 —— 上一版就是这么错的）。
PALETTE = {
    "F": ("紫底 + 墨黑图", (0x9A, 0x7B, 0xC4), (0x12, 0x0C, 0x18)),
    "G": ("亮紫底 + 墨黑图", (0xAE, 0x92, 0xD2), (0x14, 0x0D, 0x1C)),
    "H": ("浅紫底 + 墨黑图", (0xC2, 0xAA, 0xE0), (0x16, 0x0F, 0x20)),
    "I": ("淡紫底 + 墨黑图", (0xD5, 0xC2, 0xEE), (0x18, 0x0F, 0x22)),
    "J": ("藕荷底 + 墨黑图", (0xE6, 0xDB, 0xF6), (0x1A, 0x11, 0x24)),
}


def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _lum(rgb):
    r, g, b = (_lin(v) for v in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _contrast(a, b):
    la, lb = _lum(a), _lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def scheme_desc(code):
    """返回 (说明, 对比度文本, 是否够清楚)。小图上 >=4.5:1 才判成立。"""
    desc, bg, fg = PALETTE[code]
    cr = _contrast(bg, fg)
    return (desc, "%.1f:1" % cr, cr >= 4.5)
BAND_TOP, BAND_BOT = 68, 335

MINI_W = 150
MINI_H = int(MINI_W * (BAND_BOT - BAND_TOP + 1) / 448)   # 90
PAD = 12
ROW_LABEL_W = 96
HEAD_H = 40
ROW_H = MINI_H + 26


def font(sz, bold=False):
    names = ("msyhbd.ttc", "msyh.ttc") if bold else ("msyh.ttc", "msyhbd.ttc")
    for name in names + ("simhei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype("C:/Windows/Fonts/" + name, sz)
        except Exception:
            continue
    return ImageFont.load_default()


def band_of(key, code):
    p = REC / ("%s_%s.png" % (key, code))
    if not p.exists():
        return None
    im = Image.open(p).convert("RGB")
    return im.crop((0, BAND_TOP, im.width, BAND_BOT + 1))


def main(keys):
    rows = []
    for key, cid, name in KEYS:
        if keys and key not in keys:
            continue
        cells = [(c, band_of(key, c)) for c in CODES]
        cells = [(c, b) for c, b in cells if b]
        if cells:
            rows.append((key, cid, name, cells))
    if not rows:
        print("没有配色图，先跑 _recolor.py")
        return 1

    cols = len(rows[0][3])
    W = PAD + ROW_LABEL_W + cols * (MINI_W + PAD)
    H = HEAD_H + PAD + len(rows) * (ROW_H + PAD) + 8
    canvas = Image.new("RGB", (W, H), (22, 16, 28))
    dr = ImageDraw.Draw(canvas)

    dr.text((PAD, 10), "R768 诅咒卡配色挑选 — 四张 × 五套（越右越亮），均按卡面实宽 150px",
            font=font(15, True), fill=(234, 222, 242))

    # 表头
    y_head = HEAD_H
    for i, code in enumerate(CODES[:cols]):
        desc, cr, ok = scheme_desc(code)
        x = PAD + ROW_LABEL_W + i * (MINI_W + PAD)
        dr.text((x, y_head), "%s  %s" % (code, desc), font=font(12, True),
                fill=(226, 210, 238))
        dr.text((x, y_head + 15), "对比 " + cr + ("  ✓" if ok else "  ✗ 小图糊"),
                font=font(11), fill=(140, 212, 158) if ok else (232, 160, 160))

    y = HEAD_H + 34
    for key, cid, name, cells in rows:
        dr.text((PAD, y + MINI_H // 2 - 14), "%s" % name, font=font(15, True),
                fill=(226, 210, 238))
        dr.text((PAD, y + MINI_H // 2 + 3), "%d" % cid, font=font(11), fill=(150, 138, 166))
        for i, (code, band) in enumerate(cells):
            x = PAD + ROW_LABEL_W + i * (MINI_W + PAD)
            mini = band.resize((MINI_W, MINI_H), Image.LANCZOS)
            canvas.paste(mini, (x, y))
            dr.rectangle([x - 1, y - 1, x + MINI_W, y + MINI_H], outline=(58, 44, 68))
        y += ROW_H + PAD

    out = REC / "pick_all.png"
    canvas.save(out)
    print("->", out, canvas.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
