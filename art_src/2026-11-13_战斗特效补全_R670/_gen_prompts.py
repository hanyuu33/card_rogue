# -*- coding: utf-8 -*-
"""R670 战斗特效补全：生成 codex 纯文生图 prompt（黑底发光，10 张）。

沿用 R628 / R645 / R669 的口径：黑底出图 → 亮度当 alpha 转透明。
店长口径「不要用文字特效，用素材图做特效」——这里只写画面，prompt 里
一律禁止文字 / 道具实物 / 角色。

用法：
    python _gen_prompts.py            # 重写全部 prompt
"""
import os

D = os.path.dirname(os.path.abspath(__file__))
PROMPTS = os.path.join(D, "prompts")

HEAD = """Call the built-in image_gen tool RIGHT NOW and generate exactly ONE image. Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. Generate the image FIRST, then reply with a one-line confirmation.

A single isolated 2D game SPELL EFFECT sprite: {what}. Seen straight on, floating on a PURE BLACK (#000000) FLAT background. This will be converted into a transparent additive-blend sprite, so a clean uniform pure black background is CRITICAL and the effect must GLOW brightly against it.

STYLE: 2D hand-painted anime-fantasy game visual effect, the kind of spell overlay used in a cozy storybook card game. Clean cel-shaded shapes with two or three values only, hard-edged energy shapes, plus fine particle sparks. Vivid glow, strong contrast. Absolutely NO 3D render, NO photorealism, NO photo texture, NO noise grain, NO volumetric fog, NO lens flare.

SHAPE: {shape}

COMPOSITION: one effect only, dead center, {silhouette}, straight-on view, no perspective tilt, no rotation, no directional lean. The energy fades into pure black at the outer edges so the sprite blends seamlessly. NO ground, NO floor, NO scenery, NO background objects, NO cast shadow, NO frame, NO border, NO panel, NO card shape, NO second object. The ENTIRE background MUST be uniform pure black #000000: NO gradient, NO texture, NO pattern, NO coloured backdrop.

STRICTLY FORBIDDEN: any text, letters, words, runes, numbers, digits, labels, watermark, logo or signature anywhere; any human figure, face, hands, creature, animal, bird, dragon, skull, ghost body; any weapon, tool, bottle, flask, bomb, spike, prop or object; any UI element, button, icon or card frame.

NO readable text. NO numbers. NO watermark. Pure black background only.
"""

# key -> (中文名, what, shape, silhouette)
SPECS = {
    "vortex": (
        "漩涡吸入",
        "a swirling INHALING WIND VORTEX that sucks everything toward its centre",
        "ONE compact spiral vortex, roughly circular, centered. A deep #06263E hollow core at the dead center (about 26% of the frame width) ringed by 3 concentric arcs of pale #7FD8FF and #BFF0FF air streaks spiralling clockwise inward, plus 20 to 30 small bright air flecks and shredded dust wisps pulled along the spiral arms. Cold cyan-teal palette with a faint #DFF7FF highlight where the streaks are fastest. The whole vortex fills about 74% of the frame and is fully inside it, nothing cut off.",
        "perfectly round spiral silhouette",
    ),
    "air_raid": (
        "空袭落弹",
        "an AIR-STRIKE BOMB IMPACT where a heavy shell slams down from above onto a target",
        "ONE compact downward impact burst, roughly circular, centered. A white-hot #FFF2CC core blob at the dead center (about 20% of the frame width), a short thick vertical column of #FFD166 light still descending from the top edge into the core, wrapped in 10 to 14 short flame tongues of vivid #FF8A3D and #FFB03A fanning outward, with deep #7A2A08 shading between them, plus 20 to 30 bright sparks and dust flecks in the outer half. The whole impact fills about 72% of the frame and is fully inside it, nothing cut off.",
        "round blast with a vertical descent streak",
    ),
    "skill_fire": (
        "技能·火焰（红橙卡通用）",
        "a generic FIRE DAMAGE SPELL IMPACT used for red and orange skill cards",
        "ONE compact fire burst, roughly circular, centered. A white-hot #FFF6E0 core blob at the dead center (about 22% of the frame width), wrapped in 9 to 13 short hard-edged flame tongues of vivid #FF7A2A and #FFC24A shooting outward in every direction, with deep #8C2E06 shading between them, plus 18 to 28 small bright embers and speckles scattered in the outer half. The whole burst fills about 72% of the frame and is fully inside it, nothing cut off.",
        "perfectly round burst silhouette",
    ),
    "skill_ice": (
        "技能·冰霜（蓝卡通用）",
        "a generic FROST DAMAGE SPELL IMPACT used for blue skill cards",
        "ONE compact frost burst, roughly circular, centered. A pale #EAFBFF core blob at the dead center (about 20% of the frame width), wrapped in 8 to 12 short angular ice shards of vivid #7FD3FF and #C6EEFF radiating outward like a snowflake star, with deep #1E5C8A shading between them, plus 18 to 28 tiny frost motes and icy speckles scattered in the outer half. The whole burst fills about 70% of the frame and is fully inside it, nothing cut off.",
        "round snowflake-star silhouette",
    ),
    "skill_shadow": (
        "技能·暗影（紫黑卡通用）",
        "a generic SHADOW DAMAGE SPELL IMPACT used for purple and black skill cards",
        "ONE compact shadow burst, roughly circular, centered. A small intense #F0E2FF core blob at the dead center (about 18% of the frame width), wrapped in 8 to 12 jagged shadow tendrils of vivid #8F5AD0 and #C9A6FF curling outward, with deep #2A0E4A shading between them, plus 18 to 28 tiny violet sparks scattered in the outer half. Slightly smokier and softer than a fire burst, but still crisp cel-shaded shapes on pure black. The whole burst fills about 72% of the frame and is fully inside it, nothing cut off.",
        "round tendrilled silhouette",
    ),
    "skill_holy": (
        "技能·圣光（金白卡通用）",
        "a generic HOLY LIGHT DAMAGE SPELL IMPACT used for gold and white skill cards",
        "ONE compact radiant burst, roughly circular, centered. A brilliant #FFFDF0 core blob at the dead center (about 24% of the frame width), wrapped in 10 to 14 straight rays of vivid #FFD54F and #FFE9A8 radiating outward in even spokes, with soft #A9761A shading between the rays, plus 18 to 28 small golden motes scattered in the outer half. Clean, warm, orderly — a holy flash rather than chaotic fire. The whole burst fills about 74% of the frame and is fully inside it, nothing cut off.",
        "perfectly round spoke-ray silhouette",
    ),
    "skill_nature": (
        "技能·自然/物理（绿棕灰黄卡通用）",
        "a generic EARTHEN AND NATURAL FORCE IMPACT used for green, brown, grey and yellow skill cards",
        "ONE compact natural-force burst, roughly circular, centered. A warm #F6F0D8 core blob at the dead center (about 20% of the frame width), wrapped in 8 to 12 chunky leaf-shaped and stone-fragment shapes of vivid #7CC24A and #C9A24A radiating outward, with deep #33501C shading between them, plus 18 to 28 small leaf flecks and grit particles scattered in the outer half. Earthy but still glowing. The whole burst fills about 72% of the frame and is fully inside it, nothing cut off.",
        "round lumpy burst silhouette",
    ),
    "blast": (
        "爆裂（四格爆炸 / 护甲爆发）",
        "a violent EXPLOSION BLAST that fills a small area",
        "ONE compact explosion, roughly circular, centered. A white-hot #FFF4D6 core blob at the dead center (about 24% of the frame width), wrapped in 12 to 16 thick hard-edged flame tongues of vivid #FF7A2A and #FFC24A blasting outward with visible gaps, with deep #6E2404 shading between them, plus 24 to 34 bright embers, soot flecks and shock specks scattered in the outer half. Bigger and more chaotic than a precise spell hit. The whole explosion fills about 78% of the frame and is fully inside it, nothing cut off.",
        "perfectly round chaotic blast silhouette",
    ),
    "gale": (
        "疾风 / 风刃（疾风、飓风咆哮、回旋斩）",
        "a CUTTING WIND SLASH, a crescent of compressed air sweeping through",
        "ONE crescent wind blade sweeping across the frame, centered. A bright #EAFBFF leading edge arc (about 72% of the frame width) with 5 to 7 thin trailing wind streaks of pale #9BDCFF and #D8F4FF behind it, plus 20 to 30 small air flecks and torn leaf motes kicked along the arc. Cool pale blue and white palette, crisp hard-edged streaks. Crescent is fully inside the frame, both tips visible, no cut-off.",
        "crescent arc silhouette",
    ),
    "stun": (
        "敲晕 / 眩晕",
        "a STUN IMPACT, dizzy stars bursting around a struck head with no head drawn",
        "ONE compact stun burst, roughly circular, centered. A soft #FFF6D0 glow blob at the dead center (about 16% of the frame width), ringed by 5 to 7 four-pointed yellow #FFD54F and #FFF0A8 stars of slightly different sizes arranged evenly on a circle at about 46% of the frame width, plus 18 to 28 tiny sparkle dots between them. Cheerful cartoon-pop palette, very clean shapes, generous empty black between the stars. The whole ring fills about 74% of the frame and is fully inside it, nothing cut off.",
        "round ring-of-stars silhouette",
    ),
}

TOTAL = len(SPECS)


def main() -> int:
    os.makedirs(PROMPTS, exist_ok=True)
    for key, (cn, what, shape, sil) in SPECS.items():
        text = HEAD.format(what=what, shape=shape, silhouette=sil)
        path = os.path.join(PROMPTS, "%s.txt" % key)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("%-13s %-22s %4d 字符" % (key, cn, len(text)))
    # 验收页要用到的中文名，一并落盘给 _finish_fx.py 读（避免两处各写一份）
    with open(os.path.join(D, "names.tsv"), "w", encoding="utf-8", newline="\n") as f:
        for key, (cn, _w, _s, _sil) in SPECS.items():
            f.write("%s\t%s\n" % (key, cn))
    print("共 %d 张 -> %s" % (TOTAL, PROMPTS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
