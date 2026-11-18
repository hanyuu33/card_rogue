# -*- coding: utf-8 -*-
"""R797 图标：钻头 6077 重做（螺旋+斜置）/ 龟壳 6078 / 河豚 7015。"""
import hashlib
import subprocess
import sys

ROOT = "E:/work/card_rogue/"          # _make_r755_icons 的 import 会动这里的两张旧图
WATCH = ["assets/ui/trap_icon_7012.png", "assets/ui/ui_tool_swap.png"]
WT = "E:/tmp/wt794/"


def md5(p):
    return hashlib.md5(open(ROOT + p, "rb").read()).hexdigest()


before = {p: md5(p) for p in WATCH}
sys.path.insert(0, WT + "tools")
import _make_r755_icons as R755   # noqa: E402
R755.ROOT = WT   # cut() 会自己前缀 ROOT，这里改成构造工作树
for p in WATCH:
    if md5(p) != before[p]:
        subprocess.run(["git", "checkout", "--", p], cwd=ROOT, check=True)
        print("restored", p)

from PIL import Image, ImageDraw   # noqa: E402

SRC = "E:/tmp/_art_wip_r797/"
JOBS = [
    ("A_cute_hand_drawn_cartoon_game_2026-11-18T08-22-12.png", "6077", "assets/ui/relic_icon_6077.png"),
    ("A_cute_hand_drawn_cartoon_game_2026-11-18T08-21-22.png", "6078", "assets/ui/relic_icon_6078.png"),
    ("A_cute_hand_drawn_cartoon_game_2026-11-18T08-21-42.png", "7015", "assets/ui/trap_icon_7015.png"),
]

for src, tag, out in JOBS:
    im = Image.open(SRC + src).convert("RGB")
    w, h = im.size
    d = ImageDraw.Draw(im)
    d.rectangle([int(w * 0.86), int(h * 0.93), w, h], fill=(255, 255, 255))
    tmp = SRC + "_clean_%s.png" % tag
    im.save(tmp)
    R755.cut(tmp, out, pad_pct=0.07)
    print("wrote", out)

# 44px 道具栏对照（验收「认不认得出」用）
icons = ["assets/ui/relic_icon_6076.png", "assets/ui/relic_icon_6077.png",
         "assets/ui/relic_icon_6078.png", "assets/ui/trap_icon_7013.png",
         "assets/ui/trap_icon_7014.png", "assets/ui/trap_icon_7015.png",
         "assets/ui/trap_icon_7006.png"]
cell, gap = 44, 12
sheet = Image.new("RGBA", (len(icons) * (cell + gap) + gap, cell + 2 * gap), (24, 26, 32, 255))
for i, rel in enumerate(icons):
    im = Image.open(WT + rel).convert("RGBA").resize((cell, cell), Image.LANCZOS)
    sheet.alpha_composite(im, (gap + i * (cell + gap), gap))
sheet.save(WT + "art_src/2026-11-18_钻头重做与河豚_R797/_preview_44px.png")
print("preview ok")
