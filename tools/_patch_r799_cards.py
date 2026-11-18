# -*- coding: utf-8 -*-
"""R799：cards.json 追加 9272 连斩 / 9273 炮火就位。
按原风格（4 空格对象、6 空格键）插行，不做 json.dumps 整篇重写。
"""
P = "cards.json"

CARD_LINK = """    {
      "id": 9272,
      "name": "连斩",
      "kind": "技能",
      "cost": 0,
      "power": 0,
      "health": 0,
      "attack_range": 0,
      "move_speed": 0,
      "rarity": 1,
      "group": "player",
      "class": "暗影刺客",
      "traits": [],
      "effect_text": "X 费，打出时消耗全部费用。对一个目标造成 7 点伤害，重复 X 次；目标中途倒下则剩余次数作废。没有费用时也能使用（此时 X 为 0）。",
      "target_mode": "unit",
      "x_cost": true,
      "color": "物理",
      "image": ""
    }"""

CARD_BARRAGE = """    {
      "id": 9273,
      "name": "炮火就位",
      "kind": "技能",
      "cost": 0,
      "power": 0,
      "health": 0,
      "attack_range": 0,
      "move_speed": 0,
      "rarity": 2,
      "group": "player",
      "class": "机械之心",
      "traits": [],
      "effect_text": "X 费，打出时消耗全部费用。将 X 张「聚能炮击」加入抽牌库，对所有敌人造成 3 点伤害，重复 X 次。没有费用时也能使用（此时 X 为 0）。",
      "target_mode": "none",
      "x_cost": true,
      "color": "火",
      "image": ""
    }"""

# 锚点 = 最后一张卡（9271 巧克力工厂）的尾部 + 数组收尾，作为唯一性保证
ANCHOR = ('      "effect_text": "回合开始时，获得 1 费用并抽一张卡。",\r\n'
          '      "target_mode": "none",\r\n'
          '      "color": "火",\r\n'
          '      "image": ""\r\n'
          '    }\r\n'
          '  ]\r\n'
          '}\r\n')

NEW = ('      "effect_text": "回合开始时，获得 1 费用并抽一张卡。",\r\n'
       '      "target_mode": "none",\r\n'
       '      "color": "火",\r\n'
       '      "image": ""\r\n'
       '    },\r\n'
       + CARD_LINK.replace("\n", "\r\n") + ',\r\n'
       + CARD_BARRAGE.replace("\n", "\r\n") + '\r\n'
       '  ]\r\n'
       '}\r\n')

raw = open(P, "rb").read().decode("utf-8")
assert raw.count(ANCHOR) == 1, "anchor count=%d" % raw.count(ANCHOR)
out = raw.replace(ANCHOR, NEW)
open(P, "wb").write(out.encode("utf-8"))

import json
d = json.load(open(P, encoding="utf-8"))["cards"]
print("cards:", len(d), "max id:", max(c["id"] for c in d))
for c in d:
    if c["id"] in (9272, 9273):
        print(" ", c["id"], c["name"], c["kind"], "cost", c["cost"],
              "rarity", c["rarity"], "x_cost", c.get("x_cost"), c["target_mode"])
b = open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))
