# -*- coding: utf-8 -*-
"""R767：给 interface 四语加 `daily` 域（每日修饰名 / 效果 / 面板文案）。
en/ja/es 走 JSON round-trip（已验证保形）；zh_canonical 是中文底本、格式不保形，走文本插入。"""
import json
import sys

# (key, zh, en, ja, es)
NAMES = [
    ("MOD_RICH", "富裕", "Wealthy", "富裕", "Acaudalado"),
    ("MOD_STURDY", "强健", "Stalwart", "頑健", "Robustecido"),
    ("MOD_RATIONS", "旅粮", "Rations", "旅糧", "Provisiones"),
    ("MOD_LUCKY", "幸运", "Lucky", "幸運", "Afortunado"),
    ("MOD_WARM", "温暖", "Warmth", "温暖", "Calidez"),
    ("MOD_GIFTED", "工具箱", "Toolkit", "道具箱", "Caja de herramientas"),
    ("MOD_MIXED", "杂牌", "Mixed Bag", "混成", "Baraja mixta"),
    ("MOD_FRAIL_FOE", "敌之孱弱", "Frail Foes", "敵の虚弱", "Enemigos débiles"),
    ("MOD_QUIET", "冷清", "Quiet Roads", "閑散", "Caminos tranquilos"),
    ("MOD_SURGE", "灵光", "Inspiration", "閃き", "Inspiración"),
    ("MOD_POOR", "贫瘠", "Poor", "貧窮", "Escasez"),
    ("MOD_ANEMIC", "贫血", "Anemic", "貧血", "Anemia"),
    ("MOD_HUNGRY", "饥饿", "Hungry", "空腹", "Hambre"),
    ("MOD_UNLUCKY", "倒霉", "Unlucky", "不運", "Mala suerte"),
    ("MOD_COLD", "阴冷", "Chill", "寒冷", "Frío"),
    ("MOD_CURSED", "诅咒", "Cursed", "呪い", "Maldición"),
    ("MOD_TOUGH_FOE", "敌之顽强", "Tough Foes", "敵の頑強", "Enemigos tenaces"),
    ("MOD_FIERCE", "凶猛", "Fierce", "凶猛", "Feroz"),
    ("MOD_CROWDED", "拥挤", "Crowded", "混雑", "Aglomeración"),
    ("MOD_DRAINED", "滞涩", "Sluggish", "澱み", "Estancamiento"),
]

DESCS = [
    ("MODDESC_RICH", "初始金币 +80", "Starting gold +80", "初期ゴールド +80", "Oro inicial +80"),
    ("MODDESC_STURDY", "最大生命 +15%", "Max HP +15%", "最大HP +15%", "PV máximos +15%"),
    ("MODDESC_RATIONS", "每层巧克力 +3", "Chocolate +3 per layer",
     "階層ごとにチョコ +3", "Chocolate +3 por piso"),
    ("MODDESC_LUCKY", "稀有卡获取概率 ×1.6", "Rare card chance ×1.6",
     "レア獲得率 ×1.6", "Probabilidad de raras ×1.6"),
    ("MODDESC_WARM", "休息回复 +15% 最大生命", "Rest heals +15% max HP",
     "休憩回復 +15% 最大HP", "El descanso cura +15% PV máx."),
    ("MODDESC_GIFTED", "开局多一件工具", "Start with an extra tool",
     "開始時に道具 +1", "Empiezas con una herramienta extra"),
    ("MODDESC_MIXED", "卡组多 3 张随机卡", "Deck gains 3 random cards",
     "デッキにランダム3枚追加", "El mazo gana 3 cartas aleatorias"),
    ("MODDESC_FRAIL_FOE", "敌人生命 −15%", "Enemy HP −15%", "敵HP −15%", "PV enemigos −15%"),
    ("MODDESC_QUIET", "精英出现概率 ×0.75", "Elite chance ×0.75",
     "エリート出現率 ×0.75", "Probabilidad de élite ×0.75"),
    ("MODDESC_SURGE", "每回合费用 +1", "+1 energy per turn",
     "毎ターンのコスト +1", "+1 de energía por turno"),
    ("MODDESC_POOR", "初始金币 −50", "Starting gold −50", "初期ゴールド −50", "Oro inicial −50"),
    ("MODDESC_ANEMIC", "最大生命 −12%", "Max HP −12%", "最大HP −12%", "PV máximos −12%"),
    ("MODDESC_HUNGRY", "每层巧克力 −3", "Chocolate −3 per layer",
     "階層ごとにチョコ −3", "Chocolate −3 por piso"),
    ("MODDESC_UNLUCKY", "稀有卡获取概率 ×0.5", "Rare card chance ×0.5",
     "レア獲得率 ×0.5", "Probabilidad de raras ×0.5"),
    ("MODDESC_COLD", "休息回复 −15% 最大生命", "Rest heals −15% max HP",
     "休憩回復 −15% 最大HP", "El descanso cura −15% PV máx."),
    ("MODDESC_CURSED", "卡组塞 2 张木栅栏", "Deck gains 2 Wooden Fences",
     "デッキに木の柵2枚追加", "El mazo gana 2 vallas de madera"),
    ("MODDESC_TOUGH_FOE", "敌人生命 +20%", "Enemy HP +20%", "敵HP +20%", "PV enemigos +20%"),
    ("MODDESC_FIERCE", "敌人攻击 +1", "Enemy attack +1", "敵の攻撃 +1", "Ataque enemigo +1"),
    ("MODDESC_CROWDED", "精英出现概率 ×1.5", "Elite chance ×1.5",
     "エリート出現率 ×1.5", "Probabilidad de élite ×1.5"),
    ("MODDESC_DRAINED", "每回合费用 −1", "−1 energy per turn",
     "毎ターンのコスト −1", "−1 de energía por turno"),
]

UI = [
    ("DAILY_MODS", "今日修正", "Today's Modifiers", "本日の修正", "Modificadores de hoy"),
    ("DAILY_DECK", "卡组", "Deck", "デッキ", "Mazo"),
    ("MOD_DECK_RANDOM", "随机构筑", "Randomized", "ランダム構築", "Aleatorio"),
]

ROWS = NAMES + DESCS + UI
assert len(ROWS) == 43, len(ROWS)


def build(col):
    return {r[0]: r[col] for r in ROWS}


def patch_json(path, values):
    raw = open(path, encoding="utf-8").read()
    d = json.loads(raw)
    if "daily" in d["scopes"]:
        print("  %s 已有 daily 域，跳过" % path)
        return
    d["scopes"]["daily"] = values
    out = json.dumps(d, ensure_ascii=False, indent=2)
    if not out.endswith("\n"):
        out += "\n"
    open(path, "w", encoding="utf-8", newline="\n").write(out)
    print("  %s +%d 条" % (path, len(values)))


print("en / ja / es:")
patch_json("i18n/interface_en.json", build(2))
patch_json("i18n/interface_ja.json", build(3))
patch_json("i18n/interface_es.json", build(4))

# zh_canonical：条目形如 {"source": "...", "zh": "..."}，逐条带出中文底本。
P = "i18n/interface_zh_canonical.json"
raw = open(P, encoding="utf-8").read()
if '"daily"' in raw:
    print("zh_canonical 已有 daily 域，跳过")
    sys.exit(0)

blocks = []
for key, zh, _en, _ja, _es in ROWS:
    blocks.append(
        '      "%s": {\n'
        '        "source": "scripts/daily_modifiers.gd",\n'
        '        "zh": %s\n'
        '      }' % (key, json.dumps(zh, ensure_ascii=False))
    )
chunk = '    "daily": {\n' + ",\n".join(blocks) + "\n    },\n"

anchor = '  "scopes": {\n'
assert raw.count(anchor) == 1, raw.count(anchor)
raw = raw.replace(anchor, anchor + chunk, 1)
open(P, "w", encoding="utf-8", newline="\n").write(raw)
print("  %s +%d 条（文本插入）" % (P, len(ROWS)))
# 立刻验证仍然是合法 JSON
json.loads(open(P, encoding="utf-8").read())
print("  zh_canonical JSON 合法")
