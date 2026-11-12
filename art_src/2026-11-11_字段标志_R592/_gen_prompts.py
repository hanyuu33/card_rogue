# -*- coding: utf-8 -*-
"""R592 字段标志：生成 codex 的纯文生图 prompt（10 个字段各一张）。

设计口径（店长 R592）：
  · 卡面上的字段不再用纯文字，改成**标志**；
  · 标志统一待在卡面右上角的一个**圆形槽位**里，多字段轮流显示；
  · 尺寸会缩到 20~40px 显示 → 必须剪影清晰、不靠细节，靠**形状 + 语义色**辨认。

所以每个标志都是「**深色圆底 + 亮色符号 + 粗黑描边**」的成套徽章：
圆底颜色取 `AFFIX_DEFS` 里该字段的 `bg`/`fg`，10 张彼此同构，一眼能看出是一套。
"""
import io
import json
import os

D = os.path.dirname(os.path.abspath(__file__))
PROMPTS = os.path.join(D, "prompts")

HEAD = (
    "Call the built-in image_gen tool RIGHT NOW and generate exactly ONE SQUARE image, "
    "1024x1024 if supported (otherwise the most square size available; do NOT generate a wide "
    "landscape image). Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. "
    "Generate the image FIRST, then reply with a one-line confirmation.\n\n"
)

BODY = """Generate ONE game STATUS BADGE icon, isolated on a PURE WHITE (#FFFFFF) FLAT background. This will be cut out into a transparent PNG badge, so a clean uniform white background is CRITICAL.

STYLE: 2D hand-drawn anime-fantasy game UI badge. ONE circular medallion: a DEEP {bg} filled disc with a THIN metallic {fg} rim ring, and on top of the disc ONE large glowing {fg} symbol with a THICK CLEAN BLACK OUTLINE. Flat cel-shaded, exactly TWO shading steps, hard-edged shadow shapes, no gradient on the fill. Cozy light-fantasy storybook look. Readable silhouette at tiny size: the symbol must be simple, bold and instantly recognisable when shrunk to 24 pixels.

SUBJECT: {subject}

COMPOSITION: ONE circular medallion only, LARGE and CENTERED, the disc filling about 74% of the frame, perfectly round, fully inside the frame with nothing cut off. SQUARE framing, straight-on view, no perspective tilt, the badge faces the viewer flat. The medallion must be COMPLETELY SEPARATED from the frame edges by white space. NO ribbon, NO banner, NO hanging chain, NO stand, NO pedestal, NO cast shadow, NO scenery, NO background objects, NO decorative outer frame, NO card, NO panel. The ENTIRE background MUST be uniform pure white: NO gradient, NO texture, NO pattern, NO vignette, NO coloured backdrop.

STRICTLY FORBIDDEN: any text, letters, words, numbers, digits, labels, watermark, logo or signature anywhere in the image; any human figure, human face, human hands or character body; any photorealistic texture, 3D render, PBR material, photo grain, noise, film grain, airbrush, soft glow bloom, volumetric fog, god rays; any second object; any other-game card frame or UI element.

NO readable text. NO numbers. NO watermark. Pure white background only.
"""

# glyph -> (bg hex, fg hex, 符号描述)
JOBS = {
    "run": ("0e2e1a", "3fbf6f",
            "TWO bold chevron arrows pointing RIGHT, stacked one behind the other with three short "
            "speed lines trailing to the left, reading as sheer forward speed. NOT a shoe, NOT a boot, "
            "NOT a wing, NOT a horse, NOT a full creature."),
    "taunt": ("331c05", "ffa41f",
              "a chunky BULLSEYE: two concentric rings with a solid dot in the middle, plus FOUR short "
              "spikes radiating outward at the diagonals, reading as 'everyone attack me'. NOT an eye, "
              "NOT a shield, NOT a target practice board with arrows."),
    "death": ("330f14", "ff7a7a",
              "a small STYLISED SKULL, front view, two big empty eye sockets and a simple jaw line, "
              "clean and cartoonish. NOT a whole skeleton, NOT a scythe, NOT a cross, NOT a tombstone, "
              "NOT a ghost."),
    "ghost": ("1f1a38", "b79cff",
              "TWO overlapping outline silhouettes of the same small humanoid figure, offset up and to "
              "the right, the back one faded and semi-transparent, reading as an afterimage / duplicate. "
              "NOT a bedsheet ghost, NOT a face, NOT a skull, NOT a mirror."),
    "shield": ("0f2a33", "6ec6ff",
               "a simple HERALDIC SHIELD, straight-on, flat top and a pointed bottom, one clean "
               "highlight bar on the left side. NOT a sword, NOT a cross, NOT a lock, NOT armour plating, "
               "NOT a turtle shell."),
    "portal": ("2a0d33", "e58cff",
               "TWO nested DIAMOND outlines, one inside the other, the inner diamond smaller and brighter, "
               "reading as a dimensional gate / rift. NOT a rhombus gem, NOT a spinning top, NOT an eye, "
               "NOT a door, NOT a pentagram."),
    "overload": ("33120a", "ff7a3c",
                 "a bold LIGHTNING BOLT running vertically through a thin broken CIRCLE, with two short "
                 "crack lines splitting off the ring, reading as overcharged and about to burst. NOT a "
                 "battery, NOT a plug, NOT a flame, NOT a gear."),
    "swap": ("0a2a2e", "5fe0d0",
             "TWO horizontal arrows, one pointing RIGHT above and one pointing LEFT below, offset "
             "vertically, reading as exchange / swap places. NOT a refresh arrow, NOT a circle of arrows, "
             "NOT a yin-yang, NOT scissors."),
    "save": ("1a2a0a", "b9e85a",
             "a single BOOKMARK ribbon with a notched V bottom, straight-on, plus a small stitch line "
             "near the top, reading as 'keep this card in hand'. NOT a book, NOT a scroll, NOT a folder, "
             "NOT a pen, NOT a heart."),
    "share": ("33161c", "ff8fa8",
              "a simple HERALDIC SHIELD with a bold PLUS / cross sign centred on it, reading as "
              "'damage is shared here'. NOT a first-aid kit, NOT a hospital sign, NOT a heart, "
              "NOT two hands, NOT a chain."),
}


def main():
    os.makedirs(PROMPTS, exist_ok=True)
    made = []
    for glyph, (bg, fg, subject) in JOBS.items():
        text = HEAD + BODY.format(bg="#%s" % bg.upper(), fg="#%s" % fg.upper(), subject=subject)
        with io.open(os.path.join(PROMPTS, "%s.txt" % glyph), "w",
                     encoding="utf-8", newline="\n") as f:
            f.write(text)
        made.append(glyph)
    # 索引
    idx = {"generated": made,
           "defs": {g: {"bg": v[0], "fg": v[1]} for g, v in JOBS.items()}}
    with io.open(os.path.join(D, "index.json"), "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(idx, ensure_ascii=False, indent=2))
    print("prompts 已生成：%d 张 -> %s" % (len(made), PROMPTS))
    for g in made:
        print("  ", g)


if __name__ == "__main__":
    main()
