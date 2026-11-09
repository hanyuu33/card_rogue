# -*- coding: utf-8 -*-
"""R547：把「战斗胜利」做成图片素材（金色浮雕字），替代运行时 Label。

几何口径（显示坐标，面板 580 见方）：
  目标字高 46、字心 y=133 —— 缎带绿色区在中心列是 y≈108~160，
  上方盾牌尖到 108，下方金滚边 160，46 高居中刚好两侧各留 1~2px。
  成品按 2x 出图（字高 92），游戏里 `size = tex.get_size() * 0.5`。
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

TEXT = "战斗胜利"
SS = 4                      # 超采样倍数（先大画再缩）
GLYPH_H = 46.0              # 显示坐标下的目标字高
PAD = 10                    # 显示坐标下的四周留白（容纳投影/描边）
SCALE = 2                   # 成图 = 显示尺寸 × 2

GOLD = [
    (0.00, (246, 206, 112)),
    (0.18, (242, 190, 88)),
    (0.42, (230, 164, 52)),
    (0.66, (204, 128, 30)),
    (0.88, (166, 98, 24)),
    (1.00, (238, 190, 106)),
]


def lerp_gold(t):
    t = max(0.0, min(1.0, t))
    for i in range(len(GOLD) - 1):
        a, ca = GOLD[i]
        b, cb = GOLD[i + 1]
        if a <= t <= b:
            k = (t - a) / max(1e-6, (b - a))
            return tuple(int(ca[j] + (cb[j] - ca[j]) * k) for j in range(3))
    return GOLD[-1][1]


def dilate(mask, px):
    out, step = mask, 0
    while step < px:
        s = min(3, px - step)
        out = out.filter(ImageFilter.MaxFilter(s * 2 + 1))
        step += s
    return out


def render(font_path, size, tracking, bold=0.0):
    """按超采样尺寸画字，返回 (rgba 字图, 描边 mask, 字形 mask)。"""
    font = ImageFont.truetype(font_path, size)
    boxes = [font.getbbox(ch) for ch in TEXT]
    widths = [b[2] - b[0] for b in boxes]
    total_w = sum(widths) + tracking * (len(TEXT) - 1)
    asc, desc = font.getmetrics()
    w, h = total_w + 12, asc + desc + 12

    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    x = 6
    sw = max(0, int(size * bold))
    for i, ch in enumerate(TEXT):
        md.text((x - boxes[i][0], 6), ch, font=font, fill=255,
                stroke_width=sw, stroke_fill=255)
        x += widths[i] + tracking

    grad = Image.new("RGB", (1, h))
    for y in range(h):
        grad.putpixel((0, y), lerp_gold(y / max(1, h - 1)))
    grad = grad.resize((w, h))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ol_px = max(2, int(size * 0.105))
    ol = dilate(mask, ol_px)
    # 深褐描边
    out.paste(Image.new("RGBA", (w, h), (36, 23, 7, 255)), (0, 0), ol)
    # 描边内侧一圈亮金线（黄铜包边感）
    ring = ImageChops.subtract(ol, mask)
    out = Image.alpha_composite(out, Image.composite(
        Image.new("RGBA", (w, h), (250, 220, 144, 255)),
        Image.new("RGBA", (w, h), (0, 0, 0, 0)), ring))
    # 金色主体
    out.paste(grad.convert("RGBA"), (0, 0), mask)
    # 顶部提亮（克制，别把字洗白）
    hi = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hp = hi.load()
    half = max(1, int(h * 0.5))
    for y in range(half):
        a = int(35 * (1 - y / half) ** 1.6)
        for x in range(w):
            hp[x, y] = (255, 247, 208, a)
    out = Image.alpha_composite(out, Image.composite(
        hi, Image.new("RGBA", (w, h), (0, 0, 0, 0)), mask))
    # 笔画底部内阴影：沿字形上移 size*0.10 相减得到「下缘带」，压深 → 有厚度
    shi = max(2, int(size * 0.10))
    band = ImageChops.subtract(mask, mask.transform((w, h), Image.AFFINE, (1, 0, 0, 0, 1, shi)))
    out = Image.alpha_composite(out, Image.composite(
        Image.new("RGBA", (w, h), (120, 66, 12, 105)),
        Image.new("RGBA", (w, h), (0, 0, 0, 0)), band))
    # 底部暖边光
    sh = max(1, int(size * 0.04))
    low = mask.transform((w, h), Image.AFFINE, (1, 0, 0, 0, 1, -sh))
    rim = Image.eval(Image.composite(low, Image.new("L", (w, h), 0), mask), lambda v: 255 - v)
    rim = Image.composite(rim, Image.new("L", (w, h), 0), mask)
    out = Image.alpha_composite(out, Image.composite(
        Image.new("RGBA", (w, h), (255, 232, 168, 190)),
        Image.new("RGBA", (w, h), (0, 0, 0, 0)), rim))
    return out, ol, mask


def finish(font_path, tracking, bold=0.0, size=400):
    """出成品：字高归一到 GLYPH_H、四周补 PAD、按 SCALE 缩到成图尺寸。"""
    glyph, ol, mask = render(font_path, size, tracking, bold)
    gb = glyph.getbbox()
    mb = mask.getbbox()
    box = (min(gb[0], mb[0]), min(gb[1], mb[1]), max(gb[2], mb[2]), max(gb[3], mb[3]))
    tight = glyph.crop(box)
    gh = box[3] - box[1]
    k = (GLYPH_H * SS) / gh
    tight = tight.resize((max(1, int(tight.size[0] * k)), max(1, int(tight.size[1] * k))),
                         Image.LANCZOS)
    pw = int(PAD * SS)
    canvas = Image.new("RGBA", (tight.size[0] + pw * 2, tight.size[1] + pw * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sm = Image.new("L", canvas.size, 0)
    sm.paste(dilate(tight.split()[3], 6), (pw, pw + 6))
    shadow.paste(Image.new("RGBA", canvas.size, (20, 13, 4, 150)), (0, 0), sm)
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(tight, (pw, pw))
    target = (max(1, int(canvas.size[0] * SCALE / SS)), max(1, int(canvas.size[1] * SCALE / SS)))
    return canvas.resize(target, Image.LANCZOS)


VARIANTS = [
    ("song", "C:/Windows/Fonts/simsun.ttc", 26, 0.014),
    ("song_bold", "C:/Windows/Fonts/simsun.ttc", 30, 0.026),
    ("kai", "C:/Windows/Fonts/simkai.ttf", 26, 0.010),
]

if __name__ == "__main__":
    os.makedirs("_preview", exist_ok=True)
    plate = Image.open("assets/ui/battle_win_plate.png").convert("RGB").resize((580, 580), Image.LANCZOS)
    outs = []
    for name, path, tr, bold in VARIANTS:
        art = finish(path, tr, bold)
        print(name, "asset", art.size, "-> display", (art.size[0] / SCALE, art.size[1] / SCALE))
        p = plate.copy()
        dw, dh = art.size[0] // SCALE, art.size[1] // SCALE
        small = art.resize((dw, dh), Image.LANCZOS)
        p.paste(small, ((580 - dw) // 2, 133 - dh // 2), small)
        outs.append((name, p, art))
    crop = (60, 70, 520, 200)
    zw, zh = int((crop[2] - crop[0]) * 1.6), int((crop[3] - crop[1]) * 1.6)
    sheet = Image.new("RGB", (zw, zh * len(outs) + 8 * (len(outs) - 1)), (16, 16, 20))
    f = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 18)
    for i, (name, p, art) in enumerate(outs):
        c = p.crop(crop).resize((zw, zh), Image.LANCZOS)
        sheet.paste(c, (0, i * (zh + 8)))
        ImageDraw.Draw(sheet).text((12, i * (zh + 8) + 8), name, font=f, fill=(255, 214, 120))
    sheet.save("_preview/r547_title_sim.png")
    print("sim", sheet.size)
