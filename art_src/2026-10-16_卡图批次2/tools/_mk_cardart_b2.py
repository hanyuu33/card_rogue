import os
from PIL import Image

GEN = r"D:\work\gen_raw"
PICS = r"D:\work\card_rogue\assets\pics"
RATIO = 1.112
OUT_W, OUT_H = 448, 403

JOBS = [
    ("A_walking_treant_monster__a_hu_2026-10-16T01-34-31.png", "8003"),
    ("A_shadow_wraith_monster_made_o_2026-10-16T01-34-36.png", "8005"),
    ("A_sturdy_humanoid_mechanical_c_2026-10-16T01-34-33.png", "8026"),
    ("A_large_powerful_ordinary_rhin_2026-10-16T01-34-35.png", "9016"),
    ("A_chubby__plump__round_cute_du_2026-10-16T01-34-34.png", "9012"),
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
