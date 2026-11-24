# -*- coding: utf-8 -*-
"""R805：cards.json 加「诅咒娃娃」9276（诡异洋房事件的代价）。保持 CRLF + 原缩进。"""
import io

P = "E:/work/card_rogue/cards.json"
d = open(P, "rb").read().decode("utf-8")
assert "\r\n" in d

# 锚点：9275 的收尾（"image": "" 后闭合对象）+ 数组结尾
ANCHOR = ('      "event_only": true,\r\n'
          '      "color": "水风",\r\n'
          '      "image": ""\r\n'
          '    }\r\n'
          '  ]\r\n'
          '}\r\n')
assert d.count(ANCHOR) == 1, "锚点命中 %d 次" % d.count(ANCHOR)

BLOCK = (
    '    {\r\n'
    '      "id": 9276,\r\n'
    '      "name": "诅咒娃娃",\r\n'
    '      "kind": "诅咒",\r\n'
    '      "cost": 0,\r\n'
    '      "power": 0,\r\n'
    '      "health": 0,\r\n'
    '      "attack_range": 0,\r\n'
    '      "move_speed": 0,\r\n'
    '      "rarity": 6,\r\n'
    '      "group": "player",\r\n'
    '      "class": "",\r\n'
    '      "traits": [\r\n'
    '        "诅咒娃娃"\r\n'
    '      ],\r\n'
    '      "affixes": [\r\n'
    '        "保存"\r\n'
    '      ],\r\n'
    '      "effect_text": "不能打出。回合结束时，你受到 3 点伤害。回合开始时，'
    '若这张卡在弃牌区，这张卡从弃牌区加入你的手牌。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "color": "暗影",\r\n'
    '      "image": "",\r\n'
    '      "unplayable": true\r\n'
    '    }\r\n'
)

# 把 9275 的收尾改成 "}," 然后接新块，再接数组结尾
NEW = ('      "event_only": true,\r\n'
       '      "color": "水风",\r\n'
       '      "image": ""\r\n'
       '    },\r\n'
       + BLOCK +
       '  ]\r\n'
       '}\r\n')

d = d.replace(ANCHOR, NEW)
assert d.count('"id": 9276') == 1
io.open(P, "wb").write(d.encode("utf-8"))

import json
j = json.loads(open(P, encoding="utf-8").read())
cs = j["cards"]
print("ok cards=%d  last id=%d  crlf=%d" % (len(cs), max(int(c["id"]) for c in cs),
                                            open(P, "rb").read().count(b"\r\n")))
print(json.dumps([c for c in cs if int(c["id"]) == 9276][0], ensure_ascii=False, indent=1))
