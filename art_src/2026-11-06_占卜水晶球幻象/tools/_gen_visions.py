# -*- coding: utf-8 -*-
"""把 4 张 AI 幻象图裁成球内素材，并合到原背景上出预览。

产出：
  assets/ui/div_vision_1..4.png        （256×256 圆形羽化）
  assets/ui/div_orb_glass.png          （玻璃壳，ADD 叠加用）
  %TEMP%/vision_preview_1..4.png       （贴回原背景的验收图）
"""
import os
from PIL import Image, ImageDraw, ImageFilter

BG = r"D:/work/card_rogue/assets/ui/bg_divination.png"
UI = r"D:/work/card_rogue/assets/ui"
GLASS = r"D:/work/card_rogue/art_src/2026-11-06_占卜水晶球幻象/processed/div_orb_glass.png"

# 原背景里球的几何（1280×720 基准坐标）
BCX, BCY, BR = 639.0, 188.0, 89.0
OUT = 256

# AI 图：球心 / 半径 / 取内容区比例
# 末两项是单张调色：gamma（<1 提亮中间调）+ lift（整体亮度增益）
#   —— 球在屏幕只有 178px，荆棘/宴席这类「细节型」画面不提亮就糊成一团。
SRC = [
    (1, "whale",  r"D:/work/gen_raw/div_orb/Vision_seen_inside_a_glowing_c_2026-11-06T08-14-32.png", 507, 495, 300, 1.14, 1.00),
    (2, "liquid", r"D:/work/gen_raw/div_orb/Vision_seen_inside_a_glowing_c_2026-11-06T08-15-00.png", 510, 504, 500, 1.10, 1.06),
    (3, "thorn",  r"D:/work/gen_raw/div_orb/Vision_seen_inside_a_glowing_c_2026-11-06T08-15-18.png", 515, 510, 380, 0.96, 1.36),
    (4, "feast",  r"D:/work/gen_raw/div_orb/Vision_seen_inside_a_glowing_c_2026-11-06T08-15-38.png", 512, 492, 342, 0.98, 1.26),
]
KEEP = 0.82          # 取球半径的多少（AI 自绘的球壳在 0.85~0.95，这里整段避开）
GAMMA = 1.14         # 对比：>1 压暗中间调，让球里的景象更「深」
FEATHER = 0.12       # 外圈羽化比例


def circle_mask(size, feather):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([0, 0, size - 1, size - 1], fill=255)
    # 缩小再放大做羽化
    inner = int(size * (1.0 - feather))
    m2 = Image.new("L", (size, size), 0)
    d2 = ImageDraw.Draw(m2)
    d2.ellipse([0, 0, size - 1, size - 1], fill=255)
    m2 = m2.filter(ImageFilter.GaussianBlur(radius=size * feather * 0.5))
    return m2


mask = circle_mask(OUT, FEATHER)
mask.save(r"C:/Users/Administrator/AppData/Local/Temp/vision_mask.png")

def post(sq, gamma, lift):
    """径向暗角 + 单张调色：球内边缘沉下去贴住玻璃壁，整体亮按 lift 提。"""
    w, h = sq.size
    px = sq.load()
    cx = cy = (w - 1) / 2.0
    R = w / 2.0
    for y in range(h):
        for x in range(w):
            dx, dy = x - cx, y - cy
            rn = ((dx * dx + dy * dy) ** 0.5) / R
            if rn <= 0.45:
                k = 1.0
            else:
                t = min(1.0, (rn - 0.45) / 0.55)
                k = 1.0 - 0.62 * (t * t * (3 - 2 * t))
            r, g, b = px[x, y]
            def c(v):
                return 255.0 * ((v / 255.0) ** gamma) * lift
            px[x, y] = (min(255, int(c(r) * k)),
                        min(255, int(c(g) * k)),
                        min(255, int(c(b) * k)))
    return sq


# ---- 1) 每张裁圆 ----
visions = []
for idx, name, path, cx, cy, r, gm, lf in SRC:
    im = Image.open(path).convert("RGB")
    half = r * KEEP
    box = (int(cx - half), int(cy - half), int(cx + half), int(cy + half))
    sq = im.crop(box).resize((OUT, OUT), Image.LANCZOS)
    sq = post(sq, gm, lf)
    # 轻微提饱和 + 压一档亮度，贴近原背景的哑光冷调
    sq = sq.filter(ImageFilter.UnsharpMask(radius=1.2, percent=45, threshold=3))
    out = Image.new("RGBA", (OUT, OUT), (0, 0, 0, 0))
    out.paste(sq, (0, 0))
    out.putalpha(mask)
    p = os.path.join(UI, "div_vision_%d.png" % idx)
    out.save(p)
    visions.append((idx, name, out))
    print("saved", p, "box", box)

# ---- 2) 贴回原背景出预览 ----
glass = Image.open(GLASS).convert("RGBA")
bg = Image.open(BG).convert("RGBA")
size_on_bg = int(BR * 2)          # 178
ox = int(round(BCX - BR))
oy = int(round(BCY - BR))

for idx, name, vis in visions:
    canvas = bg.copy()
    v = vis.resize((size_on_bg, size_on_bg), Image.LANCZOS)
    canvas.alpha_composite(v, (ox, oy))
    g = glass.resize((size_on_bg, size_on_bg), Image.LANCZOS)
    # ADD 混合
    region = canvas.crop((ox, oy, ox + size_on_bg, oy + size_on_bg)).convert("RGB")
    gr = g.convert("RGB")
    gp, rp = gr.load(), region.load()
    ap = g.split()[3].load()
    for y in range(size_on_bg):
        for x in range(size_on_bg):
            a = ap[x, y] / 255.0
            if a <= 0:
                continue
            p0 = rp[x, y]
            g0 = gp[x, y]
            rp[x, y] = (min(255, int(p0[0] + g0[0] * a)),
                        min(255, int(p0[1] + g0[1] * a)),
                        min(255, int(p0[2] + g0[2] * a)))
    canvas.paste(region, (ox, oy))
    canvas.convert("RGB").save(
        r"C:/Users/Administrator/AppData/Local/Temp/vision_preview_%d.png" % idx)

# ---- 3) 四联验收拼图（裁球周围一块放大看） ----
pad = 60
crop_box = (ox - pad, oy - pad, ox + size_on_bg + pad, oy + size_on_bg + pad)
cw, ch = crop_box[2] - crop_box[0], crop_box[3] - crop_box[1]
sheet = Image.new("RGB", (cw * 2, ch * 2), (0, 0, 0))
for idx, name, vis in visions:
    p = r"C:/Users/Administrator/AppData/Local/Temp/vision_preview_%d.png" % idx
    tile = Image.open(p).crop(crop_box)
    sheet.paste(tile, (((idx - 1) % 2) * cw, ((idx - 1) // 2) * ch))
sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.LANCZOS)
sheet.save(r"C:/Users/Administrator/AppData/Local/Temp/vision_sheet.png")
print("sheet", sheet.size)
