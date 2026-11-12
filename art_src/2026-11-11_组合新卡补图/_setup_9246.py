# -*- coding: utf-8 -*-
"""9246 宝石兽返工准备：裁出两张实图插画参考 + 生成两版 v2 prompt。

依据（店长 2026-11-11 指名，均查过实图 / 官方设定，不空想）：
  · 影之诗「马纳历亚宝石兽」：深绿森林里的小幻兽，额头宝石能把魔力转成
    草木萌芽的养分。实图 = 奶油棕毛茸茸小狐/松鼠，额上菱形宝石，蓬松大尾，
    蹲在苔石上，蓝眼。card art: pic.87g.com/upload/2018/0320/20180320021822619.png
  · 游戏王「宝玉兽 红玉兽」(Crystal Beast Ruby Carbuncle)：原型耳廓狐、
    四只耳朵，额/背后大红宝石 + 尾尖红珠；整个宝玉兽系列的设定就是
    「身上镶着不同颜色宝石的动物」。card art: img.yugipedia.com/8/85/...
  · 炉石侧对应「宝石魔像」这类镶宝石活物；用户把三家并列，共同指向
    「活生生的奇幻动物 + 嵌宝玉」，不是 v1 那种几何晶体拼的矿石兽。

两版候选各以一张实图为形象参考，画风统一写死为项目赛璐璐；
候选不覆盖 _pending/9246.png，等店长点名再转正。
"""
import os

from PIL import Image

D = os.path.dirname(os.path.abspath(__file__))
R = os.path.join(D, "refs")

# ---- 1. 裁掉卡框 / 文字，只留插画，放大后作为 codex 的形象参考 -------------
CROPS = [
    ("影之诗_马纳历亚宝石兽_进化前.png", (30, 65, 210, 250), "参考A_影之诗小幻兽.png"),
    ("游戏王_宝玉兽红玉兽.png", (118, 288, 968, 1118), "参考B_红玉兽.png"),
]
for src, box, out in CROPS:
    im = Image.open(os.path.join(R, src)).convert("RGB").crop(box)
    scale = 4 if im.width < 400 else 1.2
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    im.save(os.path.join(R, out))
    print("ref:", out, im.size)

# ---- 2. 两版 prompt -------------------------------------------------------
HEAD = """Call the built-in image_gen tool RIGHT NOW and generate exactly one 1024x1024 image. Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. Generate the image FIRST, then reply with a one-line confirmation.

The ATTACHED image is a CREATURE-DESIGN REFERENCE cropped from an existing trading-card illustration. It shows a real, LIVING fantasy ANIMAL with gemstones inlaid in its body (the Shadowverse "Manaria Gem Beast" / Yu-Gi-Oh "Crystal Beast Ruby Carbuncle" archetype: animals that carry a gem). Borrow ONLY that archetype: a small furry / supple animal with a forehead gem, big ears, a bushy tail and expressive eyes. Do NOT copy any card frame, card border, text, letters, numbers, its exact pose, its composition, its background pattern, or its exact colour placement.
Paint a COMPLETELY NEW animal in THIS PROJECT'S STYLE: Japanese anime cel shading, THIN clean black line art, hard-edged 2-3 step shadows, big flat colour blocks, a dark muted softly-blurred background + one bright clearly-lit subject. NO painterly texture, NO photographic rendering.
"""

M_FULL = """
COMPOSITION (MANDATORY): scale the whole animal to about 76% of the frame height, centre it, leave at least 8% empty background at the TOP and at the BOTTOM edge; both ear tips, ALL FOUR paws and the FULL bushy tail must stay completely inside the frame and NEVER be cropped; any loose gem chips or sprouts must also stay inside. Do NOT fill the frame edge-to-edge, pull the camera back. When shrunk to a small 448x403 trading-card window it must still read as ONE living animal, crisp and legible.
"""

TAIL = """
AVOID ALWAYS: NO photorealistic rendering, NO photographic texture, NO 3D render, NO painterly airbrush, NO soft gradients, NO depth-of-field bokeh, NO chibi, NO cute mascot, NO invented humanoid, NO hooded figure, NO running silhouette, NO extra creature, NO text, NO letters, NO numbers, NO watermark, NO logo, NO readable symbols, NO arrows, NO arrow symbols, NO motion-trail lines, NO speed lines, NO graphic marks of any kind, NO playing cards, NO card frames, NO card borders, NO light cones, NO beams of light, NO energy streams, NO glowing fog, NO shockwave rings.
EXTRA AVOID (this is the whole point of the redo): NO body made of geometric crystal plates, NO faceted stone golem, NO mineral robot, NO gem armour plating, NO glass refraction, NO photorealistic gemstone, NO blank lens-dot eyes. The gems are INLAID ORNAMENTS on a LIVING furry animal, NOT the material of its body.
"""

BODY_A = """
SUBJECT — "GEM BEAST" (森林精魄 rare ALLY, ONE small LIVING fantasy animal; on death it combines a card).
A fluffy FOREST PHANTOM BEAST like a tiny fennec-fox / squirrel crossbreed: soft CREAM and PALE-MOSS-GREEN FUR (fur, NOT rock), a round soft body with short fur tufts on the cheeks and chest, TWO large pointed ears with pale inner fur, big warm AMBER eyes with a gentle lively expression, four small soft paws, and ONE large BUSHY TAIL curling up behind it with a paler tip.
Embedded in its FOREHEAD is ONE big clean FACETED EMERALD-GREEN GEM held in a simple leaf-shaped gold setting; two much smaller matching green gems sit on its shoulders. A few tiny loose gem chips and fresh GREEN SPROUTS rest on the mossy stone under its paws — the gem quietly feeds the forest, echoing the Shadowverse gem beast whose forehead gem turns magic into new plant growth. The gems are flat cel-shaded colour blocks with crisp black outlines, NOT glass, NOT glowing.
Seated calmly on a mossy stone, head slightly tilted, three-quarter view facing left. It is a real breathing ANIMAL with fur and expression — appealing, but NORMAL animal proportions, NOT a chibi mascot.
BACKGROUND: dark blurred deep-teal forest interior, softly out of focus, one warm key light from upper left, a few small pale pollen motes.
"""

BODY_B = """
SUBJECT — "GEM BEAST" (森林精魄 rare ALLY, ONE small LIVING fantasy animal; on death it combines a card).
A round supple little FOX-LIKE fantasy beast with smooth short PALE-JADE / moss-green FUR (fur, NOT faceted stone): plump rounded body, a big head with TWO PAIRS OF EARS — one pair of very large pointed fennec ears plus one smaller pair of rounded leaf-ears tucked inside (four ears total, the signature of Yu-Gi-Oh "Crystal Beast Ruby Carbuncle") — large vivid RED-AMBER round eyes with a bright curious expression, small soft paws, and ONE long curling tail ending in a single round RED RUBY bead.
Behind its shoulders rises ONE big clean FACETED DEEP-CRIMSON RUBY crystal, and a smaller matching ruby sits at the centre of its forehead. Body stays SOFT and ANIMAL: visible fur, rounded limbs, expressive face — the gems are INLAID ORNAMENTS carried by a living creature, NOT the material of its body. NO geometric crystal-assembled torso, NO mineral plates, NO robot, NOT chibi.
Light playful mid-step pose with all four paws visible, three-quarter view facing left, tail curling in one clean arc. Appealing but NORMAL animal proportions.
BACKGROUND: dark blurred deep-teal forest with faint muted crimson colour accents (flat, NO bokeh), softly out of focus, one warm key light from upper left.
"""

VARIANTS = [("_v2a", BODY_A), ("_v2b", BODY_B)]
for suffix, body in VARIANTS:
    txt = HEAD + body + M_FULL + TAIL
    path = os.path.join(D, "9246_宝石兽%s.txt" % suffix)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(txt)
    print("prompt:", os.path.basename(path), len(txt), "chars")
