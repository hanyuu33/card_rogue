#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R800：新增吟游诗人稀有技能「余音」9274（X 费）与内部卡「音符」9275（0 费 · 次元）。

只按原风格插行，不整篇 json.dumps（R794 的教训：会产出 100+ 行格式化噪音）。
"""
import json
import io

P = "cards.json"
raw = open(P, "rb").read()
d = raw.decode("utf-8")

anchor = '      "image": ""\r\n    }\r\n  ]\r\n}\r\n'
assert d.count(anchor) == 1, d.count(anchor)

NEW = (
    '      "image": ""\r\n'
    '    },\r\n'
    '    {\r\n'
    '      "id": 9274,\r\n'
    '      "name": "余音",\r\n'
    '      "kind": "技能",\r\n'
    '      "cost": 0,\r\n'
    '      "power": 0,\r\n'
    '      "health": 0,\r\n'
    '      "attack_range": 0,\r\n'
    '      "move_speed": 0,\r\n'
    '      "rarity": 1,\r\n'
    '      "group": "player",\r\n'
    '      "class": "吟游诗人",\r\n'
    '      "traits": [],\r\n'
    '      "affixes": [],\r\n'
    '      "effect_text": "X 费，打出时消耗全部费用。将 X 张「音符」加入抽牌库。'
    '没有费用时也能使用（此时 X 为 0）。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "x_cost": true,\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    },\r\n'
    '    {\r\n'
    '      "id": 9275,\r\n'
    '      "name": "音符",\r\n'
    '      "kind": "技能",\r\n'
    '      "cost": 0,\r\n'
    '      "power": 0,\r\n'
    '      "health": 0,\r\n'
    '      "attack_range": 0,\r\n'
    '      "move_speed": 0,\r\n'
    '      "rarity": 0,\r\n'
    '      "group": "player",\r\n'
    '      "class": "吟游诗人",\r\n'
    '      "traits": [],\r\n'
    '      "affixes": [\r\n'
    '        "次元"\r\n'
    '      ],\r\n'
    '      "effect_text": "获得 2 点费用，抽 2 张卡。",\r\n'
    '      "target_mode": "none",\r\n'
    '      "event_only": true,\r\n'
    '      "color": "水风",\r\n'
    '      "image": ""\r\n'
    '    }\r\n'
    '  ]\r\n'
    '}\r\n'
)

out = d.replace(anchor, NEW)
open(P, "wb").write(out.encode("utf-8"))

# 校验：JSON 可解析 + 两张新卡字段正确 + 行尾仍是纯 CRLF
chk = json.load(open(P, encoding="utf-8"))["cards"]
assert len(chk) == 336, len(chk)
by_id = {c["id"]: c for c in chk}
enc, note = by_id[9274], by_id[9275]
assert enc["x_cost"] is True and enc["class"] == "吟游诗人" and enc["rarity"] == 1
assert note["affixes"] == ["次元"] and note["event_only"] is True and note["cost"] == 0
assert "affixes" not in enc or enc["affixes"] == []

b = open(P, "rb").read()
assert b.count(b"\n") == b.count(b"\r\n"), "行尾被改成 LF 了"
print("cards.json ok: 总 %d 张，CRLF %d" % (len(chk), b.count(b"\r\n")))
