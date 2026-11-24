# -*- coding: utf-8 -*-
"""R842 补丁 ④ 事件长文与界面文案（各 4 语）。

narrative_*.json：events.<key> = {name, texts{常量名: 文本}}
event_ui_*.json：options / results / pickers 三处分组
全部 LF；逐条 exact-replace + assert count==1；插入顺序按既有排版（4/6/8 缩进）。
"""
import io
import json

ROOT = "E:/work/card_rogue/"

# ── 事件长文 ────────────────────────────────────────────────────────────────
NARR = {
    "zh_canonical": {
        "name": "龙石板",
        "texts": {
            "DRAGON_SLAB_DESC": (
                "荒原上斜插着一块土黄色的石板，比人还高半头。\n"
                "正面浮雕着一条盘龙，鳞爪被风磨得只剩起伏的轮廓，\n"
                "唯独龙眼那一小窝金漆没被吹走——太阳一照，像还醒着。\n"
                "你伸手按上去，石头底下传来一声极轻的呼吸。\n"
                "它没有开口，像是在等你先说出：它是一条什么样的龙。\n"
                "「强力的龙」：为一张盟友或工事附魔力量 +8；\n"
                "「尊贵的龙」：获得道具「稀有价值」——卡组里同名卡最多留 3 张，\n"
                "多出来的会被随机撕下，每因此效果删除一张卡，失去 5 点生命。\n"
                "也可以收回手，让这块石板继续站在这里。"
            ),
            "DRAGON_SLAB_MIGHT_DESC": (
                "石面上的龙纹亮了一瞬，像有一口气从石头里呼出来。\n"
                "再抬头时，指尖沾了一层金粉，石板已经裂开一道细缝——\n"
                "那条龙把力气分了一点给你带着的东西。"
            ),
            "DRAGON_SLAB_NOBLE_DESC": (
                "石板从中间裂开，土黄的碎屑簌簌落了一地。\n"
                "裂口里没有龙，只有一枚打磨得极亮的鳞片，凉得像井水。\n"
                "你身上那些多余的东西被它一一数过——数到第四件，就撕下来丢进裂缝里。"
            ),
        },
    },
    "en": {
        "name": "Dragon Slab",
        "texts": {
            "DRAGON_SLAB_DESC": (
                "A slab of ochre stone leans in the wasteland, half a head taller than you.\n"
                "A coiled dragon is carved across its face; wind has worn scales and claws into shallow ridges,\n"
                "and only the small hollow of its eye still holds gold paint — in the sun it looks awake.\n"
                "You press your palm to it, and something very light breathes under the stone.\n"
                "It says nothing, as if waiting for you to say what kind of dragon it is.\n"
                "\"The mighty dragon\": enchant one Ally or Structure with +8 Power;\n"
                "\"the noble dragon\": gain the relic \"Rare Value\" — your deck keeps at most 3 copies of each name,\n"
                "the extras are torn out at random, and you lose 5 Health for each card removed this way.\n"
                "Or you can take your hand back and leave the slab standing here."
            ),
            "DRAGON_SLAB_MIGHT_DESC": (
                "The dragon relief flares once, as if a breath had left the stone.\n"
                "When you look up again your fingertips are dusted with gold, and a thin crack runs across the slab —\n"
                "that dragon has lent a little of its strength to what you carry."
            ),
            "DRAGON_SLAB_NOBLE_DESC": (
                "The slab splits down the middle and ochre crumbs spill across the ground.\n"
                "There is no dragon inside, only a single scale polished to a hard shine, cold as well water.\n"
                "It counted every surplus thing you carried — and at the fourth, tore it out and dropped it in."
            ),
        },
    },
    "ja": {
        "name": "龍の石板",
        "texts": {
            "DRAGON_SLAB_DESC": (
                "荒れ地に土色の石板が斜めに立っている。背丈より半頭ほど高い。\n"
                "表面には盤龍が浮き彫りにされ、鱗も爪も風に削られて起伏だけが残り、\n"
                "龍の目のくぼみにだけ金箔が残っている——陽に当たると、まだ目を覚ましているようだ。\n"
                "手のひらを当てると、石の底からごく浅い息づかいが伝わってくる。\n"
                "龍は口を開かない。お前はどんな龍だ、と先に言われるのを待っているようだ。\n"
                "「強き龍」：味方か建造物1枚に力+8を付呪する。\n"
                "「貴き龍」：レリック「希少価値」を得る——デッキ内の同名カードは最大3枚まで残り、\n"
                "超えた分はランダムに引きちぎられ、この効果で削除された1枚ごとに体力を5失う。\n"
                "手を引いて、この石板をそのまま立たせておくこともできる。"
            ),
            "DRAGON_SLAB_MIGHT_DESC": (
                "石面の龍紋が一瞬だけ光り、石の中から息が漏れたようだった。\n"
                "顔を上げると指先に金粉がついていて、石板には細い亀裂が走っている——\n"
                "あの龍は、お前の持ち物に力を少し分けてくれたのだ。"
            ),
            "DRAGON_SLAB_NOBLE_DESC": (
                "石板は真ん中から割れ、土色の欠片が地面に降りそそいだ。\n"
                "割れ目の中に龍はいない。あるのは磨き上げられた1枚の鱗だけで、井戸水のように冷たい。\n"
                "お前が抱えている余分なものを1つずつ数え、4つ目で引きちぎって割れ目に落とした。"
            ),
        },
    },
    "es": {
        "name": "Losa del dragón",
        "texts": {
            "DRAGON_SLAB_DESC": (
                "Una losa de piedra ocre se inclina en el yermo, media cabeza más alta que tú.\n"
                "En su cara está tallado un dragón enroscado; el viento gastó escamas y garras hasta dejar solo relieves,\n"
                "y únicamente la cuenca de su ojo conserva pintura de oro: bajo el sol parece despierto.\n"
                "Apoyas la palma y algo muy leve respira bajo la piedra.\n"
                "No dice nada, como si esperara que tú digas qué clase de dragón es.\n"
                "«El dragón poderoso»: otorga +8 de Poder a un Aliado o Estructura;\n"
                "«el dragón noble»: obtienes el objeto «Valor escaso»; tu mazo conserva como máximo 3 copias de cada nombre,\n"
                "las sobrantes se arrancan al azar y pierdes 5 de vida por cada carta retirada por este efecto.\n"
                "También puedes retirar la mano y dejar la losa donde está."
            ),
            "DRAGON_SLAB_MIGHT_DESC": (
                "El relieve del dragón brilla un instante, como si un aliento hubiera salido de la piedra.\n"
                "Al levantar la vista tienes los dedos cubiertos de polvo de oro y una grieta fina cruza la losa:\n"
                "ese dragón le ha prestado un poco de su fuerza a lo que llevas."
            ),
            "DRAGON_SLAB_NOBLE_DESC": (
                "La losa se parte por la mitad y los fragmentos ocres caen al suelo.\n"
                "No hay ningún dragón dentro, solo una escama pulida hasta brillar, fría como agua de pozo.\n"
                "Contó una a una las cosas sobrantes que llevabas, y a la cuarta la arrancó y la echó en la grieta."
            ),
        },
    },
}

# ── 界面文案 ────────────────────────────────────────────────────────────────
OPTIONS = {
    "zh_canonical": {
        "MIGHT": "「强力的龙」：为一张盟友或工事附魔力量 +8",
        "NOBLE": "「尊贵的龙」：获得「稀有价值」",
        "NO_ALLY_DISABLED": "卡组里没有可附魔的盟友或工事",
        "LETHAL_DISABLED": "生命不足（这样选会当场倒下）",
        "LEAVE": "离开（不碰这块石板）",
    },
    "en": {
        "MIGHT": "\"The mighty dragon\": enchant one Ally or Structure with +8 Power",
        "NOBLE": "\"The noble dragon\": gain \"Rare Value\"",
        "NO_ALLY_DISABLED": "No Ally or Structure in your deck can be enchanted",
        "LETHAL_DISABLED": "Not enough Health (this choice would kill you)",
        "LEAVE": "Leave (do not touch the slab)",
    },
    "ja": {
        "MIGHT": "「強き龍」：味方か建造物1枚に力+8を付呪する",
        "NOBLE": "「貴き龍」：レリック「希少価値」を得る",
        "NO_ALLY_DISABLED": "デッキに付呪できる味方・建造物がない",
        "LETHAL_DISABLED": "体力が足りない（この選択で倒れる）",
        "LEAVE": "立ち去る（石板に触らない）",
    },
    "es": {
        "MIGHT": "«El dragón poderoso»: otorga +8 de Poder a un Aliado o Estructura",
        "NOBLE": "«El dragón noble»: obtienes «Valor escaso»",
        "NO_ALLY_DISABLED": "No hay Aliados ni Estructuras que puedan recibir el encantamiento",
        "LETHAL_DISABLED": "Vida insuficiente (esta elección te mataría)",
        "LEAVE": "Marcharse (no tocar la losa)",
    },
}

RESULTS = {
    "zh_canonical": {
        "MIGHT_GAINED": "附魔「力量 +8」已烤进你选的那张卡（力量 %d → %d）",
        "NOBLE_GAINED": "「稀有价值」已收进道具栏：撕掉 %d 张同名卡，失去 %d 点生命（现 %d / %d）",
        "NOBLE_NONE": "「稀有价值」已收进道具栏：没有超过 3 张的同名卡，一张也没撕",
    },
    "en": {
        "MIGHT_GAINED": "The enchantment \"Power +8\" is now baked into the card you chose (Power %d → %d)",
        "NOBLE_GAINED": "\"Rare Value\" goes into your relics: %d duplicate cards torn out, %d Health lost (now %d / %d)",
        "NOBLE_NONE": "\"Rare Value\" goes into your relics: no name had more than 3 copies, nothing was torn out",
    },
    "ja": {
        "MIGHT_GAINED": "付呪「パワー+8」が選んだカードに焼き込まれた（力%d → %d）",
        "NOBLE_GAINED": "「希少価値」をレリック欄に収めた：同名カードを%d枚引きちぎり、体力を%d失った（現在 %d / %d）",
        "NOBLE_NONE": "「希少価値」をレリック欄に収めた：同名カードが3枚を超えていなかったため、1枚も引きちぎらなかった",
    },
    "es": {
        "MIGHT_GAINED": "El encantamiento «Poder +8» ya está grabado en la carta que elegiste (Poder %d → %d)",
        "NOBLE_GAINED": "«Valor escaso» entra en tus objetos: %d cartas duplicadas arrancadas, %d de vida perdida (ahora %d / %d)",
        "NOBLE_NONE": "«Valor escaso» entra en tus objetos: ninguna carta superaba las 3 copias, no se arrancó nada",
    },
}

PICKERS = {
    "zh_canonical": {
        "title": "龙石板 · 挑选一张盟友或工事",
        "note": "只能选还没附魔的盟友或工事（每张卡只有一个附魔位）",
        "confirm_label": "附上「力量 +8」",
        "cancel_label": "再想想（收起）",
        "short": "龙石板",
    },
    "en": {
        "title": "Dragon Slab · Choose an Ally or Structure",
        "note": "Only Allies or Structures without an enchantment (one enchantment per card)",
        "confirm_label": "Enchant with \"Power +8\"",
        "cancel_label": "Think again (collapse)",
        "short": "Dragon Slab",
    },
    "ja": {
        "title": "龍の石板 · 味方か建造物を1枚選ぶ",
        "note": "まだ付呪されていない味方・建造物のみ（付呪は1枚につき1つ）",
        "confirm_label": "「パワー+8」を付呪する",
        "cancel_label": "やめておく（閉じる）",
        "short": "龍の石板",
    },
    "es": {
        "title": "Losa del dragón · Elige un Aliado o Estructura",
        "note": "Solo Aliados o Estructuras sin encantamiento (uno por carta)",
        "confirm_label": "Encantar con «Poder +8»",
        "cancel_label": "Pensarlo mejor (cerrar)",
        "short": "Losa del dragón",
    },
}


def read(p):
    with io.open(ROOT + p, "rb") as f:
        return f.read().decode("utf-8")


def write(p, s):
    with io.open(ROOT + p, "wb") as f:
        f.write(s.encode("utf-8"))


def j(v):
    return json.dumps(v, ensure_ascii=False)


def group_block(key, entries, indent, trailing_comma=True):
    pad = " " * indent
    inner = " " * (indent + 2)
    lines = ['%s"%s": {' % (pad, key)]
    keys = list(entries)
    for i, k in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        lines.append('%s"%s": %s%s' % (inner, k, j(entries[k]), comma))
    lines.append("%s}%s" % (pad, "," if trailing_comma else ""))
    return "\n".join(lines)


for lang in ("zh_canonical", "en", "ja", "es"):
    # ① narrative
    p = "i18n/narrative_%s.json" % lang
    s = read(p)
    assert "\r\n" not in s
    row = NARR[lang]
    inner = " " * 8
    lines = ['    "dragon_slab": {', '      "name": %s,' % j(row["name"]), '      "texts": {']
    texts = list(row["texts"])
    for i, k in enumerate(texts):
        comma = "," if i < len(texts) - 1 else ""
        lines.append('%s"%s": %s%s' % (inner, k, j(row["texts"][k]), comma))
    lines.append("      }")
    lines.append("    },")
    block = "\n".join(lines) + "\n"
    anchor = '    "haunted_house": {'
    assert s.count(anchor) == 1, "%s narrative 锚点 %d" % (p, s.count(anchor))
    s = s.replace(anchor, block + anchor, 1)
    write(p, s)
    print("OK", p)

    # ② event_ui：options / results / pickers
    p = "i18n/event_ui_%s.json" % lang
    s = read(p)
    assert "\r\n" not in s
    a_opt = '\n    },\n    "factory": {\n      "FACTORY_STAGE_1"'
    assert s.count(a_opt) == 1, "%s options 锚点 %d" % (p, s.count(a_opt))
    s = s.replace(a_opt, "\n    },\n" + group_block("dragon_slab", OPTIONS[lang], 4)
                  + '\n    "factory": {\n      "FACTORY_STAGE_1"', 1)
    a_res = '\n    },\n    "factory": {\n      "FACTORY_FREE"'
    assert s.count(a_res) == 1, "%s results 锚点 %d" % (p, s.count(a_res))
    s = s.replace(a_res, "\n    },\n" + group_block("dragon_slab", RESULTS[lang], 4)
                  + '\n    "factory": {\n      "FACTORY_FREE"', 1)
    a_pick = '\n  },\n  "results": {'
    assert s.count(a_pick) == 1, "%s pickers 锚点 %d" % (p, s.count(a_pick))
    s = s.replace(a_pick, "\n" + group_block("dragon_slab", PICKERS[lang], 4)
                  + '\n  },\n  "results": {', 1)
    write(p, s)
    print("OK", p)

print("done")
