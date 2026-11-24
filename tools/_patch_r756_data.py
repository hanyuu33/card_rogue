# -*- coding: utf-8 -*-
"""R756 数据补丁：
 * cards.json：新增「代偿」9252（2 费诅咒 · 次元 · 在手卡里期间其余手卡 +1 费）
 * relics.json：苹果 6027 / 咒缚 6058 的描述改口径
 * i18n：cards_*（新卡四语）、noncard_*（两件道具四语）、narrative_*（苹果 / 占卜四语）、
         event_ui_*（占卜按钮四语）、source_aliases（旧串→新串）
"""
import io
import json


def T(path):
    s = io.open(path, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    return (s.replace("\r\n", "\n") if crlf else s), crlf


def W(path, s, crlf):
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(path, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag):
    n = s.count(old)
    assert n == 1, "%s: count=%d" % (tag, n)
    print("  ok  %s" % tag)
    return s.replace(old, new)


def insert_card_entry(path, entry_lines, count_old=None, count_new=None):
    """在 i18n/cards_*.json 的 "9251" 条目之后插入新条目（保持 1 空格缩进风格）。"""
    s, crlf = T(path)
    lines = s.split("\n")
    i = -1
    for k, ln in enumerate(lines):
        if ln == '  "9251": {':
            i = k
            break
    assert i >= 0, path
    j = -1
    for k in range(i + 1, len(lines)):
        if lines[k] == "  }":
            j = k
            break
    assert j > i, path
    lines[j] = "  },"
    lines[j + 1:j + 1] = entry_lines
    s = "\n".join(lines)
    if count_old is not None:
        s = rep(s, '"count": %d' % count_old, '"count": %d' % count_new, path + "/count")
    W(path, s, crlf)
    print("  ok  %s/9252" % path)


NEW = {
    "zh_canonical": ('  "9252": {', '   "name": "代偿",',
                     '   "effect_text": "这张卡在手卡时，你的其他手卡费用 +1。",',
                     '   "changed": false', '  }'),
    "cards_en": ('  "9252": {', '   "name": "Compensation",',
                 '   "effect_text": "While this card is in your Hand, your other cards in Hand cost +1.",',
                 '  }'),
    "cards_ja": ('  "9252": {', '   "name": "代償",',
                 '   "effect_text": "このカードが手札にある間、他の手札のコスト+1。",',
                 '  }'),
    "cards_es": ('  "9252": {', '   "name": "Compensación",',
                 '   "effect_text": "Mientras esta carta esté en tu mano, tus otras cartas en la mano cuestan +1.",',
                 '  }'),
}
for key, row in NEW.items():
    path = "i18n/%s.json" % key
    insert_card_entry(path, list(row), 319, 320) if key != "zh_canonical" \
        else insert_card_entry(path, list(row))

# ---------------------------------------------------------------- cards.json
p = "cards.json"
s, c = T(p)
card = """    {
      "id": 9252,
      "name": "代偿",
      "kind": "诅咒",
      "cost": 2,
      "power": 0,
      "health": 0,
      "attack_range": 0,
      "move_speed": 0,
      "rarity": 6,
      "group": "player",
      "class": "",
      "traits": [
        "代偿"
      ],
      "affixes": ["次元"],
      "effect_text": "这张卡在手卡时，你的其他手卡费用 +1。",
      "target_mode": "none",
      "color": "暗影",
      "image": ""
    }
  ]
}
"""
s = rep(s, '      "image": ""\n    }\n  ]\n}\n', '      "image": ""\n    },\n' + card,
        "cards.json/新增 9252")
W(p, s, c)

# ---------------------------------------------------------------- relics.json
p = "relics.json"
s, c = T(p)
s = rep(s, '"desc": "最大生命 +7，并回复满生命值。"',
        '"desc": "最大生命 +7，并回复 20% 最大生命值。"', "relics/苹果描述")
s = rep(s, '"desc": "每场战斗你打出的第一张卡费用 -3；那张卡之后在本场战斗中费用 +1（再次上手时按 +1 后的费用算）。"',
        '"desc": "每场战斗你打出的第一张卡费用 -3（最低为 0，减费机会可跨回合保留）。"',
        "relics/咒缚描述")
W(p, s, c)

# ------------------------------------------------------- noncard_zh_canonical
p = "i18n/noncard_zh_canonical.json"
s, c = T(p)
s = rep(s, '"desc": "获得时：最大生命 +7，并回复至最大生命。"',
        '"desc": "获得时：最大生命 +7，并回复 20% 最大生命值。"', "非卡底本/苹果")
s = rep(s, '"desc": "每场战斗中，你打出的第一张非 X 费卡费用 -3（最低为 0，减费机会可跨回合保留）；那张卡之后在本场战斗中费用 +1。"',
        '"desc": "每场战斗中，你打出的第一张非 X 费卡费用 -3（最低为 0，减费机会可跨回合保留）。"',
        "非卡底本/咒缚")
W(p, s, c)

# ---------------------------------------------------------------- noncard 三语
NONCARD = {
    "noncard_en": (
        "On pickup: Gain +7 Max Health and restore your Health to maximum.",
        "On pickup: Gain +7 Max Health and restore 20% of your Max Health.",
        "The first non-X-Cost card you play each battle has Cost -3 (minimum 0; the unused discount carries over between turns). That card then has Cost +1 for the rest of the battle.",
        "The first non-X-Cost card you play each battle has Cost -3 (minimum 0; the unused discount carries over between turns)."),
    "noncard_ja": (
        "入手時：最大HP+7、HPを最大まで回復する。",
        "入手時：最大HP+7、最大HPの20%を回復する。",
        "各戦闘で最初に使用するXコストでないカードのコスト-3（最低0。減少の機会はターンをまたいで保持）。そのカードはその後、この戦闘中はコスト+1。",
        "各戦闘で最初に使用するXコストでないカードのコスト-3（最低0。減少の機会はターンをまたいで保持）。"),
    "noncard_es": (
        "Al recoger: obtén +7 de Vida máxima y recupera Vida hasta alcanzar el máximo.",
        "Al recoger: obtén +7 de Vida máxima y recupera un 20% de tu Vida máxima.",
        "La primera carta sin Coste X que juegues en cada combate tiene Coste -3 (mínimo 0; el descuento no utilizado se conserva entre turnos). Después, esa carta tiene Coste +1 durante el resto del combate.",
        "La primera carta sin Coste X que juegues en cada combate tiene Coste -3 (mínimo 0; el descuento no utilizado se conserva entre turnos)."),
}
for key, (a_old, a_new, c_old, c_new) in NONCARD.items():
    p = "i18n/%s.json" % key
    s, c = T(p)
    s = rep(s, a_old, a_new, key + "/苹果")
    s = rep(s, c_old, c_new, key + "/咒缚")
    W(p, s, c)

# ---------------------------------------------------------------- narrative
NARR = {
    "narrative_zh_canonical": (
        "获得「苹果」：最大生命 +7，并回复至最大生命。",
        "获得「苹果」：最大生命 +7，并回复 20% 最大生命值。",
        "占卜师收完钱就不见了，只留下这颗球，和一阵檀香。",
        "占卜师收完钱就不见了，只留下这颗球，和一阵檀香。\\n（占卜的代价：失去 5 点最大生命。）"),
    "narrative_en": (
        "Gain \\\"Apple\\\": Gain +7 Max Health and restore your Health to maximum.",
        "Gain \\\"Apple\\\": Gain +7 Max Health and restore 20% of your Max Health.",
        "leaving only the ball and a trace of sandalwood incense.",
        "leaving only the ball and a trace of sandalwood incense.\\n(The price of a reading: lose 5 Max Health.)"),
    "narrative_ja": (
        "「リンゴ」を得る：最大HP+7、HPを最大まで回復する。",
        "「リンゴ」を得る：最大HP+7、最大HPの20%を回復する。",
        "白檀の香りだけだ。",
        "白檀の香りだけだ。\\n（占いの代償：最大HPを5失う。）"),
    "narrative_es": (
        "Obtienes «Manzana»: obtén +7 de Vida máxima y recupera Vida hasta alcanzar el máximo.",
        "Obtienes «Manzana»: obtén +7 de Vida máxima y recupera un 20% de tu Vida máxima.",
        "dejando solo la bola y un rastro de incienso de sándalo.",
        "dejando solo la bola y un rastro de incienso de sándalo.\\n(El precio de la adivinación: pierdes 5 de Vida máxima.)"),
}
for key, (a_old, a_new, d_old, d_new) in NARR.items():
    p = "i18n/%s.json" % key
    s, c = T(p)
    s = rep(s, a_old, a_new, key + "/苹果")
    s = rep(s, d_old, d_new, key + "/占卜")
    W(p, s, c)

# ---------------------------------------------------------------- event_ui
UI = {
    "event_ui_zh_canonical": ("进行占卜", "进行占卜（失去 5 点最大生命）"),
    "event_ui_en": ("Perform a divination", "Perform a divination (lose 5 Max Health)"),
    "event_ui_ja": ("占いを行う", "占いを行う（最大HPを5失う）"),
    "event_ui_es": ("Realizar una adivinación", "Realizar una adivinación (pierdes 5 de Vida máxima)"),
}
for key, (a_old, a_new) in UI.items():
    p = "i18n/%s.json" % key
    s, c = T(p)
    s = rep(s, '"START_DIVINATION": "%s"' % a_old, '"START_DIVINATION": "%s"' % a_new, key + "/占卜按钮")
    W(p, s, c)

# ---------------------------------------------------------------- aliases
p = "i18n/source_aliases.json"
d = json.load(io.open(p, encoding="utf-8"))
hit = 0
for k in list(d.keys()):
    if "获得「苹果」：最大生命 +7" in k:
        d[k] = ("路边坐着一位医生，膝上摊着一本病历，抬头看了你一眼：\n"
                "「拿个苹果走吧。吃了它，就别再来找我。」\n"
                "获得「苹果」：最大生命 +7，并回复 20% 最大生命值。\n"
                "也可以什么也不接，转身离开——只是路上别再回头。")
        hit += 1
assert hit == 1, "apple alias %d" % hit
d["屋里只点着一支蜡烛，水晶球里浮着一层不肯散去的雾。\n\n「看得到什么，全看你相信什么。」\n\n占卜师收完钱就不见了，只留下这颗球，和一阵檀香。"] = (
    "屋里只点着一支蜡烛，水晶球里浮着一层不肯散去的雾。\n\n"
    "「看得到什么，全看你相信什么。」\n\n"
    "占卜师收完钱就不见了，只留下这颗球，和一阵檀香。\n（占卜的代价：失去 5 点最大生命。）")
io.open(p, "w", encoding="utf-8", newline="").write(
    json.dumps(d, ensure_ascii=False, indent=2) + "\n")
print("  ok  source_aliases")
print("all data patches applied")
