# -*- coding: utf-8 -*-
"""R768：把配色方案从「固定五套」改成「F 打底 + G/H/I/J 四级提亮」。

店长反馈：F（#9A7BC4）太深，卡面上容易看不清。
所以保留「亮紫底 + 墨黑剪影」这层关系（只有它能同时保住青裂缝/黄闪电/灰石头），
只把底色沿亮度往上推四档，让店长在同一条色相带上挑亮度。

同时把 _swatch.py 里写死的对比度数字改成实时计算 —— 硬编码在改色后必然过期。
"""
import io
import re

RECOLOR = r"E:\work\card_rogue\art_src\2026-11-16_诅咒火柴人_R768\_recolor.py"
SWATCH = r"E:\work\card_rogue\art_src\2026-11-16_诅咒火柴人_R768\_swatch.py"


def read(p):
    return io.open(p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def sub1(src, old, new, tag):
    assert src.count(old) == 1, "%s: count=%d" % (tag, src.count(old))
    return src.replace(old, new)


# ---------- 1. _recolor.py 的方案表 ----------
s = read(RECOLOR)
old_schemes = '''SCHEMES = [
    ("A", "深紫底 + 骨白图", (0x24, 0x1A, 0x32), (0xEA, 0xE0, 0xF4)),
    ("B", "中紫底 + 墨黑图", (0x7A, 0x5A, 0xA0), (0x14, 0x0E, 0x1C)),
    ("C", "深紫底 + 亮紫图", (0x2A, 0x1B, 0x36), (0xC8, 0x9B, 0xE8)),
    ("D", "亮紫灰底 + 黑图", (0xA9, 0x8B, 0xC8), (0x16, 0x10, 0x1E)),
    ("E", "深酒红底 + 骨白图", (0x2C, 0x12, 0x20), (0xF0, 0xDE, 0xE6)),
    ("F", "紫底 + 墨黑图", (0x9A, 0x7B, 0xC4), (0x12, 0x0C, 0x18)),
]'''
new_schemes = '''# 店长反馈「紫色太深、容易看不清」后，保留「亮紫底 + 墨黑剪影」这一层关系
# （只有它能让青裂缝 / 黄闪电 / 灰石头三类符号同时活着），只把底色亮度往上推四档。
# F = 原方案，作对照基准；G/H/I/J 依次更亮，图色同步微调以保持墨黑层次。
SCHEMES = [
    ("F", "紫底 + 墨黑图", (0x9A, 0x7B, 0xC4), (0x12, 0x0C, 0x18)),
    ("G", "亮紫底 + 墨黑图", (0xAE, 0x92, 0xD2), (0x14, 0x0D, 0x1C)),
    ("H", "浅紫底 + 墨黑图", (0xC2, 0xAA, 0xE0), (0x16, 0x0F, 0x20)),
    ("I", "淡紫底 + 墨黑图", (0xD5, 0xC2, 0xEE), (0x18, 0x0F, 0x22)),
    ("J", "藕荷底 + 墨黑图", (0xE6, 0xDB, 0xF6), (0x1A, 0x11, 0x24)),
]'''
s = sub1(s, old_schemes, new_schemes, "SCHEMES")
write(RECOLOR, s)
print("recolor.py: SCHEMES -> F/G/H/I/J")

# ---------- 2. _swatch.py 的列与说明 ----------
s = read(SWATCH)
old_codes = '''CODES = ["A", "C", "D", "F", "E"]
SCHEME_DESC = {
    "A": ("深紫底 + 骨白图", "13.0:1", True),
    "B": ("中紫底 + 墨黑图", "3.4:1", False),
    "C": ("深紫底 + 亮紫图", "7.1:1", False),
    "D": ("亮紫灰底 + 黑图", "6.4:1", True),
    "E": ("深酒红底 + 骨白图", "13.4:1", True),
    "F": ("紫底 + 墨黑图", "5.5:1", True),
}'''
new_codes = '''CODES = ["F", "G", "H", "I", "J"]

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
    return (desc, "%.1f:1" % cr, cr >= 4.5)'''
s = sub1(s, old_codes, new_codes, "CODES")

s = sub1(s, "        desc, cr, ok = SCHEME_DESC[code]",
         "        desc, cr, ok = scheme_desc(code)", "调用点")

s = sub1(s, 'dr.text((PAD, 10), "R768 诅咒卡配色挑选 — 四张 × 五套，均按卡面实宽 150px",',
         'dr.text((PAD, 10), "R768 诅咒卡配色挑选 — 四张 × 五套（越右越亮），均按卡面实宽 150px",',
         "标题")
write(SWATCH, s)
print("swatch.py: CODES -> F/G/H/I/J，对比度改为实时计算")

# ---------- 3. 残留检查 ----------
for path, pats in ((RECOLOR, ["SCHEME_DESC"]), (SWATCH, ["SCHEME_DESC"])):
    body = read(path)
    for p in pats:
        n = len(re.findall(p, body))
        assert n == 0, "%s 还残留 %s x%d" % (path, p, n)
print("残留检查 0")
