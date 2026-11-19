# -*- coding: utf-8 -*-
"""R823：按 alpha 裁安全边距，缩到 400x92；不按亮度抠图。"""
from pathlib import Path
from PIL import Image

ROOT = Path(r"E:/work/card_rogue")
SRC = ROOT / "art_src/2026-11-19_存档返回按钮_R823/raw/return_button_v1.png"
DST = ROOT / "assets/ui/return_context_button.png"
im = Image.open(SRC).convert("RGBA")
alpha = im.getchannel("A")
print("source", im.size, "alpha_extrema", alpha.getextrema())
bbox = alpha.getbbox()
assert bbox is not None, "整图没有可见像素"
print("alpha_bbox", bbox)
im = im.crop(bbox)
# 保留完整描边与箭头，缩到可见区 400x84；上下各 4px 透明安全带。
im.thumbnail((400, 84), Image.Resampling.LANCZOS)
out = Image.new("RGBA", (400, 92), (0, 0, 0, 0))
out.alpha_composite(im, ((400 - im.width) // 2, (92 - im.height) // 2))
out.save(DST)
print("saved", DST, out.size, DST.stat().st_size)
