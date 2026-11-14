# -*- coding: utf-8 -*-
"""R734 场地边框特效：生成委托 codex 的 7 份 prompt。

形态定稿（店长 2026-11-15 口径）：
  * 6 张 kind=="场地" 的卡各一套「格子边框环」；火墙术 9084 一套「整行火焰带」。
  * 环**整格铺满 + 可外溢**，因为绘制层级压在单位卡之下（店长：不必怕大小）。
    于是环带能做厚到 12%~15%，不再被「竖置卡上下只剩 8.8px」卡住。
  * 统一纯黑底 —— 后续 _finish_fx.py 按亮度转 alpha、走加色混合。

环与横条两套几何措辞（GEOMETRY / COMPOSITION）分开写：横条不能有矩形轮廓。
用法：python _gen_prompts.py
"""
import os

D = os.path.join(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(D, "prompts")

HEAD = (
    "Call the built-in image_gen tool RIGHT NOW and generate exactly ONE image. "
    "Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. "
    "Generate the image FIRST, then reply with a one-line confirmation.\n\n"
)

STYLE = (
    "STYLE: 2D hand-painted anime-fantasy game effect art, the kind of spell overlay "
    "used in a cozy illustrated card game. Clean cel-shaded shapes with two or three "
    "values, crisp silhouettes, fine particle details. Vivid glow, strong contrast. "
    "Absolutely NO 3D render, NO photorealism, NO photoreal texture, NO noise grain, "
    "NO volumetric fog, NO lens flare, NO depth of field.\n"
)

FORBID = (
    "STRICTLY FORBIDDEN: any text, letters, words, runes, numbers, digits, labels, "
    "watermark, logo or signature anywhere; any human figure, face, hands, creature, "
    "animal, bird, dragon, skull, ghost body; any weapon, tool, bottle, flask, bomb, "
    "spike, prop; any UI element, button, icon; any picture-frame moulding or card shape.\n\n"
    "NO readable text. NO numbers. NO watermark. Pure black background only.\n"
)

RING_GEOM = (
    "GEOMETRY (most important): a CLOSED LOOP BAND hugging all four edges of a wide "
    "landscape rectangle. The band is EVENLY thick, about 12 to 15 percent of the canvas "
    "height, and runs CONTINUOUSLY around the whole perimeter with no gap and no break at "
    "the corners. The four corners carry slightly larger ornament clusters that stay "
    "within the band's thickness. The ENTIRE interior of the ring — the middle 70 percent "
    "of the canvas, both horizontally and vertically — is untouched pure black, with only "
    "a faint inner glow bleeding a few pixels inward. Nothing stands inside the middle.\n"
)

RING_COMP = (
    "COMPOSITION: one single ring only, centered, symmetric, straight-on view, no "
    "perspective tilt, no 3D bevel, no rotation, no directional lean. Both the outer rim "
    "and the inner rim of the band fade smoothly into pure black. NO ground, NO floor, NO "
    "scenery, NO background objects, NO cast shadow, NO panel, NO photo frame, NO picture "
    "inside the ring, NO second object. The ENTIRE background MUST be uniform pure black "
    "#000000: NO gradient, NO texture, NO pattern, NO coloured backdrop.\n"
)

BANNER_GEOM = (
    "GEOMETRY (most important): a WIDE HORIZONTAL BANNER, approximately 3.4 to 1. This is "
    "NOT a ring and NOT a rectangle outline: a continuous burning band of flame that runs "
    "from the left edge of the frame to the right edge, open at both ends, with no end "
    "caps, no border, no frame line. The flames occupy the lower 60 percent of the banner "
    "and lick upward; the top 35 percent fades into pure black. The fire is densest along "
    "the bottom baseline and thins out into separate tongues as it rises.\n"
)

BANNER_COMP = (
    "COMPOSITION: one continuous wall of fire spanning the full width, straight-on view, "
    "no perspective, no ground plane, no scenery, no objects behind it, no cast shadow, no "
    "second effect. The bottom edge and both side ends fade into pure black so the strip "
    "tiles and blends seamlessly. The ENTIRE background MUST be uniform pure black "
    "#000000: NO gradient, NO texture, NO pattern, NO coloured backdrop.\n"
)

# key: (形态, 元素段, 中文名)
JOBS = [
    ("field_8028", "ring",
     "ELEMENT: fresh spring WATER. The band is a flowing ribbon of clear water in pale aqua "
     "#6FD8E8 and #BFEFFF, with a bright white crest highlight skimming along its length, "
     "small droplets and round bubbles rising inside the band, and thin rivulets curling at "
     "the four corners. Mood: calm, clean, gently magical — a healing spring, NOT dangerous. "
     "Softest and lowest-contrast ring of the set, no fire, no orange.\n",
     "清泉 8028 · 水（持续场地，温柔不刺眼）"),

    ("field_8036", "ring",
     "ELEMENT: a mechanical REPAIR BAY. The band is assembled from interlocking brass and "
     "steel-grey machine segments: riveted plates, toothed gear arcs biting into each other "
     "at the four corners, and a soft mint-green #6FE0A0 inspection light running along a "
     "recessed groove inside the band. Fine steel-blue #9EC4E8 highlights pick out the metal "
     "edges. Mood: tidy, engineered, quietly humming. No rust, no grime, no loose tools.\n",
     "维修间 8036 · 机械检修（友方，绿色检修光）"),

    ("field_8037", "ring",
     "ELEMENT: a REFIT FACTORY. The band is a channel of hot molten metal: an amber #FFB03A "
     "and orange #FF7A2A glowing stream with a rhythmic toothed conveyor pattern inside it, "
     "sparks and embers spitting outward from the band, and furnace-mouth notches of bright "
     "light at the four corners. Steel-grey #6A7480 structural plates clamp the glowing "
     "channel. Mood: industrial, hot, productive — bright but controlled. No smoke clouds.\n",
     "改造工厂 8037 · 熔金齿轮（持续改造）"),

    ("field_9186", "ring",
     "ELEMENT: a VORTEX. The band is a churning whirlpool of deep violet #7A5CFF, #B98CFF "
     "and dark navy, with spiral streak lines drawn along the inside of the band so it reads "
     "as rotating, small curve-hooks of brighter violet at the four corners like the eye of a "
     "small whirl, and scattered violet sparks thrown outward. Mood: cold, pulling, "
     "unsettling. No water splash, no bright blue, no fire.\n",
     "漩涡 9186 · 暗紫涡流（回合末伤害）"),

    ("field_8082", "ring",
     "ELEMENT: a POISON SWAMP. The band is thick bubbling mire: sickly green #9FD85C and "
     "murky olive mixed with violet #B98CFF vapour, with fat blisters and popped bubbles of "
     "varied size, a few viscous drips hanging from the inner rim, and puffy spore sacs "
     "swelling at the four corners. Mood: damp, sticky, toxic. No solid ground, no plants, "
     "no bones, no skulls.\n",
     "毒沼 8082 · 毒绿瘴气（中毒 2 回合）"),

    ("field_9224", "ring",
     "ELEMENT: a cold ARCANE MARK. The band is a thin precise rune-band: pale ice-blue "
     "#6EC6FF and white geometric notches, bracket shapes and measurement ticks marching "
     "along the four edges, sharp angular corner brackets, and a faint cyan inner hairline. "
     "Deliberately minimal and sharp — the thinnest, most restrained ring of the set, mostly "
     "black with only the ticks glowing. Mood: analytic, calm, targeting. The notches must "
     "stay ABSTRACT geometry and must NOT form readable letters, numbers or glyph text.\n",
     "标记 9224 · 冷蓝准星（敌人受伤 +1）"),

    ("firewall_9084", "banner",
     "ELEMENT: a WALL OF FIRE. A roaring continuous sheet of flame: an intense white-hot "
     "baseline, a bright orange #FF7A2A and amber #FFB03A body, deep crimson #C42B0E at the "
     "outer licks, tall flame tongues curling left and right, and small embers drifting up "
     "into the black above. Irregular, organic, hand-painted flame shapes — never a straight "
     "band of colour, never a gradient rectangle. Mood: roaring, dangerous, hot.\n",
     "火墙术 9084 · 整行火焰（3 格宽横带）"),
]


def build(kind, element):
    geom, comp = (RING_GEOM, RING_COMP) if kind == "ring" else (BANNER_GEOM, BANNER_COMP)
    intro = (
        "A single isolated 2D game UI effect sprite: "
        + ("a HOLLOW RECTANGULAR BORDER RING — an elemental energy band that runs along the "
           "four edges of the canvas and is completely EMPTY in the middle. It will be laid "
           "over ONE cell of a tactical card-game board, UNDERNEATH the unit card standing "
           "there, so the ring hugs the outer edge of the cell and the middle stays black. "
           if kind == "ring" else
           "a WALL-OF-FIRE BANNER — a burning strip that covers one whole row of three "
           "battle-grid cells. It will be laid over that row, UNDERNEATH the unit cards "
           "standing there. ")
        + "Seen perfectly straight on, floating on a PURE BLACK (#000000) FLAT background. "
        "This will be converted into a transparent additive-blend overlay, so a clean "
        "uniform pure black background is CRITICAL and the effect must GLOW brightly "
        "against it.\n\n"
    )
    return HEAD + intro + STYLE + "\n" + geom + "\n" + element + "\n" + comp + "\n" + FORBID


def main():
    os.makedirs(P, exist_ok=True)
    names = []
    for key, kind, element, cn in JOBS:
        p = os.path.join(P, "%s.txt" % key)
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(build(kind, element))
        names.append("%s\t%s" % (key, cn))
        print("WROTE %-16s %5d chars  %s" % (key, len(build(kind, element)), cn))
    with open(os.path.join(D, "names.tsv"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(names) + "\n")
    print("total", len(JOBS))


if __name__ == "__main__":
    main()
