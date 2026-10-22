import os
from PIL import Image

D = os.path.dirname(os.path.abspath(__file__))
jobs = [
    # (源文件, 输出名, 上切比例)
    ("FULL_BLEED_wide_cinematic_key__2026-10-22T07-16-40.png", "CG_guinea_pig_bard_hero_2560x1440.png", 0.15),
    ("FULL_BLEED_wide_cinematic_key__2026-10-22T07-15-33.png", "CG_guinea_pig_bard_night_2560x1440.png", 0.25),
    ("FULL_BLEED_wide_cinematic_anim_2026-10-22T07-15-18.png", "CG_guinea_pig_bard_anime_2560x1440.png", 0.25),
]

for src, out, ratio in jobs:
    im = Image.open(os.path.join(D, src)).convert("RGB")
    W, H = im.size
    th = int(round(W * 9 / 16))
    cut = H - th
    top = int(cut * ratio)
    c = im.crop((0, top, W, top + th))
    g = c.convert("L").load()
    w, h = c.size
    hot = sum(1 for y in range(h - 130, h) for x in range(w - 340, w) if g[x, y] > 205)
    c.resize((2560, 1440), Image.LANCZOS).save(os.path.join(D, out))
    print(f"{out}: {W}x{H} -> {c.size} (top {top}) bright_px_br={hot}")
