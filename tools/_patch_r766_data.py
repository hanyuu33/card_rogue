# -*- coding: utf-8 -*-
"""R766 数据层：懊悔（卡 9265）+ 猴爪（遗物 6066）+ 四语文本。

写入策略按文件各自的格式分两种，别混：
  * `relics.json` / `noncard_en|ja|es.json` 是**标准 `json.dumps(indent=2)` 输出** →
    直接 json 加载改写再 dump，diff 只多一条；
  * `cards.json`（CRLF + `"affixes": ["次元"]` 内联数组）/ `noncard_zh_canonical.json`
    （一行一条 compact）/ `cards_en|ja|es.json`（indent=1 多行）**都不是**标准输出 →
    一律**文本精确插入**，锚点带 assert count==1。

⚠️ 术语按 `i18n/noncard_zh_canonical.json` 的 rules：「手牌」不是「手卡」、
「消失 = 本场对战移除」。「弃牌区」是规范词。
"""
import io
import json
import pathlib

ROOT = pathlib.Path(r"E:\work\card_rogue")

CARD_ID = 9265
RELIC_ID = 6066

# ---------------------------------------------------------------- cards.json
CARD_ZH = """    {
      "id": 9265,
      "name": "懊悔",
      "kind": "诅咒",
      "cost": 1,
      "power": 0,
      "health": 0,
      "attack_range": 0,
      "move_speed": 0,
      "rarity": 6,
      "group": "player",
      "class": "",
      "traits": [
        "懊悔"
      ],
      "affixes": ["次元"],
      "effect_text": "选弃牌区一张其他职业卡消失。",
      "target_mode": "none",
      "value": 0,
      "color": "暗影",
      "image": ""
    }"""

TAIL_ANCHOR = (
    '      "effect_text": "从三个其他职业的盟友中选一张，加入手卡。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "value": 1,\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    }\r\n'
    '  ]\r\n'
    '}\r\n'
)

p = ROOT / "cards.json"
raw = p.read_bytes().decode("utf-8")
assert '"id": 9265' not in raw, "9265 已存在，别重复插入"
assert raw.count(TAIL_ANCHOR) == 1, "cards.json 尾部锚点不唯一"
new_tail = (
    TAIL_ANCHOR[:-len("    }\r\n  ]\r\n}\r\n")]
    + "    },\r\n"
    + CARD_ZH.replace("\n", "\r\n") + "\r\n"
    + "  ]\r\n}\r\n"
)
raw = raw.replace(TAIL_ANCHOR, new_tail)
p.write_bytes(raw.encode("utf-8"))
print("cards.json +9265   size", p.stat().st_size)


# --------------------------------------------------------------- relics.json
p = ROOT / "relics.json"
d = json.loads(p.read_text(encoding="utf-8"))
relics = d["relics"]
assert all(int(r["id"]) != RELIC_ID for r in relics), "6066 已被占用"
relics.append({
    "id": RELIC_ID,
    "name": "猴爪",
    "kind": "战斗",
    "source": "奖励",
    "tier": "稀有",
    "desc": "每场战斗的前三个回合开始时：将一张随机其他职业卡加入手牌，并将一张「懊悔」加入卡组。",
})
relics.sort(key=lambda r: int(r["id"]))
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n",
             encoding="utf-8", newline="\n")
print("relics.json +6066  size", p.stat().st_size)


# ------------------------------------------- noncard_zh_canonical（compact 行）
p = ROOT / "i18n" / "noncard_zh_canonical.json"
raw = p.read_text(encoding="utf-8")
assert '"6066"' not in raw, "noncard_zh 已有 6066"
line_6065 = next(ln for ln in raw.split("\n") if ln.strip().startswith('"6065":'))
assert raw.count(line_6065) == 1
new_line = ('    "6066": {"name": "猴爪", "desc": "每场战斗的前三个回合开始时：'
            '将一张随机其他职业卡加入手牌，并将一张「懊悔」加入卡组。"},')
raw = raw.replace(line_6065, line_6065 + "\n" + new_line)
p.write_text(raw, encoding="utf-8", newline="\n")
print("noncard_zh_canonical +6066")


# ------------------------------------------------ noncard_en/ja/es（标准 dump）
NONCARD = {
    "en": {"name": "Monkey's Paw",
           "desc": "At the start of each of the first three turns of every battle: add a random card of another class to your Hand, and add a Regret to your Deck."},
    "ja": {"name": "猿の手",
           "desc": "戦闘ごとの最初の3ターン開始時：他職のランダムなカード1枚を手札に加え、デッキに「後悔」を1枚加える。"},
    "es": {"name": "Pata de mono",
           "desc": "Al inicio de cada uno de los tres primeros turnos de cada combate: añade una carta aleatoria de otra clase a tu mano y añade un Arrepentimiento a tu mazo."},
}
for lang, entry in NONCARD.items():
    p = ROOT / "i18n" / ("noncard_%s.json" % lang)
    d = json.loads(p.read_text(encoding="utf-8"))
    assert "6066" not in d["relics"], "%s 已有 6066" % lang
    d["relics"]["6066"] = entry
    d["relics"] = dict(sorted(d["relics"].items(), key=lambda kv: int(kv[0])))
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n",
                 encoding="utf-8", newline="\n")
    print("noncard_%s +6066" % lang)


# ------------------------------------------------ cards_en/ja/es（尾部文本插入）
CARDS_L10N = {
    "en": {"name": "Regret",
           "effect_text": "Choose a card of another class in the discard pile. It is Banished."},
    "ja": {"name": "後悔",
           "effect_text": "捨て札置き場から他職のカード1枚を選ぶ。それは消滅する。"},
    "es": {"name": "Arrepentimiento",
           "effect_text": "Elige una carta de otra clase en la pila de descarte. Se destierra."},
}
for lang, entry in CARDS_L10N.items():
    p = ROOT / "i18n" / ("cards_%s.json" % lang)
    raw = p.read_text(encoding="utf-8")
    assert '"9265"' not in raw, "%s 已有 9265" % lang
    tail = "\n  }\n }\n}\n"
    assert raw.count(tail) == 1, "%s 尾部锚点不唯一（%d）" % (lang, raw.count(tail))
    body = ('\n  },\n'
            '  "9265": {\n'
            '   "name": %s,\n'
            '   "effect_text": %s\n'
            '  }\n }\n}\n' % (json.dumps(entry["name"], ensure_ascii=False),
                              json.dumps(entry["effect_text"], ensure_ascii=False)))
    raw = raw.replace(tail, body)
    p.write_text(raw, encoding="utf-8", newline="\n")
    print("cards_%s +9265" % lang)


# ------------------------------------------------------------------ 复核
print("\n--- verify ---")
d = json.loads((ROOT / "cards.json").read_text(encoding="utf-8"))
c = [x for x in d["cards"] if int(x["id"]) == CARD_ID][0]
print("card:", json.dumps(c, ensure_ascii=False))
d = json.loads((ROOT / "relics.json").read_text(encoding="utf-8"))
r = [x for x in d["relics"] if int(x["id"]) == RELIC_ID][0]
print("relic:", json.dumps(r, ensure_ascii=False))
for lang in ("en", "ja", "es"):
    cd = json.loads((ROOT / "i18n" / ("cards_%s.json" % lang)).read_text(encoding="utf-8"))
    nd = json.loads((ROOT / "i18n" / ("noncard_%s.json" % lang)).read_text(encoding="utf-8"))
    print(lang, "card:", json.dumps(cd["cards"]["9265"], ensure_ascii=False))
    print(lang, "relic:", json.dumps(nd["relics"]["6066"], ensure_ascii=False))
raw = (ROOT / "cards.json").read_bytes()
print("cards.json 仍为 CRLF:", b"\r\n" in raw and raw.count(b"\n") == raw.count(b"\r\n"))
