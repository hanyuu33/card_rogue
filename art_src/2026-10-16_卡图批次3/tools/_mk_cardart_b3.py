import os
from PIL import Image

GEN = r"D:\work\gen_raw"
PICS = r"D:\work\card_rogue\assets\pics"
RATIO = 1.112
OUT_W, OUT_H = 448, 403

JOBS = [
    ("Keep_this_exact_anime_characte_2026-10-16T01-49-29.png", "8002_forest"),
    ("Keep_this_exact_anime_characte_2026-10-16T01-50-11.png", "8002_shadow"),
    ("Keep_this_exact_anime_characte_2026-10-16T01-50-42.png", "8002_mech"),
    ("A_simple_ordinary_wooden_fence_2026-10-16T01-51-14.png", "8001"),
    ("Keep_this_exact_composition__a_2026-10-16T01-52-57.png", "9072"),
]

for src, cid in JOBS:
    im = Image.open(os.path.join(GEN, src)).convert("RGB")
    w, h = im.size
    target_w = int(h * RATIO)
    if target_w <= w:
        x0 = (w - target_w) // 2
        box = (x0, 0, x0 + target_w, h)
    else:
        target_h = int(w / RATIO)
        y0 = (h - target_h) // 2
        box = (0, y0, w, y0 + target_h)
    im = im.crop(box).resize((OUT_W, OUT_H), Image.LANCZOS)
    dst = os.path.join(PICS, cid + ".png")
    im.save(dst, "PNG")
    print(cid, os.path.getsize(dst), "bytes")
print("done")
