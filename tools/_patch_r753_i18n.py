# -*- coding: utf-8 -*-
"""R753：事件「奇异雕像」+ 石头（7012）三语文案。"""
import json

TODAY = "2026-11-15"

# ── 中文权威（narrative）──
ZH_DESC = """空地上立着一尊巨大的白石雕像，雨水把它洗得发灰。
狮子的躯干、背上探出的山羊头、尾巴末端盘着的蛇——
你在一本讲嵌合兽的旧册子上见过这个姿势，只是它不该出现在这片林子里。
石缝里全是苔，底座上的字早被磨平了。"""

ZH_PRAY = """你把手按在它冰凉的爪子上，什么也没说。
石头里传来一声很轻的、像是应答的震动——
接下来三场战斗，每次胜利都会从残骸里翻出一件工具。"""

ZH_SMASH = """你抄起一块石头砸向它的前腿。
裂纹从爪子一路爬到山羊头上，整尊雕像塌成一堆白渣——
握得住的那些，正好够塞满你的工具栏。"""

NARRATIVE = {
    "en": {
        "name": "The Strange Statue",
        "desc": """A colossal white stone statue stands in the clearing, washed grey by the rain.
A lion's body, a goat's head rising from its back, a serpent coiled at the tip of its tail —
you have seen that pose in an old volume on chimeras, though it has no business being in this forest.
Moss fills every crack; the words on the pedestal were worn away long ago.""",
        "pray": """You lay your hand on its cold paw and say nothing.
Something answers from inside the stone — a faint, patient tremor.
For the next three battles, every victory will give up a tool from the wreckage.""",
        "smash": """You pick up a stone and bring it down on the foreleg.
A crack runs from the paw up to the goat's head, and the whole statue collapses into white rubble —
the pieces that still fit your hand are exactly enough to fill your tool bar.""",
    },
    "ja": {
        "name": "奇妙な石像",
        "desc": """空き地に巨大な白石の像が立っている。雨に洗われて灰色になっていた。
獅子の胴、背から伸びた山羊の頭、尾の先に巻きついた蛇——
その姿は嵌合獣の古い画集で見たことがある。だが、この森にあるはずがない。
石の隙間は苔で埋まり、台座の文字はとうに磨り減っていた。""",
        "pray": """冷たい前脚に手を置いて、何も言わなかった。
石の内側から、応えるような微かな震えが返ってくる——
次の 3 戦闘、勝利のたびに残骸からツールが一つ見つかる。""",
        "smash": """石を拾い上げ、前脚に叩きつけた。
ひびは前脚から山羊の頭へ一気に走り、像は白い瓦礫と化した——
手に収まる大きさのものだけでも、ツールバーは埋まってしまう。""",
    },
    "es": {
        "name": "La estatua extraña",
        "desc": """En el claro se alza una colosal estatua de piedra blanca, lavada a gris por la lluvia.
Cuerpo de león, una cabeza de cabra que asoma del lomo, una serpiente enroscada en la punta de la cola:
ya habías visto esa pose en un viejo volumen sobre quimeras, aunque no debería estar en este bosque.
El musgo llena cada grieta; las palabras del pedestal se borraron hace mucho.""",
        "pray": """Apoyas la mano en su pata fría y no dices nada.
Algo responde desde dentro de la piedra: un temblor leve, paciente.
Durante las próximas 3 batallas, cada victoria entregará una herramienta entre los escombros.""",
        "smash": """Recoges una piedra y la estrellas contra la pata delantera.
Una grieta sube de la pata a la cabeza de cabra y la estatua entera se derrumba en cascotes blancos:
los trozos que aún caben en tu mano bastan para llenar la barra de herramientas.""",
    },
}

# ── 选项 / 结果（event_ui）──
OPTIONS = {
    "zh": {
        "PRAY": "祭拜（接下来三场战斗必定掉落工具）",
        "SMASH": "摧毁（工具栏用「石头」填满）",
        "LEAVE": "绕过去（什么都不做）",
    },
    "en": {
        "PRAY": "Worship (the next 3 battles are guaranteed to drop a tool)",
        "SMASH": "Smash it (fill your tool bar with Stones)",
        "LEAVE": "Walk past (do nothing)",
    },
    "ja": {
        "PRAY": "参拝する（次の 3 戦闘で必ずツールがドロップ）",
        "SMASH": "破壊する（ツールバーを「石」で埋める）",
        "LEAVE": "通り過ぎる（何もしない）",
    },
    "es": {
        "PRAY": "Rendir culto (las próximas 3 batallas garantizan una herramienta)",
        "SMASH": "Destruirla (llena la barra de herramientas con Piedras)",
        "LEAVE": "Pasar de largo (no hacer nada)",
    },
}

RESULTS = {
    "zh": {
        "STATUE_PRAY": "已祭拜：接下来 %d 场战斗，每次胜利都必定掉落一件工具。",
        "STATUE_SMASH": "雕像塌了：工具栏里塞进 %d 块「石头」（拖到敌人身上砸 15 点伤害）。",
        "STATUE_SMASH_FULL": "雕像塌了，可你的工具栏已经满了 —— 碎块只能留在原地。",
    },
    "en": {
        "STATUE_PRAY": "Worshipped: the next %d battles each guarantee one tool drop.",
        "STATUE_SMASH": "The statue collapses: %d Stones stuffed into your tool bar (drag one onto an enemy for 15 damage).",
        "STATUE_SMASH_FULL": "The statue collapses, but your tool bar is already full — the rubble stays where it fell.",
    },
    "ja": {
        "STATUE_PRAY": "参拝した：次の %d 戦闘は毎回必ずツールが手に入る。",
        "STATUE_SMASH": "像は崩れた：ツールバーに「石」を %d 個詰め込んだ（敵にドラッグで 15 ダメージ）。",
        "STATUE_SMASH_FULL": "像は崩れたが、ツールバーはすでに満杯だ——瓦礫はそのまま残った。",
    },
    "es": {
        "STATUE_PRAY": "Culto rendido: las próximas %d batallas garantizan una herramienta cada una.",
        "STATUE_SMASH": "La estatua se derrumba: %d Piedras llenan la barra (arrastra una a un enemigo para 15 de daño).",
        "STATUE_SMASH_FULL": "La estatua se derrumba, pero la barra ya está llena: los escombros se quedan donde cayeron.",
    },
}

STONE = {
    "zh": ("石头", "拖到敌方单位身上。对它造成 15 点伤害，用掉后从工具栏移除。"),
    "en": ("Stone", "Drag it onto an enemy unit. Deals 15 damage to it, then the tool is used up."),
    "ja": ("石", "敵ユニットにドラッグ。15 ダメージを与え、使用後はツールバーから消える。"),
    "es": ("Piedra", "Arrástrala sobre una unidad enemiga. Inflige 15 de daño y la herramienta se consume."),
}


def load(path):
    return json.loads(open(path, encoding='utf-8').read())


def save(path, data, indent):
    open(path, 'w', encoding='utf-8', newline='\n').write(
        json.dumps(data, ensure_ascii=False, indent=indent) + '\n')


# ① narrative_zh_canonical：加 events.statue
p = 'i18n/narrative_zh_canonical.json'
d = load(p)
d['events']['statue'] = {"name": "奇异雕像", "texts": {
    "STATUE_DESC": ZH_DESC, "STATUE_PRAY_DESC": ZH_PRAY, "STATUE_SMASH_DESC": ZH_SMASH}}
d['updated'] = TODAY
save(p, d, 2)

# ② narrative_{en,ja,es}
for lang in ("en", "ja", "es"):
    p = 'i18n/narrative_%s.json' % lang
    d = load(p)
    t = NARRATIVE[lang]
    d['events']['statue'] = {"name": t["name"], "texts": {
        "STATUE_DESC": t["desc"], "STATUE_PRAY_DESC": t["pray"], "STATUE_SMASH_DESC": t["smash"]}}
    d['updated'] = TODAY
    save(p, d, 2)

# ③ event_ui_zh_canonical：选项 + 结果
p = 'i18n/event_ui_zh_canonical.json'
d = load(p)
d['options']['statue'] = OPTIONS['zh']
d['results']['statue'] = RESULTS['zh']
d['updated'] = TODAY
save(p, d, 2)

for lang in ("en", "ja", "es"):
    p = 'i18n/event_ui_%s.json' % lang
    d = load(p)
    d['options']['statue'] = OPTIONS[lang]
    d['results']['statue'] = RESULTS[lang]
    d['updated'] = TODAY
    save(p, d, 2)

# ④ traps 三语：加 7012
for lang in ("en", "ja", "es"):
    p = 'i18n/traps_%s.json' % lang
    d = load(p)
    n, de = STONE[lang]
    d['traps']['7012'] = {"name": n, "desc": de}
    save(p, d, 1)

print('i18n ok')
