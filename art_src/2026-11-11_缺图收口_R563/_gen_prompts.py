# -*- coding: utf-8 -*-
"""R563 缺图收口：27 张 prompt 生成器。

口径（店长 2026-11-11）：真实缺图 12 张 + art_plan.json 里 15 张「暂不做」全部补上。
风格沿用 R552 的 14 桶参考图，只借画风不借内容；codex 图生图管线沿用 R562。

遵守的既有纪律：
  规范 A  非盟友/工事卡不得凭空捏造人形/生物 → 一律只画物件/特效
  规范 B  非卡牌相关效果不得出现卡牌 → 只有 9168 许愿允许
  纪律 E  全身主体写死 76% 占幅 + 上下 8% 留白
  纪律 F  验收必须看裁好的 448x403
  纪律 G  留白不足用画布延展兜底
  纪律 H  先读 effect_text；天线/碟/炮口等机械件默认不自发光
"""
import os

D = os.path.dirname(os.path.abspath(__file__))

HEAD = """Call the built-in image_gen tool RIGHT NOW and generate exactly one 1024x1024 image. Do NOT read skill files. Do NOT run shell commands. Do NOT ask questions. Generate the image FIRST, then reply with a one-line confirmation.

The ATTACHED image is a STYLE REFERENCE ONLY: copy its drawing technique (Japanese anime cel shading, THIN clean black line art, hard-edged 2-3 step shadows, big flat colour blocks, dark muted softly-blurred background + bright clearly-lit subject). Do NOT copy its character, its pose, its stance, its props, its scene, its composition, its scale, or its colour placement. Paint a COMPLETELY DIFFERENT subject.
"""

M_FULL = """
COMPOSITION (MANDATORY): scale the whole figure to about 76% of the frame height, centre it, leave at least 8% empty background at the TOP and at the BOTTOM edge; the top of the head and BOTH feet must be FULLY visible and NOT cropped; every extra part or afterimage must also stay completely inside the frame. Do NOT fill the frame edge-to-edge like the reference image, pull the camera back.
"""

M_OBJ = """
COMPOSITION (MANDATORY): keep the entire subject fully inside the frame with generous safe margins (at least 10% empty background on every side), do NOT crop any part of it, do NOT fill the frame edge-to-edge, pull the camera back. Everything must read clearly when shrunk to a small 448x403 trading-card window.
"""

TAIL = """
AVOID ALWAYS: NO photorealistic rendering, NO photographic texture, NO 3D render, NO painterly airbrush, NO soft gradients, NO depth-of-field bokeh, NO chibi, NO cute mascot, NO invented humanoid, NO hooded figure, NO running silhouette, NO extra creature, NO text, NO letters, NO numbers, NO watermark, NO logo, NO readable symbols, NO arrows, NO arrow symbols, NO motion-trail lines, NO speed lines, NO graphic marks of any kind, NO playing cards, NO card frames, NO light cones, NO beams of light, NO energy streams, NO glowing fog. It must stay crisp and legible when shrunk to a small 448x403 trading-card window.
"""

TAIL_CARD = """
CARD RULE: cards ARE allowed in this picture, but every card must be completely BLANK — NO text, NO letters, NO numbers, NO suits, NO readable symbols, NO ornate frames.
AVOID ALWAYS: NO photorealistic rendering, NO photographic texture, NO 3D render, NO painterly airbrush, NO soft gradients, NO depth-of-field bokeh, NO chibi, NO cute mascot, NO invented humanoid, NO hooded figure, NO hands, NO extra creature, NO text, NO letters, NO numbers, NO watermark, NO logo, NO arrows, NO arrow symbols, NO motion-trail lines, NO speed lines, NO graphic marks of any kind, NO light cones, NO glowing fog. It must stay crisp and legible when shrunk to a small 448x403 trading-card window.
"""

# (id, 卡名, 参考桶, 是否全身, 是否允许卡牌, 画面正文)
CARDS = [
(8084, "传授", "treant", 0, 0, """
SUBJECT — "PASSING DOWN" (森林精魄 skill; a three-part combination motif). NO human, NO creature, NO animal, NO full figure.
THREE floating LEAF-SHAPED STONE TABLETS arranged in a shallow arc, each carved with a DIFFERENT simple groove pattern (pure shapes, NO letters, NO numbers): the top one glows warm gold, the middle deep leaf-green, the bottom pale jade. Thin glowing amber vine tendrils link tablet to tablet, a few small golden pollen motes drift between them. Mossy stone with carved leaf veins, crisp hard edges, flat cel shading.
BACKGROUND: dark blurred forest interior, deep teal-green, softly out of focus, no figures. One warm key light from upper left.
"""),

(8085, "影缚", "shadow_beast", 0, 0, """
SUBJECT — "SHADOW BIND" (暗影刺客 skill; a three-part combination motif). NO human, NO creature, NO full figure.
THREE separate DARK-VIOLET SHADOW BANDS, flat ribbon-like strips of pure shadow, each curling around a small floating faceted obsidian shard. Flat hard-edged shapes with thin pale-violet rim light — NOT smoke, NOT haze. One band tight and knotted, one loosely coiled, one stretched taut: three distinct states like three selectable components. A few tiny violet spark fragments hang in the air. NO arrows, NO lines.
BACKGROUND: dark blurred ruined stone alley, deep indigo-violet, empty.
"""),

(9149, "疲惫", "prop", 0, 0, """
SUBJECT — "EXHAUSTION" (a curse: while in hand, all skill cards cost +1). NO human, NO creature, NO hands, NO face, NO expression.
A single HEAVY LEAD PLUMB WEIGHT hanging from a short slack chain, dull grey-violet metal with scratched cel-shaded facets, wrapped in a drooping strip of faded grey cloth. It sags low in the frame; a few small dust-grey crumbs fall from it, faint violet-grey cracks cross the metal. It reads as heaviness and drag, NOT as a weapon. A second smaller identical weight lies below in soft shadow to suggest accumulation.
BACKGROUND: dark blurred stone floor, deep blue-grey, empty.
"""),

(9154, "破绽", "skill_fx", 0, 0, """
SUBJECT — "OPENING / FLAW" (a curse with the dimensional trait: it vanishes when played). NO human, NO creature, NO armour, NO weapon.
A single vertical JAGGED CRACK splitting a large flat dark slate panel into two halves that peel apart; from inside the crack a thin cold VIOLET-WHITE VOID light shows. The crack's edges crumble into small hard angular fragments that drift away and fade to transparency. Flat cel-shaded shapes, crisp black outlines on the slate. NO glow haze, NO energy beam, NO smoke.
BACKGROUND: dark blurred stone void, deep blue-grey, empty. Diagonal composition, the crack running corner to corner.
"""),

(9157, "罐子", "prop", 0, 0, """
SUBJECT — "JAR (CURSE)" — a sealed earthenware jar that will vanish and summon an enemy. NO human, NO creature, NO visible monster.
A squat round CLAY JAR with a narrow neck, warm brown-grey cel-shaded ceramic with cracked pale glaze, tied at the neck with a torn BLANK paper talisman (NO letters, NO writing-like marks) and a frayed hemp cord. A long jagged crack runs down one side; a dim CRIMSON-VIOLET glow leaks from inside the crack and three thin curls of dark smoke drift upward. A few clay chips lie at its base. Single subject, centred, three-quarter view.
BACKGROUND: dark blurred battlefield ground at night, deep blue-grey.
"""),

# R563: 9158 罐子(工事) 已弃用（旧召唤物机制），不再出图。见 README。

(9168, "许愿", "prop", 0, 1, """
SUBJECT — "WISH" (0-cost skill: choose a card from the deck, add it to hand, then it vanishes). Card imagery is ALLOWED here.
A small fan of FIVE completely BLANK-BACKED CARDS lies on a dark surface; ONE card lifts out of the fan toward the upper right, caught in a thin clean CRESCENT of pale GOLD-WHITE light with three small four-point star sparkles. The lifted card's back is plain deep indigo with one simple circular gold emblem (NO letter). The other cards stay flat and dim. NO hands, NO human, NO creature.
BACKGROUND: dark blurred night sky / dim interior, deep blue-violet. Diagonal composition, the lifted card bright against the dark.
"""),

(9241, "激光巨炮", "mech", 0, 0, """
SUBJECT — "LASER CANNON" (enemy structure of the deep navy-blue-grey Revelator fleet). NO human, NO creature, NO robot with a face, NO beam.
A massive fixed NAVY-BLUE-GREY ARTILLERY EMPLACEMENT: a wide armoured base bolted to a steel deck, a long horizontal multi-barrel cannon with three stacked muzzle rings, a big round CYAN charging coil behind the breech, and a small VIOLET-WHITE glow deep inside the muzzle. Small CRIMSON warning triangles on the casing, thin cyan status strips along the base, two folded stabiliser legs planted. It reads DORMANT and charging — NO laser, NO beam, NO projectile, NO light cone. Broad flat cel-shaded armour, crisp outlines.
BACKGROUND: dark blurred storm clouds and ship-deck plating, deep blue-grey. Slightly low three-quarter view.
"""),

(9242, "普罗诺亚之影", "shadow_humanoid", 1, 0, """
SUBJECT — "SHADOW OF PRONOIA" (enemy Boss ally, ONE being, NO human face). A tall imposing figure of layered DARK NAVY-VIOLET armour plates over a hollow shadow core, with a smooth featureless oval helmet bearing ONE thin horizontal CYAN visor slit — NO eyes, NO mouth. Around it THREE semi-transparent GHOSTED SPLINTER FORMS peel off to the left, right and behind: simplified versions of the same body in three different stances (one heavy and braced, one wide and shield-like, one slim leaning forward), drawn as flat pale-violet translucent silhouettes with crisp edges — NOT smoke, NOT haze. Thin CYAN energy rings circle the chest and wrists, a few violet-white motes drift. Upright authoritative stance, arms slightly open.
NORMAL head-to-body proportion, NOT chibi.
BACKGROUND: dark blurred storm sky and ruined deck, deep blue-grey.
"""),

(9243, "炮击构状体", "mech", 1, 0, """
SUBJECT — "BOMBARDMENT CONFIGURATION" (enemy ally construct, ONE machine, NO pilot, NO human, NO second robot).
A HEAVY squat construct of deep NAVY-BLUE-GREY armour: broad layered shoulders, compact torso, a short triple-barrel cannon on the right shoulder angled slightly up, a low blocky head with ONE thin CYAN visor slit — NO face. From an open emitter on its left palm a small clean flat CYAN RING of light expands outward toward off-frame allies (a crisp ring, NOT a beam, NOT a cone). Small CRIMSON warning marks on the chest, thin cyan seams, two thick planted legs. Braced grounded stance.
NORMAL head-to-body proportion, NOT chibi.
BACKGROUND: dark blurred storm clouds / ship deck, deep blue-grey.
"""),

(9244, "护盾构状体", "mech", 1, 0, """
SUBJECT — "SHIELD CONFIGURATION" (enemy ally construct, ONE machine, NO pilot, NO human, NO second robot).
A WIDE defensive construct of deep NAVY-BLUE-GREY armour, both arms raised and spread, projecting a large clean HEXAGONAL ENERGY SHIELD PANEL in front of it — flat translucent pale-CYAN hexagon cells with crisp black outlines and hard edges, NO glow haze, NO bokeh. Low blocky head with ONE thin CYAN visor slit — NO face. Small CRIMSON warning marks on the shoulders, thin cyan seams, heavy planted feet. It reads as shielding units BEHIND it, not attacking.
NORMAL head-to-body proportion, NOT chibi.
BACKGROUND: dark blurred storm clouds / deck, deep blue-grey.
"""),

(9245, "迅捷构状体", "mech", 1, 0, """
SUBJECT — "SWIFT CONFIGURATION" (enemy ally construct, ONE machine, NO pilot, NO human, NO second robot).
A TALL SLENDER construct of deep NAVY-BLUE-GREY armour built for speed: long thin limbs, sharp fin-like shoulder blades, bright CYAN thruster nozzles on the calves and two smaller ones on the back, a narrow low head with ONE thin CYAN visor slit — NO face. Leaning forward in a running-ready stance, one foot forward one back. TWO flat pale-violet AFTERIMAGE SILHOUETTES trail behind at slight offsets (crisp flat shapes, NOT motion lines, NOT speed lines, NOT blur smear). Small CRIMSON warning marks on the thighs.
NORMAL head-to-body proportion, NOT chibi.
BACKGROUND: dark blurred storm clouds / deck, deep blue-grey.
"""),

(8020, "鲜血堡垒", "tower", 0, 0, """
SUBJECT — "BLOOD BASTION" (暗影刺客 structure). A tall, CLEARLY LIT, crisp stone fortress seen straight-on three-quarter — NOT a pyramid, NOT an isometric icon, NOT a tiny squat illustration, NOT a dark muddy scene.
Two thick DARK-GREY stone towers flank a heavy central gate, built from large clearly separated rectangular blocks with crisp black outlines and hard flat cel shading. Bright CRIMSON blood runs in carved channels down the walls and pools in a shallow basin at the base — vivid flat red, NOT glowing haze. Iron spikes top the towers, a blank shield-shaped iron plate on the gate (NO emblem), two plain dark-violet banners (NO symbols).
BACKGROUND: dark blurred rocky battlefield, deep indigo-grey. The fortress must be brightly lit and legible at thumbnail size. Slightly low camera.
"""),

(9185, "麻痹", "prop", 0, 0, """
SUBJECT — "PARALYSIS" (a curse that cannot be played and vanishes at turn end). NO human, NO face, NO expression, NO electric wires, NO cables, NO lightning, NO duck, NO bird.
A single floating PURPLE-GREY SEAL DISC: a plain faceted octagon with a simple concentric groove (NO letters, NO numbers, NO readable symbols), held perfectly STILL in mid-air. Its outer rim is already breaking into a handful of hard angular pale-grey fragments that drift upward and fade to transparency — the disc is quietly coming apart. A thin ring of frozen dust hangs motionless around it. Flat cel-shaded shapes, crisp outlines, NO glow haze, NO energy streams.
BACKGROUND: dark blurred stone void, deep blue-grey, empty. Centred, still, quiet.
"""),

(9015, "鸭子号角", "duck", 0, 0, """
SUBJECT — "DUCK HORN" (enemy effect: summons a duck knight every 3 turns). NO human, NO creature, NO duck character, NO full figure.
A single WAR HORN of brushed brass, its wide bell shaped subtly like a flattened DUCK BILL (two rounded lobes, NO eyes, NO face), a dark leather grip wrapped around the middle, three small brass studs along the tube, a plain crimson cord tied near the mouthpiece. THREE small round brass BEADS sit in a shallow row beside it (a quiet 'three turns' motif), each a plain sphere. Crisp cel-shaded metal with hard flat highlights. NO sound waves, NO musical notes, NO motion lines.
BACKGROUND: dark blurred battlefield camp, deep blue-grey.
"""),

(9028, "龙裔", "dragon", 1, 0, """
SUBJECT — "DRAGONKIN" (enemy ally, ONE small dragon-humanoid hatchling, NO human, NO second character).
A compact young draconic humanoid: squat sturdy body, short thick tail, small curved horns, blunt wing-stubs on the back, a broad snout with two small nostrils (NO human face), flat ASH-GREY scales with ORANGE ember cracks glowing faintly along the shoulders and tail, a pale cream underbelly plate, short clawed hands and feet. Slightly crouched ready stance, head lowered, wings half-spread.
NORMAL proportion for a small creature, NOT chibi, NOT a cute mascot.
BACKGROUND: dark blurred ashen battlefield, deep blue-grey.
"""),

(9029, "骷髅", "undead", 1, 0, """
SUBJECT — "SKELETON" (enemy ally, ONE undead warrior, NO living human, NO flesh, NO second character).
A full skeleton warrior of clean pale BONE plates with crisp black outlines: rounded skull with two hollow sockets holding small COLD GREEN ghost-flame dots (NOT red, NOT glowing haze), narrow jaw, rib cage with clearly separated ribs, simple pelvis, long limb bones with visible joints, holding a plain chipped short sword in one hand and a small round battered shield in the other. NO armour, NO clothing, NO cape. Standing slightly hunched, feet planted, sword lowered.
NORMAL head-to-body proportion, NOT chibi, NOT a cute mascot.
BACKGROUND: dark blurred graveyard, deep blue-grey.
"""),

(9048, "发条鸭", "duck", 1, 0, """
SUBJECT — "CLOCKWORK DUCK" (enemy ally, ONE mechanical duck, NO human, NO living animal, NO second character).
A small upright mechanical duck of riveted BRASS and dull COPPER plates: rounded head with a flat metal bill, two small blank CYAN lens dots (NOT living eyes), segmented neck, barrel-shaped body with an open circular gear window showing two interlocking brass gears, short metal wings, two flat webbed feet, and a big WIND-UP KEY on its back with a visible spring coil. Crisp cel-shaded metal with hard flat highlights, small amber rust marks at the joints. Standing square, slightly stiff.
NORMAL proportion, NOT chibi, NOT a cute mascot.
BACKGROUND: dark blurred workshop, deep blue-grey.
"""),

(9049, "齿轮升腾", "mech", 0, 0, """
SUBJECT — "GEAR ASCENSION" (enemy effect: all friendly units gain +2 power). NO human, NO creature, NO full robot.
A vertical stack of FIVE interlocking STEEL GEARS of increasing size, each rising one step higher than the last, drawn as clean flat cel-shaded discs with crisp black outlines and visible teeth. Thin CYAN energy rings circle the two upper gears, a couple of small cyan sparks sit in the gaps between teeth. Gears are plain machine parts, NOT glowing magical symbols. A dark steel shaft runs behind them.
BACKGROUND: dark blurred machine interior, deep blue-grey, empty. Diagonal rising composition.
"""),

(9115, "使魔之力", "duck", 0, 0, """
SUBJECT — "FAMILIAR POWER" (enemy effect: familiar ducks gain +1 power). NO human, NO creature, NO duck character, NO full figure.
A single large FEATHER-shaped brass emblem floating upright, plain and flat with crisp black outlines and a simple central quill groove (NO letters, NO runes), held inside a thin CYAN circular energy ring. THREE smaller identical feather emblems rise in a short diagonal behind it, each slightly dimmer. A few small cyan motes hang nearby. NO arrows, NO motion lines, NO light beams.
BACKGROUND: dark blurred ritual chamber, deep blue-grey, empty.
"""),

(9117, "恶魔使魔", "duck", 0, 0, """
SUBJECT — "DEMON FAMILIAR" (enemy effect: familiar ducks gain power and are summoned). NO human, NO creature, NO duck character, NO full figure.
A single dark CRIMSON-VIOLET SUMMONING SIGIL PLATE: a flat hexagonal iron plate with two small curved HORN-like prongs at its top edge and a simple hollow ring in the centre (NO letters, NO pentagram, NO readable symbols). Inside the hollow ring sits a small clean CYAN flame-shape, flat and crisp. Three short dark-violet ribbon shapes radiate outward from the plate and stop abruptly — NOT smoke, NOT haze. Iron rivets on the rim.
BACKGROUND: dark blurred ritual chamber, deep blue-grey, empty. Single centred object.
"""),

(9139, "充能巨炮", "mech", 0, 0, """
SUBJECT — "CHARGING CANNON" (enemy effect: destroys a random enemy unit each turn). NO human, NO creature, NO full robot, NO beam.
Close-up of a huge CANNON BREECH: a thick navy-grey steel barrel cropped by the frame, three concentric CYAN charging coils around the breech, a small round VIOLET-WHITE core visible deep inside the open muzzle (contained, NOT shooting), two heavy hydraulic pistons along the barrel, small crimson warning plates and rivets. Thin cyan seam lines, hard flat cel shading. The charge reads as STORED energy, not a shot. NO laser, NO projectile, NO light cone.
BACKGROUND: dark blurred ship-deck interior, deep blue-grey.
"""),

(9147, "流水线装配", "mech", 0, 0, """
SUBJECT — "ASSEMBLY LINE" (enemy effect: summons a mass-produced unit every 3 turns). NO human, NO creature, NO full robot.
A wide STEEL CONVEYOR BELT running diagonally across the frame carrying THREE identical half-finished grey machine chassis blocks (plain rectangular torso shells, NO heads, NO limbs), evenly spaced. Two overhead robotic ARM manipulators with visible pistons lower toward the middle chassis, their tips holding small CYAN weld points. THREE round AMBER status lamps hang in a row above the belt (a quiet 'three turns' motif). Cyan guide strips along the belt edge, riveted steel, oily dark floor.
BACKGROUND: dark blurred factory, deep blue-grey.
"""),

(9201, "舰炮", "ship", 0, 0, """
SUBJECT — "SHIP CANNON" (Revelator phase-1 passive: bombards one column each turn). NO human, NO creature, NO full robot, NO beam, NO projectile.
A row of THREE NAVY-BLUE-GREY naval turrets along a sloped armoured ship deck, each a low domed housing with a short thick barrel pointing out to the left, clean three-quarter perspective. Thin CYAN status strips run along the deck plating, one round CYAN charging lens on each turret, small crimson warning marks on the housings. The cannons are DORMANT — no muzzle flash, no laser, no beam. Broad flat cel-shaded armour panels, crisp outlines.
BACKGROUND: dark blurred storm clouds, deep blue-grey.
"""),

(9202, "电磁屏障", "skill_fx", 0, 0, """
SUBJECT — "ELECTROMAGNETIC BARRIER" (Revelator phase-2 passive: attackers take damage). NO human, NO creature, NO full robot.
A large clean HEXAGONAL BARRIER WALL seen slightly from the side, made of flat translucent pale-CYAN hexagon cells with crisp black outlines and hard edges, NO glow haze, NO bokeh. Along its rim run thin VIOLET-WHITE arc segments (short flat shapes, NOT lightning bolts, NOT zigzag electricity). Three small violet sparks sit where the arcs meet the frame. Only dark blurred shapes show behind it. NO arrows, NO shockwave rings.
BACKGROUND: dark blurred storm clouds / deck, deep blue-grey, empty.
"""),

(9203, "紧急呼叫", "mech", 0, 0, """
SUBJECT — "EMERGENCY CALL" (Revelator phase-3 passive: summons a powerful mass-produced enemy). NO human, NO creature, NO full robot, NO sound waves.
A single wall-mounted EMERGENCY BEACON: a squat navy-grey steel box with a large round CRIMSON lens at the centre (flat bright red, NOT glowing haze), a short folded antenna on top, two small cyan status dots below the lens, four corner bolts, a plain hinged lever on the side. From its base THREE short flat CYAN light bars point down to a small empty steel summoning pad on the floor (short clean bars, NOT a beam, NOT a cone, NO arrows).
BACKGROUND: dark blurred ship corridor, deep blue-grey.
"""),

(9209, "空袭", "skill_fx", 0, 0, """
SUBJECT — "AIR STRIKE" (enemy effect: marks 5 tiles, then damages units on them). NO human, NO creature, NO aircraft visible, NO explosion, NO falling bombs.
A slightly high-angle view of a dark battlefield grid: FIVE flat square TILES picked out by thin crisp CRIMSON outline frames, each with a small solid crimson DIAMOND at its centre (NO letters, NO numbers). Above them hover five small hard-edged dark-violet triangular SHADOWS at matching positions, like cast silhouettes of incoming strikes — flat shapes, NOT smoke, NOT blur. The surrounding ground stays dark and unmarked. Clean flat cel shading, crisp outlines. NO motion lines, NO speed lines, NO arrows.
BACKGROUND: dark blurred battlefield ground, deep blue-grey.
"""),
]

if __name__ == "__main__":
    for cid, name, _ref, full, card_ok, body in CARDS:
        txt = HEAD + body + (M_FULL if full else M_OBJ) + (TAIL_CARD if card_ok else TAIL)
        path = os.path.join(D, "%d_%s.txt" % (cid, name))
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)
    print("wrote %d prompts" % len(CARDS))
