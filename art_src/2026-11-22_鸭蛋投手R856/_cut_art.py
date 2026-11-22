# -*- coding: utf-8 -*-
"""R856：把 codex 出的 raw 图裁成卡图素材（448x404），并各出「双口径预览」。

口径（ART.md「卡图区口径 R854」）：
  卡图区 = 卡面高 × 0.540，素材 448×404 → 图区 448:291。
  战斗读 **0..291**、商店 / 图鉴读居中 **56..347**，交集只有 56..291。

两种处理：
  * 9284 鸭蛋投手 —— 与既有卡图同口径：按 448:404 比例**顶部优先**裁切再缩放。
    鸭子太高（头 10% / 脚 92%），任何裁法都装不进 235 行的交集带，
    所以按惯例「卡图显示上半身」（低头、举起的金蛋、前指的手都在带内）。
  * 9285 金鸭蛋 —— 单物件：等比缩放后**正好填满交集带 56..291**（高 235、顶 56），
    两个口径都完整、无裁切。实测：高 300 居中时战斗口径切掉蛋底 30 行、商店口径上下各切 5 行，
    而交集带内可行上限是 h<=178（居中）——所以不能居中，必须顶到 56 行起算，
    这样 h 可以做到 235（= 291-56），是全图最大的无裁切尺寸。
  * fx_egg_gain —— 特效：黑底按亮度转 alpha（RGB 归一化到满亮，避免黑边；
    与既有 bx_* 一致：低 alpha 区 RGB 仍 130+），256×256 RGBA。
"""
import os

from PIL import Image

D = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(D, "raw")
OUT = os.path.join(D, "cut")
PREV = os.path.join(D, "preview")
os.makedirs(OUT, exist_ok=True)
os.makedirs(PREV, exist_ok=True)

W, H = 448, 404
ART_TOP = 291          # 战斗口径
ART_SHOP = (56, 347)   # 商店 / 图鉴口径


def cut_top_fill(src, dst):
    """按 448:404 比例顶部优先裁切 → 缩放。"""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    keep_h = int(round(w * H / W))
    if keep_h <= h:
        im2 = im.crop((0, 0, w, keep_h))
    else:
        keep_w = int(round(h * W / H))
        im2 = im.crop(((w - keep_w) // 2, 0, (w - keep_w) // 2 + keep_w, h))
    im2 = im2.resize((W, H), Image.LANCZOS)
    im2.save(dst)
    return im2


def cut_contain(src, dst, box_h):
    """等比缩放整张内容到指定高度，居中放白底。"""
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    scale = box_h / float(h)
    nw = int(round(w * scale))
    im2 = im.resize((nw, box_h), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H), (255, 255, 255))
    canvas.paste(im2, ((W - nw) // 2, (H - box_h) // 2), im2)
    canvas.save(dst)
    return canvas


def cut_band_fill(src, dst, top, bottom, fill=0.92):
    """等比缩放后填满 top..bottom 这条带（再留 fill 比例），带内居中放白底。

    交集带 56..291 → 高 235。这是「两个口径都完整」能给出的最大尺寸：
    居中方案（整张 404 上下留一样）上限只有 h<=178，因为 (404-h)/2 必须 >= 56。
    fill=0.92 让蛋底离带边留 ~9 行，战斗口径下不贴边。
    """
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    band_h = bottom - top
    box_h = int(round(band_h * fill))
    scale = box_h / float(h)
    nw = int(round(w * scale))
    im2 = im.resize((nw, box_h), Image.LANCZOS)
    y = top + (band_h - box_h) // 2
    canvas = Image.new("RGB", (W, H), (255, 255, 255))
    canvas.paste(im2, ((W - nw) // 2, y), im2)
    canvas.save(dst)
    return canvas


def cut_fx(src, dst, size=256):
    """黑底特效图 → RGBA：alpha 取亮度，RGB 归一化到满亮（防黑边）。

    与既有 bx_* 同款：低 alpha 区的 RGB 仍是亮色（130+），
    所以叠加时不会出现一圈脏黑边。lum < 0.06 视为纯背景，直接全透明
    （codex 出的图黑底常带一点压缩噪声，不清会把方形底噪画出来）。
    """
    im = Image.open(src).convert("RGB").resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size))
    sp, dp = im.load(), out.load()
    for y in range(size):
        for x in range(size):
            r, g, b = sp[x, y]
            lum = (max(r, g, b)) / 255.0
            if lum <= 0.06:
                dp[x, y] = (0, 0, 0, 0)
                continue
            # 归一化到满亮，保住色相（白金核心仍是白，橙金光环仍是橙金）
            k = 255.0 / max(r, g, b)
            nr, ng, nb = int(r * k), int(g * k), int(b * k)
            a = int(round(min(1.0, lum ** 1.35) * 255))
            dp[x, y] = (nr, ng, nb, a)
    out.save(dst)
    return out


def preview(im, dst, label):
    """双口径并排：左 = 战斗 0..291，右 = 商店居中 56..347。"""
    top = im.crop((0, 0, W, ART_TOP))
    shop = im.crop((0, ART_SHOP[0], W, ART_SHOP[1]))
    pad, gap, head = 12, 16, 30
    total_h = head + max(top.height, shop.height) + pad * 2
    total_w = pad * 2 + top.width + gap + shop.width
    sheet = Image.new("RGB", (total_w, total_h), (34, 34, 38))
    sheet.paste(top, (pad, head + pad))
    sheet.paste(shop, (pad + top.width + gap, head + pad))
    sheet.save(dst)
    print("  preview -> %s  (%s)" % (os.path.basename(dst), label))


jobs = [
    ("9284_鸭蛋投手.png", "9284.png", "top", None),
    ("9285_金鸭蛋.png", "9285.png", "band", None),
]

for raw_name, out_name, mode, box_h in jobs:
    src = os.path.join(RAW, raw_name)
    if not os.path.exists(src):
        print("SKIP %s（raw 不存在）" % raw_name)
        continue
    dst = os.path.join(OUT, out_name)
    if mode == "top":
        im = cut_top_fill(src, dst)
    elif mode == "band":
        im = cut_band_fill(src, dst, ART_SHOP[0], ART_TOP)
    else:
        im = cut_contain(src, dst, box_h)
    print("OK %s -> cut/%s %s" % (raw_name, out_name, im.size))
    preview(im, os.path.join(PREV, out_name.replace(".png", "_compare.png")),
            "%s  |左 0..291 右 56..347" % out_name)

# ---- 特效：黑底转 alpha，并叠在深色场地底上看实际观感 ----
fx_raw = os.path.join(RAW, "fx_egg_gain.png")
if os.path.exists(fx_raw):
    fx_dst = os.path.join(OUT, "bx_egg_gain.png")
    fx = cut_fx(fx_raw, fx_dst)
    print("OK fx_egg_gain.png -> cut/bx_egg_gain.png %s" % (fx.size,))
    # 256 = 战场格内尺寸；再放大一倍模拟大特效
    sheet = Image.new("RGB", (256 * 2 + 36, 256 + 24), (30, 32, 38))
    for i, s in enumerate((256, 512)):
        tile = fx.resize((s, s), Image.LANCZOS)
        layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        layer.alpha_composite(tile)
        base = Image.new("RGBA", (s, s), (46, 40, 34, 255))
        base.alpha_composite(layer)
        sheet.paste(base.convert("RGB"), (12 + i * (256 + 12), 12))
    sheet.save(os.path.join(PREV, "bx_egg_gain_onboard.png"))
    print("  preview -> bx_egg_gain_onboard.png  (左 256 / 右 512，深色底)")
else:
    print("SKIP fx_egg_gain.png（raw 不存在）")
