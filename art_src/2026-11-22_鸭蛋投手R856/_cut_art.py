# -*- coding: utf-8 -*-
"""R856：把 codex 出的 raw 图裁成卡图素材（448x404），并各出「双口径预览」。

口径（ART.md「卡图区口径 R854」）：
  卡图区 = 卡面高 × 0.540，素材 448×404 → 图区 448:291。
  战斗读 **0..291**、商店 / 图鉴读居中 **56..347**，交集只有 56..291。

所有卡图都是**满幅场景插画**（和 9022 鸭蛋 / 9179 惊奇盒子 同一画法），
所以两张都走**顶部优先**裁切：按 448:404 比例取上部再缩放。

⚠️ R856 走过一次弯路：9285 第一版被当成「白底商品图」出图（提示词里明写
`plain pure white background`），再看「单物件居中」的裁法——两道一起把卡图
做成了贴图。店长当场否掉：**金鸭蛋是刚被扔出去的，它不在巢里、也不在白底上。**
那条「单物件填 56..291 交集带」的方案随之作废（它只对白底物件成立），
函数 `cut_contain` / `cut_band_fill` 一并删掉，免得下次又被当惯例抄一遍。
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


def cut_box(src, dst, box):
    """按原始像素窗口裁（box = 左, 上, 右, 下），窗口须已接近 448:404。

    R856 9285：远景图 1536×1024 里蛋太小（只占画幅 23% 高，落地到 404 上只有 93 行，
    战场格子会看不清），所以把镜头往蛋推近。窗口由「蛋心落在交集带 56..291 的中线
    173 行」反推：y0 = 蛋心y - 173 × 窗高 / 404。实测蛋心 ≈ (777, 436)。
    """
    im = Image.open(src).convert("RGB").crop(box)
    im2 = im.resize((W, H), Image.LANCZOS)
    im2.save(dst)
    return im2


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
    ("9284_鸭蛋投手.png", "9284.png", None),
    # 蛋心 (828, 371)，推近窗口 926×835 → 蛋占 98..248 行（交集带 56..291 内），高宽比 1.25
    ("9285_金鸭蛋_fly_w2.png", "9285.png", (365, 13, 1291, 848)),
]

for raw_name, out_name, box in jobs:
    src = os.path.join(RAW, raw_name)
    if not os.path.exists(src):
        print("SKIP %s（raw 不存在）" % raw_name)
        continue
    dst = os.path.join(OUT, out_name)
    im = cut_box(src, dst, box) if box else cut_top_fill(src, dst)
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
