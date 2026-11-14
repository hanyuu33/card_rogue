# -*- coding: utf-8 -*-
"""R690 工具图标：生成 2 份 codex 纯文生图 prompt（7005 小血瓶 / 7006 法力药剂）。

口径：R663 那四个陷阱图标是 codex 纯文生图出来的（粗黑描边 / 平涂两级 / 纯白底），
新加的两个「使用型工具」必须是**同一族**的药瓶 —— 只换液体颜色与中央标记，
让人一眼看出「这是同一套东西」（与 9154/9185 共用路牌外框同一条原则）。

直接复用 R663 的 ICON_HEAD / OPENER 模板，一个字都没改画风段。
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

# 瓶型与 7003 毒瓶**完全同款**：小圆玻璃瓶 + 软木塞 + 两颗小气泡，只换液体色与中央标记。
ICON_SUBJECTS = {
    "7005": ("a small round glass healing vial with warm CRIMSON-RED liquid, a cork stopper, "
             "and ONE bold simple RED CROSS symbol painted on the front of the glass, "
             "two tiny bubbles inside the glass"),
    "7006": ("a small round glass mana potion vial with clear SAPPHIRE-BLUE liquid, a cork stopper, "
             "and ONE bold simple BLUE DIAMOND symbol painted on the front of the glass, "
             "two tiny bubbles inside the glass"),
}

n = 0
for key, subj in ICON_SUBJECTS.items():
    (P / ("%s.txt" % key)).write_text(OPENER + (ICON_HEAD % subj), encoding="utf-8", newline="\n")
    n += 1
print("prompts written:", n, "->", P)
