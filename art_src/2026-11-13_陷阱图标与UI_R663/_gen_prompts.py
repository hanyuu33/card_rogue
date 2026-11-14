# -*- coding: utf-8 -*-
"""R663 陷阱素材：生成 8 份 codex 纯文生图 prompt（图标 4 + UI 4）。

口径（店长 2026-11-13）：委托 codex 纯文生图，不冒充 Seedream v5。
图标沿用 R577b 道具图标画风（粗黑描边 / 平涂两级 / 低饱和 / 纯白底）。
UI 素材一律「深色元件 + 纯白底 + 中心纯白留空」，后期走全局去白 → 透明。
"""
from pathlib import Path

D = Path(__file__).resolve().parent
P = D / "prompts"
P.mkdir(parents=True, exist_ok=True)

OPENER = """Call the built-in image_gen tool RIGHT NOW and generate exactly ONE SQUARE image, 1024x1024 if supported (otherwise the most square size available; do NOT generate a wide landscape image). Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. Generate the image FIRST, then reply with a one-line confirmation.

"""

ICON_HEAD = """Generate ONE game TRAP item ICON, isolated on a PURE WHITE (#FFFFFF) FLAT background. This will be cut out into a transparent PNG icon, so a clean uniform white background is CRITICAL.

STYLE: 2D hand-drawn anime game icon, THICK CLEAN BLACK OUTLINE around every shape, flat cel-shaded colour blocks with exactly TWO shading steps per object, hard-edged shadow shapes, low-saturation palette (cool charcoal blue-grey, muted purple, one warm amber accent). Cozy light-fantasy storybook look, simple readable silhouette, drawn detail only where the eye lands.

SUBJECT: %s

COMPOSITION: ONE single object only, LARGE and CENTERED, filling about 76%% of the frame, fully inside the frame with nothing cut off. SQUARE framing, straight-on view, no perspective tilt. The object must be COMPLETELY SEPARATED from the frame edges by white space. NO ground, NO pedestal, NO cast shadow, NO scenery, NO background objects, NO decorative border, NO frame, NO card, NO panel, NO bubble, NO sparkles outside the object. The ENTIRE background MUST be uniform pure white: NO gradient, NO texture, NO pattern, NO vignette, NO coloured backdrop.

STRICTLY FORBIDDEN: any text, letters, words, numbers, digits, labels, watermark, logo or signature anywhere in the image; any human figure, human face, human hands or full character body (animal parts and small creatures are fine); any photorealistic texture, 3D render, PBR material, photo grain, noise, film grain, airbrush, soft glow bloom, volumetric fog, god rays; any second object; any other-game card frame or UI element.

NO readable text. NO numbers. NO watermark. Pure white background only.
"""

UI_HEAD = """Generate ONE game UI FRAME / PLATE element, isolated on a PURE WHITE (#FFFFFF) FLAT background. This will be cut out into a transparent PNG overlay, so a clean uniform white background is CRITICAL.

STYLE: 2D hand-drawn anime fantasy game UI, deep ink-blue leather (#22304A), warm brass hairline trim (#A58C58), parchment-cream accents (#E9E7E2), flat cel-shaded colour blocks with exactly TWO shading steps, crisp clean outlines, subtle parchment grain only inside the plate, NO 3D render, NO soft glow, NO gradient outside the object.

SUBJECT: %s

COMPOSITION: exactly ONE element, centered, straight-on, no perspective tilt. The element's INTERIOR must be EMPTY PURE WHITE (it becomes transparent; the icon and text are drawn by code later). NO text, NO numbers, NO symbols, NO icon inside. The WHITE background and the WHITE interior must be the SAME pure white. NO cast shadow, NO scenery, NO second object, NO card, NO character.

STRICTLY FORBIDDEN: any text, letters, words, numbers, digits, labels, watermark, logo, signature; any human figure or character; any photorealistic texture, PBR material, photo grain, film grain, airbrush, soft bloom, volumetric fog, god rays; any sparkles or glow outside the element; any other-game UI.

NO readable text. NO numbers. NO watermark. Pure white background only.
"""

ICON_SUBJECTS = {
    "7001": "a round alchemical bomb with a dark charcoal iron shell, two narrow brass bands around the shell, a short curved fuse on top and one small amber flame at the fuse tip",
    "7002": "a frost snare: a six-pointed pale ice-blue crystal cluster with sharp spikes pointing outward, mounted on a small dark metal trigger ring, a few tiny frost chips on the crystal edges",
    "7003": "a small round glass poison vial with muted green liquid, a cork stopper, one completely blank paper label, and two tiny bubbles inside the glass",
    "7004": "a spike trap: three sharp steel spikes pointing upward, fixed on a short dark wooden base plate with two brass rivets",
}

UI_SUBJECTS = {
    "trap_slot": "a single SQUARE empty item-slot frame: deep ink-blue leather border, a thin brass inner hairline, four small brass corner rivets. The square centre must be COMPLETELY EMPTY pure white. Aspect ratio 1:1.",
    "trap_bar_battle": "a single NARROW VERTICAL rack backplate: a tall rounded rectangle about 1:3 (much taller than wide), deep ink-blue leather with brass trim along both long edges, three evenly spaced shallow square indentations that are EMPTY PURE WHITE, stacked vertically, plus small brass rivets at the top and bottom. Only ONE rack, centered.",
    "trap_bar_map": "a single NARROW VERTICAL rack backplate: a tall rounded rectangle about 1:3, warm parchment-cream paper with a soft grey-brown edge line and small brass corner tabs, three evenly spaced EMPTY PURE WHITE square indentations stacked vertically. Only ONE rack, centered.",
    "trap_group_tag": "a single SHORT HORIZONTAL name-plate ribbon about 4:1 (wide and short), deep ink-blue with pointed swallowtail ends, a thin brass hairline along the top and bottom edges, four tiny brass four-point stars near both ends. The centre must be COMPLETELY EMPTY pure white for code-drawn text.",
}

n = 0
for key, subj in ICON_SUBJECTS.items():
    (P / ("%s.txt" % key)).write_text(OPENER + (ICON_HEAD % subj), encoding="utf-8", newline="\n")
    n += 1
for key, subj in UI_SUBJECTS.items():
    (P / ("%s.txt" % key)).write_text(OPENER + (UI_HEAD % subj), encoding="utf-8", newline="\n")
    n += 1
print("prompts written:", n, "->", P)
