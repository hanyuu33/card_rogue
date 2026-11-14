# -*- coding: utf-8 -*-
"""R669 陷阱触发特效：生成 4 份 codex 纯文生图 prompt（黑底发光图）。

口径（店长 2026-11-13）：「帮我补，用codex生成素材」——沿用 R628 / R645 的
「不要文字特效，用素材图做特效」路子，出图走 codex 纯文生图，不冒充 Seedream v5。
四张各对应一个陷阱，落盘后由 _finish_fx.py 做「亮度 → alpha」转透明贴图。
"""
from pathlib import Path

D = Path(__file__).resolve().parent
P = D / "prompts"
P.mkdir(parents=True, exist_ok=True)

OPENER = """Call the built-in image_gen tool RIGHT NOW and generate exactly ONE SQUARE image, 1024x1024 if supported (otherwise the most square size available; do NOT generate a wide landscape image). Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. Generate the image FIRST, then reply with a one-line confirmation.

"""

HEAD = """A single isolated 2D game TRAP TRIGGER EFFECT sprite: %s, seen straight on, floating on a PURE BLACK (#000000) FLAT background. This will be converted into a transparent additive-blend sprite, so a clean uniform pure black background is CRITICAL and the effect must GLOW brightly against it.

STYLE: 2D hand-painted anime-fantasy game visual effect, the kind of impact overlay used in a cozy storybook card game. Clean cel-shaded shapes with two or three values only, hard-edged silhouettes, plus fine particle sparks. Vivid glow, strong contrast. Absolutely NO 3D render, NO photorealism, NO photo texture, NO noise grain, NO volumetric fog, NO lens flare, NO soft airbrush blur.

SHAPE: %s

COMPOSITION: ONE compact, roughly CIRCULAR burst only, dead center, perfectly round overall silhouette, straight-on view, no perspective tilt, no ellipse, no rotation, no directional lean. The whole burst fills about 72%% of the frame and is fully inside it, nothing cut off. The energy fades into pure black at the outer edges so the sprite blends seamlessly. NO ground, NO floor, NO scenery, NO background objects, NO cast shadow, NO frame, NO border, NO panel, NO card shape, NO second burst. The ENTIRE background MUST be uniform pure black #000000: NO gradient, NO texture, NO pattern, NO coloured backdrop.

STRICTLY FORBIDDEN: any text, letters, words, runes, numbers, digits, labels, watermark, logo or signature anywhere; any human figure, face, hands, creature, animal, dragon, skull, ghost body; any recognizable item silhouette (NO bomb object, NO bottle, NO vial, NO trap device, NO mechanism, NO weapon); any UI element, button, icon or card frame.

NO readable text. NO numbers. NO watermark. Pure black background only.
"""

JOBS = {
    "7001": (
        "a compact CIRCULAR ALCHEMICAL EXPLOSION when a hidden bomb trap detonates",
        "a white-hot #FFF3CE core blob at the dead center (about 20 percent of the frame width), wrapped in 10 to 14 jagged flame tongues of vivid #FF8A2B and #FFD36B shooting outward in every direction, with deep #7A2A12 shading between them, one thin circular amber shock ring near the outer third, plus 20 to 30 small bright ember sparks scattered in the outer half",
    ),
    "7002": (
        "a compact CIRCULAR FROST ERUPTION when an ice snare trap goes off",
        "an icy white #EAFBFF core star at the dead center, six sharp pale #8ED8F8 icicle shards radiating outward like a snowflake, dozens of small hard-edged crystalline splinters between them, deep #2C6C9E shading, a thin circular #BEEBFF frost shock ring, and a few faint cyan mist wisps that fade into black",
    ),
    "7003": (
        "a compact CIRCULAR POISON SPLASH when a venom vial trap breaks",
        "a sickly bright #DFFF8A core blob at the dead center, 8 to 12 rounded #6FCB45 liquid droplets with hard cel-shaded highlights flying outward, deep #2C5A22 shading, 10 to 18 tiny bubbles and speckles, two or three thin pale-green vapour curls, and one thin circular acid-green shock ring",
    ),
    "7004": (
        "a compact CIRCULAR SPIKE ERUPTION when a steel spike trap springs",
        "a cold white #F0E6FF core at the dead center, five sharp steel #B9A7D8 spear tips shooting radially outward with hard black outlines and #6B4C9C shading, a dozen small metallic shards between them, a few thin violet energy arcs, and one thin circular #A98BE8 shock ring",
    ),
}

n = 0
for key, (subject, shape) in JOBS.items():
    (P / ("%s.txt" % key)).write_text(OPENER + (HEAD % (subject, shape)),
                                      encoding="utf-8", newline="\n")
    n += 1
print("prompts written:", n, "->", P)
