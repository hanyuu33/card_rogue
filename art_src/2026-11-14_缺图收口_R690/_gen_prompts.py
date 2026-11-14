# -*- coding: utf-8 -*-
"""R690 缺图收口：2 张 prompt 生成器（9248 种子 / 9249 被眷顾者）。

口径（店长 2026-11-14）：「当前缺失图片的卡，委托 codex 生成」。
缺图来源 = `python _art_index.py --todo`：共 2 张，均为 R689 新增的森林精魄卡。

遵守的既有纪律（见 art_src/2026-11-10_图生图批量/README.md）：
  规范 A  非盟友/工事卡不得凭空捏造人形/生物 → 9248 只画物件
  规范 B  非卡牌相关效果不得出现卡牌 → 两张都不放卡牌元素
  纪律 K  角色卡可以借职业 CG，但要换姿势＋换背景＋写死占幅（9249 借 class_cg_forest）
  纪律 M  借职业 CG 必须单独写死头身比，禁用「NOT chibi」这类含糊措辞（9249）
  纪律 E  全身主体写死 76% 占幅 + 上下 8% 留白；半身像写死头顶/双耳/双手完整
  纪律 H  先读 effect_text；不画光柱/光雾/粒子爆炸
  R644   素材统一 448x404，卡面只显示第 53..350 行 → 主体必须落在中间横带
"""
import os

D = os.path.dirname(os.path.abspath(__file__))

HEAD_STYLE = """Call the built-in image_gen tool RIGHT NOW and generate exactly one 1024x1024 image. Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. Generate the image FIRST, then reply with a one-line confirmation.

The ATTACHED image is a STYLE REFERENCE ONLY: copy its drawing technique (Japanese anime cel shading, THIN clean black line art, hard-edged 2-3 step shadows, big flat colour blocks, dark muted softly-blurred background + bright clearly-lit subject). Do NOT copy its character, its pose, its stance, its props, its scene, its composition, its scale, or its colour placement. Paint a COMPLETELY DIFFERENT subject.
"""

HEAD_CHAR = """Call the built-in image_gen tool RIGHT NOW and generate exactly one 1024x1024 image. Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. Generate the image FIRST, then reply with a one-line confirmation.

The ATTACHED image is the CHARACTER DESIGN reference: keep this character EXACTLY as shown — a little girl with long straight silvery-cream hair and soft braided side strands, large amber-gold eyes, black pointed animal ears with pale inner fur, small green leaves and white daisy flowers tucked into her hair, a sleeveless dress made of layered green leaves, and a big black fluffy tail. Reproduce her face, hair, ears, leaf dress and colour placement faithfully. Repaint her in the project's cel-shaded card-art style (Japanese anime cel shading, THIN clean black line art, hard-edged 2-3 step shadows, big flat colour blocks, dark blurred background + bright clearly-lit subject; NO photorealistic, NO 3D render, NO soft airbrush gradients).

CRITICAL — BODY PROPORTIONS. Do NOT draw a grown-up teenager or an adult woman; she MUST match the reference EXACTLY:
She is a SMALL CHILD: head-to-body ratio about 1:4, a LARGE ROUND HEAD almost as wide as her narrow little shoulders, big round amber-gold eyes set low on a soft round child face, a tiny short nose, short soft rounded arms and small hands with short fingers, a short compact torso and thin child limbs. In this HALF-BODY portrait her head must occupy about ONE THIRD of the visible figure height.
DO NOT elongate the neck, DO NOT narrow or lengthen the head, DO NOT widen the shoulders, DO NOT lengthen or slim the arms, DO NOT give her a mature face, an adult bust or an adult waist, DO NOT make her look tall or willowy. Keep the reference's childlike silhouette exactly. This is NOT a chibi mascot — it is the same little girl as the CG, just repainted and given a new pose.
"""

M_OBJ = """
COMPOSITION (MANDATORY): keep the entire subject fully inside the frame, centred, with generous safe margins, do NOT crop any part of it, do NOT fill the frame edge-to-edge, pull the camera back. The MOST IMPORTANT part of the subject (the split husk and the shoots) must sit in the CENTRE BAND of the image, vertically around the middle third — never touching the top or the bottom edge. Everything must read clearly when shrunk to a small 448x404 trading-card window.
"""

M_FULL = """
COMPOSITION (MANDATORY): scale the whole figure to about 76% of the frame height, centre it, leave at least 8% empty background at the TOP and at the BOTTOM edge; the top of the head and BOTH feet must be FULLY visible and NOT cropped; every extra part or companion must also stay completely inside the frame. Do NOT fill the frame edge-to-edge like the reference image, pull the camera back. The whole subject must sit in the CENTRE BAND of the image, vertically around the middle third.
"""

M_HALF = """
COMPOSITION (MANDATORY): half-body framing, the TOP OF HER HEAD, BOTH BLACK EARS and BOTH CUPPED HANDS fully inside the frame, at least 8% empty background above the hair and on both sides, do NOT crop the ears or the hands, do NOT fill the frame edge-to-edge, pull the camera back. Her face and her cupped hands must both sit in the CENTRE BAND of the image, vertically around the middle third. Everything must read clearly when shrunk to a small 448x404 trading-card window.
"""

TAIL = """
AVOID ALWAYS: NO photorealistic rendering, NO photographic texture, NO 3D render, NO painterly airbrush, NO soft gradients, NO depth-of-field bokeh, NO chibi, NO cute mascot, NO invented humanoid, NO hooded figure, NO running silhouette, NO extra creature, NO text, NO letters, NO numbers, NO watermark, NO logo, NO readable symbols, NO runes, NO arrows, NO arrow symbols, NO motion-trail lines, NO speed lines, NO graphic marks of any kind, NO playing cards, NO card frames, NO card backs, NO light cones, NO beams of light, NO energy streams, NO glowing fog, NO particle explosion. It must stay crisp and legible when shrunk to a small 448x404 trading-card window.
"""

# (id, 卡名, 参考桶, 模板, 正文)
CARDS = [
(9248, "种子", "treant", "obj", """
SUBJECT — "SEED" (森林精魄 effect card, 0 cost): at the start of every turn it DESTROYS ITSELF and gives either 1 mana or one random card, settling once per copy sitting in the effect zone. It is a bursting, self-opening seed — NOT a plant, NOT a tree, NOT a creature.
NO human, NO creature, NO hands, NO face, NO monster inside, NO card shapes.
A single LARGE SEED the size of a fist, standing upright on dark forest moss: a thick woody husk in warm CHESTNUT-BROWN and pale TAN, drawn with crisp thin black outlines and hard flat cel-shaded facets, its surface scored with a few simple natural grooves (NO letters, NO runes). The husk has ALREADY SPLIT open along one clean vertical seam into TWO THICK HALVES leaning apart, and deep in the opening a bright WARM GOLD-GREEN KERNEL is visible — one flat solid shape with crisp hard edges, NOT a glow haze, NOT a beam.
From the seam TWO SMALL TENDER GREEN SHOOTS unfurl upward, tiny and crisp, still curled at the tips. FIVE or SIX small round GOLDEN SEEDS drift up out of the opening at slightly different heights, plain flat spheres with crisp outlines (a quiet "one per copy" motif). Two or three smaller identical UNSPLIT seeds lie half-buried in the moss around the base, clearly the same object at a smaller scale.
BACKGROUND: dark blurred forest floor, deep mossy green and teal, softly out of focus, a few out-of-focus fern silhouettes, empty — NO figures, NO card shapes.
LIGHTING: one warm key light from the upper left on the husk and the shoots, the rest falling into clean hard cel shadow. The seed must be the brightest, sharpest thing in the frame.
"""),

(9249, "被眷顾者", "char_forest", "half", """
SUBJECT — "THE FAVOURED ONE" (森林精魄 skill, 3 cost). A single character, the forest spirit girl, shown in a HALF-BODY portrait from the waist up, centred.
NEW POSE AND NEW ACTION — do NOT keep the reference image's standing pose, its open arms, or its bright sunlit daytime forest background.
Her head is tilted UP and slightly back, chin lifted, eyes WIDE OPEN looking up into the light, lips slightly parted in soft wonder, both black ears lifted and alert, the daisies and leaves still in her hair. BOTH ARMS are raised in front of her chest, elbows tucked in, her two small hands held side by side and CUPPED UPWARD as if catching something falling from above — palms up, fingers gently curled, clearly readable as an open receiving gesture (NOT pressed palm-to-palm, NOT a prayer, NOT hands clasped).
In her cupped palms rests a small flat WARM GOLD-GREEN LEAF-SHAPED GLOW — one crisp solid shape with hard edges and a thin black outline, NOT a soft glow haze, NOT a beam, NOT a light cone, NOT a floating orb.
Directly ABOVE her, THREE thin GOLDEN LEAF-RINGS descend in a loose vertical spiral toward her hands: three flat leaf-shaped rings with crisp outlines, evenly spaced, getting smaller as they come down. Beside each shoulder, TWO or THREE pale translucent LEAF-SHAPED AFTERIMAGES of the same leaf drift at slight offsets — flat pale-gold shapes with crisp edges, NOT smoke, NOT motion lines, NOT speed lines, NOT blur.
BACKGROUND: a DIM night forest, deep blue-green and muted, softly blurred tree trunks and fern silhouettes, NO bright daylight, NO sunbeams, NO white sky. A few faint pale-gold firefly dots far in the back.
LIGHTING: one soft cool key light from the upper left on her face and hair, plus a warm gold rim from the falling leaf-rings along her lifted chin and cupped hands; the rest falls into clean hard cel shadows.
"""),

# —— 以下两张是并行线 2026-11-14 上午新加进 cards.json 的森林精魄盟友，同样缺图，一并收口 ——
(9250, "鸭妈妈", "goose", "full", """
SUBJECT — "MOTHER DUCK" (森林精魄 ally, 4 cost, 3 power / 15 health): when she is played she summons ONE DUCKLING on each side of her. Show ONE mother duck plus EXACTLY TWO ducklings following her — NO other bird, NO other creature, NO human.
A large ROUND plump WHITE mother duck waddling forward in three-quarter view: soft rounded body and big breast, CREAM-WHITE feathers with hard flat cel-shaded shadow steps and crisp thin black outlines, a broad ORANGE bill, orange webbed feet mid-stride, a small calm proud eye, wings tucked against her sides, short tail flicked up. She reads as protective and heavy, NOT fierce.
Behind her, one step back on EACH side, TWO TINY PALE-YELLOW DUCKLINGS walk in her wake — clearly smaller, same simple rounded shapes, tiny orange bills and feet, plain dark round eyes. They must stay fully visible and must NOT be hidden behind her body.
BACKGROUND: softly blurred sunlit mossy forest path, warm mid-green and tea-brown, a few out-of-focus fern fronds and stones, empty — NO figures.
LIGHTING: warm key light from the upper left, her white feathers the brightest thing in the frame, clean hard cel shadows underneath.
"""),

(9251, "小鸭", "goose", "full", """
SUBJECT — "DUCKLING" (森林精魄 token ally, 0 cost, 1 power / 1 health, dimensional: it vanishes when it leaves play). ONE single tiny duckling alone — NO second bird, NO mother duck, NO nest of eggs, NO human, NO rubber-toy look.
A TINY fluffy PALE-YELLOW duckling standing alone, its head almost as large as its body, round plump body, a crisp fluffy silhouette with a few flat feather tufts at the chest and tail, a small clean ORANGE bill, small orange webbed feet planted slightly apart, one big plain DARK ROUND eye, the head tilted slightly to one side as if curious, one stubby wing lifted a little away from the body. It must read as a living little bird in the project's cel-shaded style, NOT a bath toy and NOT a mascot logo.
A SINGLE tiny pale-gold four-point sparkle hangs in the air just above its head (a quiet "one card gets cheaper" motif) — one flat crisp star shape only, NO other particles, NO glow haze.
BACKGROUND: softly blurred sunlit mossy forest floor, warm mid-green and tea-brown, a few out-of-focus fern fronds, empty — NO figures.
LIGHTING: warm key light from the upper left, the pale-yellow down the brightest thing in the frame, clean hard cel shadows underneath.
"""),
]

if __name__ == "__main__":
    for cid, name, _ref, tpl, body in CARDS:
        head = HEAD_CHAR if tpl == "half" else HEAD_STYLE
        tail = {"obj": M_OBJ, "full": M_FULL, "half": M_HALF}[tpl]
        txt = head + body + tail + TAIL
        path = os.path.join(D, "%d_%s.txt" % (cid, name))
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)
        print("wrote", os.path.basename(path), len(txt))
