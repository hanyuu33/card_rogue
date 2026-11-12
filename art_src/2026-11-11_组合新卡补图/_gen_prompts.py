# -*- coding: utf-8 -*-
"""2026-11-11 组合新卡补图：4 张 prompt 生成器。

来源：cards.json 里 4 张「有卡无图」
  9246 宝石兽（森林精魄·盟友，死亡时组合一张卡）
  9247 拼装工厂（机械之心·工事，回合开始时组合一张卡）
  9190 猫鼠游戏（暗影刺客·技能，丢弃所有手牌 / 下回合技能伤害加倍）
  9191 黑暗嵌合（暗影刺客·技能，组合一张卡 + 产物获「保存」+ 打全体）
9158 罐子(工事) 已弃用永久不出图；8002 攻击有森林/机械/暗影三版图。

沿用 R563 的 HEAD / M_FULL / M_OBJ / TAIL 模板与全部纪律：
  规范 A  非盟友/工事卡不得凭空捏造人形/生物 → 两张技能卡只画物件/特效
  规范 B  非卡牌相关效果不得出现卡牌 → 4 张全部不画卡牌（只有 9168 许愿破例）
  纪律 E  全身主体 76% 占幅 + 上下 8% 留白
  纪律 F  验收看裁好的 448x403
  纪律 G  留白不足用画布延展兜底
  纪律 H  先读 effect_text；机械件默认不自发光；「组合」画物理扣合，不画吸能
  纪律 N  已定稿指令先丢后台；拿到一张就裁切并发增量页，不等整批
"""
import os

D = os.path.dirname(os.path.abspath(__file__))

HEAD = """Call the built-in image_gen tool RIGHT NOW and generate exactly one 1024x1024 image. Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. Generate the image FIRST, then reply with a one-line confirmation.

The ATTACHED image is a STYLE REFERENCE ONLY: copy its drawing technique (Japanese anime cel shading, THIN clean black line art, hard-edged 2-3 step shadows, big flat colour blocks, dark muted softly-blurred background + bright clearly-lit subject). Do NOT copy its character, its pose, its stance, its props, its scene, its composition, its scale, or its colour placement. Paint a COMPLETELY DIFFERENT subject.
"""

M_FULL = """
COMPOSITION (MANDATORY): scale the whole figure to about 76% of the frame height, centre it, leave at least 8% empty background at the TOP and at the BOTTOM edge; the top of the head and ALL FOUR paws must be FULLY visible and NOT cropped; every extra part or floating chip must also stay completely inside the frame. Do NOT fill the frame edge-to-edge like the reference image, pull the camera back.
"""

M_OBJ = """
COMPOSITION (MANDATORY): keep the entire subject fully inside the frame with generous safe margins (at least 10% empty background on every side), do NOT crop any part of it, do NOT fill the frame edge-to-edge, pull the camera back. Everything must read clearly when shrunk to a small 448x403 trading-card window.
"""

TAIL = """
AVOID ALWAYS: NO photorealistic rendering, NO photographic texture, NO 3D render, NO painterly airbrush, NO soft gradients, NO depth-of-field bokeh, NO chibi, NO cute mascot, NO invented humanoid, NO hooded figure, NO running silhouette, NO extra creature, NO text, NO letters, NO numbers, NO watermark, NO logo, NO readable symbols, NO arrows, NO arrow symbols, NO motion-trail lines, NO speed lines, NO graphic marks of any kind, NO playing cards, NO card frames, NO light cones, NO beams of light, NO energy streams, NO glowing fog. It must stay crisp and legible when shrunk to a small 448x403 trading-card window.
"""

# (id, 卡名, 参考桶, 是否全身, 是否允许卡牌, 画面正文)
CARDS = [
(9246, "宝石兽", "treant", 1, 0, """
SUBJECT — "GEM BEAST" (森林精魄 rare ALLY unit, ONE small creature, FULL BODY, death triggers a card combination).
A compact four-legged BEAST built from faceted EMERALD-GREEN and pale JADE crystal plates: a low stocky body with clearly separated flat gem facets, four short sturdy legs with blunt clawed crystal feet, a wedge-shaped head with two short blunt horn-crystals and two small flat CYAN-GREEN lens eyes (NOT expressive cartoon eyes), a short faceted tail. Thin moss-green seams and small leaf-shaped plate edges sit between the facets; a few tiny detached crystal chips float near its back, quietly hinting that it can shatter and be combined again. Flat cel-shaded gem facets with crisp black outlines and hard 2-3 step highlights — flat colour blocks, NOT glass refraction, NOT photorealistic gemstone, NOT glowing crystal.
Calm planted stance, three-quarter view facing left, all four paws on the ground. NORMAL head-to-body proportion for a small beast, NOT chibi, NOT a cute mascot, NO second creature.
BACKGROUND: dark blurred forest interior, deep teal-green, empty, one warm key light from upper left.
"""),

(9247, "拼装工厂", "mech", 0, 0, """
SUBJECT — "ASSEMBLY FACTORY" (机械之心 rare FORTIFICATION, ONE stationary building-like machine; at every turn start it combines a card). NO human, NO creature, NO full robot, NO conveyor belt close-up, NO cannon, NO turret, NO radar dish.
A compact bolted STEEL FACTORY SHRINE planted on a steel deck: a wide armoured base, a squat square central housing with a heavy hinged front panel, TWO short side towers of riveted plating, and one low plain chimney stack with a blank cap (NO smoke, NO glow). Across the front are THREE open EMPTY MODULE SLOTS of different shapes, each holding one half-inserted plain grey machine block — a cube, a wedge and a short cylinder — physically SLOTTED TOGETHER like a three-part kit with visible tongue-and-groove joints; the parts are solid and touching, NOT floating, NOT emitting energy. Small flat AMBER status plates (colour only, they do NOT glow), thin cyan seam lines only along armour edges, visible bolts, broad flat cel-shaded panels with crisp black outlines. It reads as a FIXED defensive workshop that assembles parts, NOT a weapon.
BACKGROUND: dark blurred workshop / ship deck, deep blue-grey. Slightly low three-quarter view, clearly lit, generous safe margins.
"""),

(9190, "猫鼠游戏", "shadow_beast", 0, 0, """
SUBJECT — "CAT AND MOUSE" (暗影刺客 5-cost SKILL: discard the whole hand now, skill damage doubles on the NEXT turn). NO human, NO creature, NO animal, NO cat, NO mouse, NO face, NO hands, NO playing cards, NO card frames.
A still life of TWO abstract GAME PIECES facing each other on a dark chequered board: one tall DARK-VIOLET obsidian hexagonal token with two small pointed fin shapes on its top, one small PALE-BONE rounded token with two tiny round fins — pure geometric game tokens, they are NOT animals and have NO faces, NO eyes, NO letters. Between them stands a small tilted HOURGLASS with pale violet sand settled in the LOWER bulb (one turn later). Behind the taller token TWO overlapping flat CRESCENT BLADE SHADOWS stack at a slight offset, hard-edged and crisp, a quiet 'doubled strike' motif — flat shapes, NOT motion lines, NOT speed lines, NOT a glow. A few small pale blank chips lie scattered and dim beside the board, hinting at a discarded hand WITHOUT drawing any card.
BACKGROUND: dark blurred ruined stone chamber, deep indigo-violet, empty. Centred, still, quiet, one cold key light.
"""),

(9191, "黑暗嵌合", "shadow_beast", 0, 0, """
SUBJECT — "DARK FUSION" (暗影刺客 2-cost SKILL: physically combine parts into one card, then strike EVERY enemy). NO human, NO creature, NO full robot, NO face, NO hands, NO playing cards, NO card frames, NO beam, NO vortex.
THREE heavy BLACK-OBSIDIAN WEDGE BLOCKS with dark-violet metal rims slide together into ONE complete faceted diamond-shaped CORE: the seams visibly INTERLOCK with clean tongue-and-groove joints, like sentai mecha parts physically docking. The blocks are solid, hard-edged, crisp black outlined and flat cel-shaded, with small brass rivets and one thin violet seam at each joint. NO energy absorption, NO swirling vortex, NO suction lines, NO light cone, NO glowing fog. Around the finished core, SIX small identical flat VIOLET-BLACK diamond SHARDS sit at evenly spaced positions near the frame edges, each FACING outward in a different direction (a quiet 'all enemies' motif) — flat hard shapes, NOT a beam, NOT a shockwave ring, NOT smoke, NOT arrows.
BACKGROUND: dark blurred ritual chamber / ruined deck, deep indigo-violet, empty. Single centred subject, generous safe margins.
"""),
]

if __name__ == "__main__":
    for cid, name, _ref, full, card_ok, body in CARDS:
        txt = HEAD + body + (M_FULL if full else M_OBJ) + TAIL
        path = os.path.join(D, "%d_%s.txt" % (cid, name))
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)
    print("wrote %d prompts" % len(CARDS))
