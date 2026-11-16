# -*- coding: utf-8 -*-
"""R776 数据补丁：两张吟游诗人卡。

9267 激励乐章（技能 · 1 费 · 普通 rarity 0）
9268 管风琴（工事 · 4 费 · 0 力量 / 射程 7 / 19 生命 · 史诗 rarity 2）

cards.json 是 CRLF，一律按字节原文插入，不走 json.dumps 整篇重写。
"""
import io
import json

ROOT = "cards.json"

INSPIRE = (
    '    {\r\n'
    '      "id": 9267,\r\n'
    '      "name": "激励乐章",\r\n'
    '      "kind": "技能",\r\n'
    '      "cost": 1,\r\n'
    '      "power": 0,\r\n'
    '      "health": 0,\r\n'
    '      "attack_range": 0,\r\n'
    '      "move_speed": 0,\r\n'
    '      "rarity": 0,\r\n'
    '      "group": "player",\r\n'
    '      "class": "吟游诗人",\r\n'
    '      "traits": [],\r\n'
    '      "affixes": [],\r\n'
    '      "effect_text": "本回合场上所有盟友力量 +4；原本职业不属于自己的盟友改为 +6。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    },\r\n'
)

ORGAN = (
    '    {\r\n'
    '      "id": 9268,\r\n'
    '      "name": "管风琴",\r\n'
    '      "kind": "工事",\r\n'
    '      "cost": 4,\r\n'
    '      "power": 0,\r\n'
    '      "health": 19,\r\n'
    '      "attack_range": 7,\r\n'
    '      "move_speed": 0,\r\n'
    '      "rarity": 2,\r\n'
    '      "group": "player",\r\n'
    '      "class": "吟游诗人",\r\n'
    '      "traits": [\r\n'
    '        "工事",\r\n'
    '        "管风琴"\r\n'
    '      ],\r\n'
    '      "affixes": [],\r\n'
    '      "effect_text": "攻击时，从卡组将一张随机技能卡加入手卡，该卡本回合费用 -1。在场时，每使用一张技能卡，对所有敌人造成 3 点伤害。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    }\r\n'
)

raw = io.open(ROOT, "rb").read().decode("utf-8")
assert '"id": 9267' not in raw and '"id": 9268' not in raw

# 9266 是最后一张 → 在它的收尾 "    }\r\n  ]\r\n}\r\n" 前插入两张
tail = (
    '      "effect_text": "费用本局 +1。将一张随机比这张卡费用高 1 的其他职业盟友加入手卡，'
    '其费用本局变为 0。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    }\r\n'
    '  ]\r\n'
    '}\r\n'
)
assert raw.count(tail) == 1, raw.count(tail)
new_tail = (
    '      "effect_text": "费用本局 +1。将一张随机比这张卡费用高 1 的其他职业盟友加入手卡，'
    '其费用本局变为 0。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    },\r\n'
) + INSPIRE + ORGAN + '  ]\r\n}\r\n'
raw = raw.replace(tail, new_tail)
io.open(ROOT, "wb").write(raw.encode("utf-8"))

data = json.loads(io.open(ROOT, "rb").read().decode("utf-8"))
ids = [c["id"] for c in data["cards"]]
assert ids.count(9267) == 1 and ids.count(9268) == 1
print("cards.json OK，总卡数", len(data["cards"]))

# ── zh_canonical：尾插两条（该文件 json 往返不保序，按原文精确插） ──
ZC = "i18n/zh_canonical.json"
z_raw = io.open(ZC, "rb").read().decode("utf-8")
z_tail = (
    '  "9266": {\n'
    '   "name": "呼唤",\n'
    '   "effect_text": "费用本局 +1。将一张随机比这张卡费用高 1 的其他职业盟友加入手卡，'
    '其费用本局变为 0。",\n'
    '   "changed": false\n'
    '  }\n'
    ' }\n'
    '}'
)
assert z_raw.count(z_tail) == 1, z_raw.count(z_tail)
z_new = (
    '  "9266": {\n'
    '   "name": "呼唤",\n'
    '   "effect_text": "费用本局 +1。将一张随机比这张卡费用高 1 的其他职业盟友加入手卡，'
    '其费用本局变为 0。",\n'
    '   "changed": false\n'
    '  },\n'
    '  "9267": {\n'
    '   "name": "激励乐章",\n'
    '   "effect_text": "本回合场上所有盟友力量 +4；原本职业不属于自己的盟友改为 +6。",\n'
    '   "changed": false\n'
    '  },\n'
    '  "9268": {\n'
    '   "name": "管风琴",\n'
    '   "effect_text": "攻击时，从卡组将一张随机技能卡加入手卡，该卡本回合费用 -1。'
    '在场时，每使用一张技能卡，对所有敌人造成 3 点伤害。",\n'
    '   "changed": false\n'
    '  }\n'
    ' }\n'
    '}'
)
z_raw = z_raw.replace(z_tail, z_new)
io.open(ZC, "wb").write(z_raw.encode("utf-8"))
zd = json.loads(z_raw)
assert zd["cards"]["9267"]["name"] == "激励乐章"
print("zh_canonical OK，条数", len(zd["cards"]))

# ── cards_en / cards_ja：整篇 json 往返字节一致 → 直接重写 ──
EN_NEW = {
    "9267": {
        "name": "Rousing Anthem",
        "effect_text": "This turn, all Allies on the field gain +4 Power. "
                       "Allies whose original class is not yours gain +6 instead.",
    },
    "9268": {
        "name": "Pipe Organ",
        "effect_text": "When it attacks, add a random Skill card from your deck to your Hand; "
                       "its cost is -1 this turn. While in play, whenever you use a Skill card, "
                       "deal 3 damage to all enemies.",
    },
}
JA_NEW = {
    "9267": {
        "name": "激励の楽章",
        "effect_text": "このターン、場の味方すべての力 +4。本来のクラスが自分と異なる味方は +6 になる。",
    },
    "9268": {
        "name": "パイプオルガン",
        "effect_text": "攻撃時、山札からスキルカードをランダムで1枚手札に加え、"
                       "このターンの費用を -1 する。場にある間、スキルカードを使うたび、"
                       "敵すべてに 3 ダメージを与える。",
    },
}

for path, add in (("i18n/cards_en.json", EN_NEW), ("i18n/cards_ja.json", JA_NEW)):
    raw_txt = io.open(path, "rb").read().decode("utf-8")
    d = json.loads(raw_txt)
    assert json.dumps(d, ensure_ascii=False, indent=1) + "\n" == raw_txt, path + " 往返不一致"
    for k, v in add.items():
        assert k not in d["cards"]
        d["cards"][k] = v
    d["count"] = len(d["cards"])
    out = json.dumps(d, ensure_ascii=False, indent=1) + "\n"
    io.open(path, "wb").write(out.encode("utf-8"))
    print(path, "OK → count", d["count"])
