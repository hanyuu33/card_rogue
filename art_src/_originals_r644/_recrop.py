"""R644 老虎 9038 卡图重新裁切（可重跑）

背景：卡图区是 448x404 素材按 `CardFace.cover_region()` 居中裁成 **1.51:1** 的横带
（`UiTheme.CARD_ART_RATIO = 0.662` → 宽/高 = 1/0.662）。旧素材把虎头放在画面最上沿，
居中裁切把整颗脑袋裁掉了（卡上只看得到胸口以下 + 兔子赤狐）。

做法：从 1254x1254 方形原图重新裁 **1.51:1** 的横带（虎头 + 全身 + 岩顶），缩到
448x297，再上下各补一条「模糊边缘带」填成 448x404 —— 补的这两条正好落在
居中裁切会丢掉的行（0..52 / 351..403），卡面上看不见。

跑法：python _recrop.py    （在仓库根目录执行）
"""
import os
from PIL import Image, ImageFilter

SRC = "art_src/_originals_r644/9038_square_1254.png"
OUT = ["assets/pics/9038.png", "assets/pics/_pending/9038.png"]

RATIO = 1.0 / 0.662          # 卡图区宽高比（UiTheme.CARD_ART_RATIO）
W, H = 448, 404              # 全项目卡图的统一尺寸（宽高都必须能被 4 整除）
BAND_H = 297                 # 卡图区实际显示的行数 = round(448 / RATIO)
BAND_TOP = 53                # 居中裁切会丢掉的上沿行数 = (404 - 297) / 2
CROP_TOP = 43                # 横带在方形原图里的起始行（头顶留约 24px 余量）
# 起点怎么定：方形图里虎头顶在 y≈67（耳尖），43 起裁 → 留 24px。
# 想再压一点头顶留白就调小；想多露岩石就调大（会同时往下吃掉脚）。

src = Image.open(SRC).convert("RGB")
band_h = int(round(src.width / RATIO))
band = src.crop((0, CROP_TOP, src.width, CROP_TOP + band_h))
band = band.resize((W, BAND_H), Image.LANCZOS)

full = Image.new("RGB", (W, H), (0, 0, 0))
pad_t = BAND_TOP
pad_b = H - BAND_H - BAND_TOP
strip_t = band.crop((0, 0, W, 1)).resize((W, pad_t)).filter(ImageFilter.GaussianBlur(4))
strip_b = band.crop((0, BAND_H - 1, W, BAND_H)).resize((W, pad_b)).filter(ImageFilter.GaussianBlur(4))
full.paste(strip_t, (0, 0))
full.paste(band, (0, pad_t))
full.paste(strip_b, (0, pad_t + BAND_H))

for p in OUT:
    os.makedirs(os.path.dirname(p), exist_ok=True)
    full.convert("RGBA").save(p, optimize=True)
    print("wrote", p, Image.open(p).size)
