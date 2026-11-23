"""R843g 老虎 9038：从无水印方形原图重建完整高度的卡图净图（可重跑）。

R644 曾为旧的居中裁切在上下填模糊保护带；R843g 卡图窗增高并改为顶部优先，
继续沿用那张会把模糊带重新露出来。这里直接保留方形原图的完整纵向内容，
只按项目 448x404 规格裁掉左右多余边，不再添加任何模糊带或水印遮挡。

跑法：python art_src/_originals_r644/_recrop.py（在仓库根目录执行）。
"""
import os
from PIL import Image

SRC = "art_src/_originals_r644/9038_square_1254.png"
OUT = ["assets/pics/9038.png", "assets/pics/_pending/9038.png"]
W, H = 448, 404

src = Image.open(SRC).convert("RGB")
sw, sh = src.size
target_ratio = W / float(H)
crop_w = min(sw, round(sh * target_ratio))
left = (sw - crop_w) // 2
full = src.crop((left, 0, left + crop_w, sh)).resize((W, H), Image.LANCZOS)

for p in OUT:
    os.makedirs(os.path.dirname(p), exist_ok=True)
    full.convert("RGBA").save(p, optimize=True)
    print("wrote", p, Image.open(p).size)
