# -*- coding: utf-8 -*-
"""Steam 成就图标流水线（R742 · 单色金属版）。

设计口径
--------
Steam 的成就图标不是九张彩色小插画，而**一套同材质徽章**：每枚只有一个金属色，
体积全靠明暗，等级由金属区分（铜 / 银 / 金）。所以这里不再缩彩色原图，而是

  1. 原图 → 灰度（丢掉每张自带的配色，只留明暗结构）
  2. 灰度 → 单色金属渐变（铜/银/金，各自一条「暗→中→亮→高光」的色阶）
  3. 套统一的圆形徽章骨架：同色系深底 + 对角受光的金属环 + 主体留边

等级按「拿到它的难度」分档，见 TIER。

输入：`release/achievement_icons/src/<API>.png`（1024 方图，AI 出图，带水印那版也行）
输出：
  * `64/<API>.png`           已达成（该等级金属色，64×64 透明圆，后台直接传）
  * `64/<API>_locked.png`    未达成（统一灰石、压暗，64×64）
  * `512/<API>.png`          512 版（商店页 / 攻略站配图）
  * `preview.png` / `.html`  验收用

用法：python tools/make_achievement_icons.py
"""
import io
import math
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps, ImageStat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "release", "achievement_icons")
SRC = os.path.join(BASE, "src")

# (API, 显示名, 等级)  —— 等级按获取难度分：进度型铜 / 通关型银 / 高难型金
ACHIEVEMENTS = [
    ("FIRST_STEP",   "初次启程", "bronze"),
    ("FIRST_BOSS",   "直面恐惧", "bronze"),
    ("LAYER2_CLEAR", "深入腹地", "bronze"),
    ("FULL_CLEAR",   "完整通关", "silver"),
    ("CLEAR_FOREST", "森林的加冕", "silver"),
    ("CLEAR_ROGUE",  "影中的圆满", "silver"),
    ("CLEAR_MECH",   "机械的觉醒", "silver"),
    ("CLEAR_HARD",   "越难越勇", "gold"),
    ("CLEAR_APEX",   "巅峰之上", "gold"),
]

TIER_LABEL = {"bronze": "铜", "silver": "银", "gold": "金"}

# 单色金属色阶：(灰度位置, RGB)。位置 0/70/150/205/255 分别对应
# 暗部 / 中间调 / 亮部 / 高光 / 极光——靠这五档拉开金属的体积感。
METALS = {
    "bronze": [(0, (28, 15, 9)), (70, (104, 57, 29)), (150, (182, 111, 60)),
               (205, (226, 161, 100)), (255, (255, 225, 182))],
    # 银走冷调（偏靛蓝），和未达成的暖中性灰石拉开；否则 64px 下两者难分
    "silver": [(0, (16, 20, 30)), (70, (66, 80, 102)), (150, (132, 152, 178)),
               (205, (196, 214, 238)), (255, (255, 255, 255))],
    # 金提亮高光：三档里视觉权重最高，一眼看出是「最难那一条」
    "gold":   [(0, (34, 22, 7)), (70, (134, 89, 22)), (150, (216, 166, 52)),
               (205, (250, 218, 122)), (255, (255, 252, 228))],
    # 未达成版：暖中性灰石。三档共用一种，达成后才「显色」——这是 Steam 的常规读法。
    "stone":  [(0, (15, 14, 13)), (70, (56, 54, 52)), (150, (98, 96, 93)),
               (205, (132, 130, 126)), (255, (162, 160, 155))],
}

CROP = 72          # 四边各裁多少（1024 → 880），顺手切掉右下角 AI 水印
ICON = 64
MID = 512
CONTENT = 0.62     # 主体等效边长占画布比例（按面积归一，剩下留给金属环和呼吸）
CONTENT_MAX = 0.74 # 主体最长边上限，防止细长主体顶到环上
LUMA_TARGET = 142  # 主体平均亮度归一化目标（所有徽章拉到同一亮度，才像一套）
SIZE = 880         # 大图工作尺寸


def apply_ramp(gray: Image.Image, stops) -> Image.Image:
    """灰度 → 三通道查表，实现多段色阶着色（纯 PIL，无需 numpy）。"""
    lut = [[], [], []]
    for v in range(256):
        seg = 0
        for i in range(len(stops) - 1):
            if v >= stops[i][0]:
                seg = i
        p0, c0 = stops[seg]
        p1, c1 = stops[min(seg + 1, len(stops) - 1)]
        t = 0.0 if p1 == p0 else (v - p0) / float(p1 - p0)
        t = max(0.0, min(1.0, t))
        for ch in range(3):
            lut[ch].append(int(c0[ch] + (c1[ch] - c0[ch]) * t))
    return Image.merge("RGB", [gray.point(l) for l in lut])


def diag_light(size: int, s: int = 64) -> Image.Image:
    """左上亮 → 右下暗的对角光照。环是等半径的，径向光照对它无效，必须用方向光。"""
    im = Image.new("L", (s, s))
    px = im.load()
    for y in range(s):
        for x in range(s):
            px[x, y] = int(255 * (1.0 - (x + y) / (2.0 * (s - 1))))
    return im.resize((size, size), Image.BICUBIC)


def radial_light(size: int, cx=0.5, cy=0.42, power=1.9, s=128) -> Image.Image:
    """径向光，给底牌做中心微亮。低分辨率算完放大，比逐像素快几十倍。"""
    im = Image.new("L", (s, s))
    px = im.load()
    ox, oy = cx * s, cy * s
    maxd = (max(ox, s - ox) ** 2 + max(oy, s - oy) ** 2) ** 0.5
    for y in range(s):
        for x in range(s):
            d = ((x - ox) ** 2 + (y - oy) ** 2) ** 0.5 / maxd
            px[x, y] = int(255 * max(0.0, 1.0 - d) ** power)
    return im.resize((size, size), Image.BICUBIC)


def _posterize_lut(n: int):
    """把连续灰压成 n 档色阶（等距取整），得到版画/雕刻式的硬边。"""
    lut = [int(round(round(v / 255.0 * (n - 1)) * 255.0 / (n - 1))) for v in range(256)]
    return lut.__getitem__


def _s_curve(k: float):
    """返回 sigmoid 查表函数，k 越大中间调越陡。"""
    import math
    lut = [int(round(255.0 / (1.0 + math.exp(-k * (v / 255.0 - 0.5))))) for v in range(256)]
    return lut.__getitem__


def _alpha_from_gray(gray: Image.Image) -> Image.Image:
    """把背景抽成透明，只留主体。

    两个坑：
    1. 阈值不能写死 —— 有的源图整幅偏亮（石地板），写死会把背景一起保下来。
    2. 阈值不能太低 —— 原图主体外围有一圈柔光，阈值低就会把它当主体留下来，
       880 尺寸看着是一片脏雾。所以下限提到中位数附近，只认「明显比底色亮」的部分。
    """
    hist = gray.histogram()
    total = sum(hist)
    acc, p55, p88 = 0, 0, 0
    for v in range(256):
        acc += hist[v]
        if p55 == 0 and acc >= total * 0.55:
            p55 = v
        if p88 == 0 and acc >= total * 0.88:
            p88 = v
    low = max(42, int(p55 * 0.96))
    high = max(low + 40, int(p88 * 0.98))
    span = float(high - low)
    a = gray.point(lambda v: 0 if v <= low else (255 if v >= high else int((v - low) * 255 / span)))
    a = a.filter(ImageFilter.MedianFilter(5))      # 去掉零星亮斑，它们在 64px 下只是噪点
    a = a.filter(ImageFilter.GaussianBlur(SIZE / 300.0))
    return a


def build(api: str, metal: str) -> Image.Image:
    path = os.path.join(SRC, api + ".png")
    if not os.path.exists(path):
        raise SystemExit("缺源图：%s（把 AI 出的方图按 <API>.png 放进 src/）" % path)

    src = Image.open(path).convert("RGB")
    w, h = src.size
    side = min(w, h) - CROP * 2
    left, top = (w - side) // 2, (h - side) // 2
    art = src.crop((left, top, left + side, top + side))

    inner = int(SIZE * CONTENT)
    art = art.resize((inner, inner), Image.LANCZOS)

    gray = ImageOps.autocontrast(art.convert("L"), cutoff=2)
    # 减细节三连：中值滤波去絮状纹理 → 大半径 unsharp 捏出轮廓 → 压成 5 档色阶。
    # 原图的柔和渐变镀上金属在 64px 下会糊成一片斑驳，色阶化后才是「雕刻」的读法。
    gray = gray.filter(ImageFilter.MedianFilter(9))
    gray = gray.filter(ImageFilter.UnsharpMask(radius=SIZE / 60.0, percent=80, threshold=0))
    gray = gray.point(_posterize_lut(5))
    gray = gray.filter(ImageFilter.GaussianBlur(SIZE / 420.0))
    gray = gray.filter(ImageFilter.UnsharpMask(radius=SIZE / 180.0, percent=90, threshold=0))
    gray = ImageEnhance.Contrast(gray).enhance(1.08)

    alpha = _alpha_from_gray(gray)

    # 归一化一：按主体包围盒裁紧再统一缩放。
    # 不这么做，匕首那枚主体只占半格、机械心那枚快顶到环 —— 九枚摆一起就不像一套。
    # 注意 bbox 必须用「实心主体」来取：alpha 上的零星半透明噪点会把框撑满整幅，
    # 那就等于没裁（踩过）。
    box = alpha.point(lambda v: 255 if v >= 200 else 0).getbbox()
    if box:
        art = art.crop(box)
        gray = gray.crop(box)
        alpha = alpha.crop(box)
    nw, nh = gray.size
    # 按「面积」归一（而非最长边）：否则细长主体（如竖长的盾）会被放大到比别的更抢眼。
    # 再用最长边上限兜一次，防止细长主体溢出到金属环上。
    scale = min((SIZE * CONTENT) / math.sqrt(nw * nh), (SIZE * CONTENT_MAX) / float(max(nw, nh)))
    nw, nh = max(1, int(nw * scale)), max(1, int(nh * scale))
    art = art.resize((nw, nh), Image.LANCZOS)
    gray = gray.resize((nw, nh), Image.LANCZOS)
    alpha = alpha.resize((nw, nh), Image.LANCZOS)

    # 归一化二：把主体平均亮度拉到同一水平。
    # 源图有的整幅偏亮（机械心）、有的偏暗（暗影匕首），不拉平就会出现
    # 「同一档银，一枚发白一枚近黑」。
    body = ImageStat.Stat(gray, mask=alpha.point(lambda v: 255 if v > 60 else 0))
    mean = body.mean[0] if body.count and body.count[0] else 128.0
    mean = max(16.0, min(240.0, mean))
    gamma = math.log(LUMA_TARGET / 255.0) / math.log(mean / 255.0)
    gamma = max(0.45, min(2.2, gamma))
    gray = gray.point(lambda v: int(255 * ((v / 255.0) ** gamma)))
    print("      bbox %dx%d  主体亮度 %.0f → gamma %.2f" % (nw, nh, mean, gamma))

    stops = METALS[metal]
    tinted = apply_ramp(gray, stops)

    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # 底牌：同色系深色径向渐变（与金属同家族，保证「一个色系」）
    dark = stops[0][1]
    glow = radial_light(SIZE)
    plate = Image.merge("RGB", [
        glow.point(lambda v, c=c: min(255, int(c + v * 0.20))) for c in dark
    ])
    out.paste(plate, (0, 0))

    ox, oy = (SIZE - nw) // 2, (SIZE - nh) // 2
    out.paste(tinted, (ox, oy), alpha)

    # 金属环：方向光调制明度 —— 左上亮、右下暗，才像被打光的实心金属
    ringw = int(SIZE * 0.030)
    m = int(SIZE * 0.030)
    rmask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(rmask).ellipse([m, m, SIZE - m, SIZE - m], outline=255, width=ringw)
    lit = diag_light(SIZE, 96).filter(ImageFilter.GaussianBlur(SIZE / 130))
    ringval = lit.point(lambda v: int(92 + v * 0.64))
    out.paste(apply_ramp(ringval, stops), (0, 0), rmask)

    # 环两侧极细暗边，跟底牌和主体分开，64px 下才不糊成一圈
    gap = Image.new("L", (SIZE, SIZE), 0)
    gd = ImageDraw.Draw(gap)
    thin = max(2, SIZE // 240)
    gd.ellipse([m - ringw // 2 - thin, m - ringw // 2 - thin,
                SIZE - m + ringw // 2 + thin, SIZE - m + ringw // 2 + thin],
               outline=255, width=thin)
    gd.ellipse([m + ringw // 2, m + ringw // 2,
                SIZE - m - ringw // 2, SIZE - m - ringw // 2], outline=255, width=thin)
    shadow = tuple(max(0, int(c * 0.28)) for c in stops[0][1])
    out.paste(Image.new("RGB", (SIZE, SIZE), shadow), (0, 0), gap)

    # 圆形裁切 + 最外沿一道暗边（防止在浅色背景上发飘）
    circ = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(circ).ellipse([1, 1, SIZE - 2, SIZE - 2], fill=255)
    clipped = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    clipped.paste(out, (0, 0), circ)
    outer = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(outer).ellipse([1, 1, SIZE - 2, SIZE - 2],
                                 outline=255, width=max(2, SIZE // 300))
    clipped.paste(Image.new("RGB", (SIZE, SIZE), (4, 4, 6)), (0, 0),
                  outer.point(lambda v: int(v * 0.9)))
    return clipped


def downsize(big: Image.Image) -> Image.Image:
    """880 → 64。缩小后再锐一次，否则 64px 边缘发糊。"""
    small = big.resize((ICON, ICON), Image.LANCZOS)
    return small.filter(ImageFilter.UnsharpMask(radius=1.0, percent=125, threshold=2))


def main() -> None:
    out64 = os.path.join(BASE, "64")
    out512 = os.path.join(BASE, "512")
    os.makedirs(out64, exist_ok=True)
    os.makedirs(out512, exist_ok=True)

    rows = []
    for api, label, tier in ACHIEVEMENTS:
        big = build(api, tier)
        big.save(os.path.join(out512, api + ".png"))
        icon = downsize(big)
        icon.save(os.path.join(out64, api + ".png"), optimize=True)

        # 未达成版：同一套骨架换成中性灰石，再压一档亮度，形成「没点亮」的哑光感
        lk = downsize(build(api, "stone"))
        alpha = lk.split()[3]
        lk = Image.merge("RGB", [c.point(lambda v: int(v * 0.72)) for c in lk.convert("RGB").split()])
        lk = lk.convert("RGBA")
        lk.putalpha(alpha)
        lk.save(os.path.join(out64, api + "_locked.png"), optimize=True)

        rows.append((api, label, tier, icon, lk))
        print("  %-13s %-6s %s  (64 + 512 + locked)" % (api, label, TIER_LABEL[tier]))

    _preview(rows)
    print("\n输出目录：%s" % BASE)


def _font(size: int):
    for cand in ("C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/simhei.ttf"):
        if os.path.exists(cand):
            return ImageFont.truetype(cand, size)
    try:
        return ImageFont.truetype("arial.ttf", size)
    except Exception:
        return ImageFont.load_default()


def _preview(rows) -> None:
    """一张对比表 PNG（好发给人看）+ 一个 HTML（好逐条核对、能看清 64px 实效）。"""
    cell, pad, label_h = 128, 20, 30
    w = pad * 2 + 210 + cell * 2 + 40
    h = pad + len(rows) * (cell + label_h + pad)

    font = _font(16)
    font_s = _font(13)
    sheet = Image.new("RGB", (w, h), (18, 19, 22))
    d = ImageDraw.Draw(sheet)
    y = pad
    for api, label, tier, icon, lk in rows:
        d.text((pad, y), api, fill=(228, 228, 230), font=font)
        d.text((pad, y + 20), "%s · %s" % (label, TIER_LABEL[tier]), fill=(146, 148, 154), font=font_s)
        x = pad + 210
        sheet.paste(icon.resize((cell, cell), Image.NEAREST), (x, y), 
                    icon.resize((cell, cell), Image.NEAREST).split()[3])
        lk_big = lk.resize((cell, cell), Image.NEAREST)
        sheet.paste(lk_big, (x + cell + 40, y), lk_big.split()[3])
        d.text((x, y + cell + 2), "achieved", fill=(140, 200, 150), font=font_s)
        d.text((x + cell + 40, y + cell + 2), "locked", fill=(160, 150, 140), font=font_s)
        y += cell + label_h + pad
    sheet.save(os.path.join(BASE, "preview.png"))
    print("  preview.png  %dx%d" % (w, h))

    html = [
        "<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>",
        "<title>Quackill · Steam 成就图标</title><style>",
        "body{background:#131418;color:#e6e6e6;font:14px/1.7 system-ui,'Segoe UI',sans-serif;margin:0;padding:30px}",
        "h1{font-size:18px;color:#e8d3a4;margin:0 0 6px}p.note{color:#9aa0a6;margin:0 0 24px;max-width:820px}",
        "table{border-collapse:collapse}td,th{padding:10px 16px;border-bottom:1px solid #272a31;text-align:left;vertical-align:middle}",
        "th{color:#9aa0a6;font-weight:500;font-size:12px;text-transform:uppercase;letter-spacing:.08em}",
        "code{color:#8fd6a8;font-size:12px}.tier{font-size:12px;padding:1px 8px;border-radius:10px}",
        ".b{background:#40301f;color:#e0a86a}.s{background:#2c3038;color:#c3ccd6}.g{background:#3d3315;color:#efd07e}",
        "img.px{image-rendering:pixelated;width:64px;height:64px}",
        "img.big{width:104px;height:104px}",
        "</style></head><body>",
        "<h1>Quackill · Steam 成就图标（9 条 · 铜/银/金）</h1>",
        "<p class='note'>后台传 <code>64/&lt;API&gt;.png</code>（已达成）与 <code>64/&lt;API&gt;_locked.png</code>（未达成），"
        "均 64×64 透明 PNG。等级按获取难度分：进度型铜、通关型银、高难型金。</p>",
        "<table><tr><th>API / 显示名</th><th>等级</th><th>已达成</th><th>未达成</th><th>放大</th></tr>",
    ]
    cls = {"bronze": "b", "silver": "s", "gold": "g"}
    for api, label, tier, _, _ in rows:
        html.append(
            "<tr><td><code>%s</code><br>%s</td><td><span class='tier %s'>%s</span></td>"
            "<td><img class='px' src='64/%s.png'></td>"
            "<td><img class='px' src='64/%s_locked.png'></td>"
            "<td><img class='big' src='512/%s.png'></td></tr>"
            % (api, label, cls[tier], TIER_LABEL[tier], api, api, api)
        )
    html.append("</table></body></html>")
    with io.open(os.path.join(BASE, "preview.html"), "w", encoding="utf-8") as f:
        f.write("\n".join(html))
    print("  preview.html")


if __name__ == "__main__":
    main()
