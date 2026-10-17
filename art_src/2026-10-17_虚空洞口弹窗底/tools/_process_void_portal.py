# -*- coding: utf-8 -*-
"""R197 虚空洞口弹窗底：raw AI 图 → 768x540 工程素材。

流程：去水印（左下角镜像盖右下角）→ 居中裁 768:540 → 缩到 768x540 →
中心强制纯黑（圆盘 + 羽化边）→ 写 assets/ui/void_portal.png + 验收图。
"""
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = r"D:\work\card_rogue"
RAW = r"D:\work\gen_raw\Wide_landscape_dark_fantasy_vo_2026-10-17T00-58-16.png"
OUT = os.path.join(ROOT, "assets", "ui", "void_portal.png")
AR_DIR = os.path.join(ROOT, "art_src", "2026-10-17_虚空洞口弹窗底")
os.makedirs(AR_DIR, exist_ok=True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)

TARGET_W, TARGET_H = 768, 540
R_BLACK = 225          # 纯黑圆盘半径（几何中心），代码侧文字区角距 210 < 225
FEATHER = 16
TEXT_HALF_W, TEXT_HALF_H = 168, 126

im = Image.open(RAW).convert("RGB")
W, H = im.size
print("raw size:", W, H)

# 1) 去水印：右下角 <- 左下角水平镜像
pw, ph = 340, 130
left = im.crop((0, H - ph, pw, H)).transpose(Image.FLIP_LEFT_RIGHT)
im.paste(left, (W - pw, H - ph))

# 2) 居中裁到目标比例
target_ar = TARGET_W / TARGET_H
if W / H > target_ar:
    cw, ch = int(H * target_ar), H
else:
    cw, ch = W, int(W / target_ar)
x0, y0 = (W - cw) // 2, (H - ch) // 2
im = im.crop((x0, y0, x0 + cw, y0 + ch))
print("crop:", im.size)

# 3) 缩放
im = im.resize((TARGET_W, TARGET_H), Image.LANCZOS)

# 4) 量环内半径（沿水平/垂直中线找亮度 > 45 处，打印参考）
px = im.load()
cx, cy = TARGET_W // 2, TARGET_H // 2
for axis in ("h", "v"):
    edge = None
    for d in range(0, (TARGET_W if axis == "h" else TARGET_H) // 2):
        r, g, b = px[cx + d, cy] if axis == "h" else px[cx, cy + d]
        if (r + g + b) / 3 > 45:
            edge = d
            break
    print("ring inner (%s):" % axis, edge)

# 5) 中心强制纯黑（外缘羽化）
mask = Image.new("L", (TARGET_W, TARGET_H), 0)
md = ImageDraw.Draw(mask)
for i in range(FEATHER):
    a = int(255 * (i + 1) / FEATHER)
    md.ellipse((cx - R_BLACK + i, cy - R_BLACK + i,
                cx + R_BLACK - i, cy + R_BLACK - i), fill=a)
md.ellipse((cx - R_BLACK + FEATHER, cy - R_BLACK + FEATHER,
            cx + R_BLACK - FEATHER, cy + R_BLACK - FEATHER), fill=255)
im = Image.composite(Image.new("RGB", (TARGET_W, TARGET_H), (0, 0, 0)), im, mask)

im.save(OUT)
print("saved:", OUT)

# 6) 验收图：画出代码侧文字区框 + 示例白字
prev = im.copy()
pd = ImageDraw.Draw(prev)
tx0, ty0 = cx - TEXT_HALF_W, cy - TEXT_HALF_H
tx1, ty1 = cx + TEXT_HALF_W, cy + TEXT_HALF_H
pd.rectangle((tx0, ty0, tx1, ty1), outline=(90, 220, 140), width=2)
try:
    f = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 16)
except Exception:
    f = ImageFont.load_default()
pd.text((cx, ty0 + 14), "敌方效果", font=f, fill=(255, 255, 255), anchor="mm")
pd.text((cx, cy - 40), "使魔之力", font=f, fill=(255, 255, 255), anchor="mm")
pd.text((cx, cy), "每回合开始时，使魔鸭子", font=f, fill=(230, 230, 235), anchor="mm")
pd.text((cx, cy + 22), "力量 +1（永久）", font=f, fill=(230, 230, 235), anchor="mm")
pd.text((cx, ty1 - 16), "点击任意处继续", font=f, fill=(160, 160, 170), anchor="mm")
prev.save(os.path.join(AR_DIR, "preview_text_region.png"))
print("preview saved")
