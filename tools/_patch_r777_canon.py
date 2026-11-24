# -*- coding: utf-8 -*-
"""zh_canonical.json：按原文精确插 9269 / 9270（不整篇重排，diff 只多 12 行）。"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "i18n", "zh_canonical.json")
raw = io.open(P, "rb").read().decode("utf-8")
assert '"9269"' not in raw and '"9270"' not in raw

old = (
    '  "9268": {\n'
    '   "name": "管风琴",\n'
    '   "effect_text": "攻击时，从卡组将一张随机技能卡加入手卡，该卡本回合费用 -1。'
    '在场时，每使用一张技能卡，对所有敌人造成 3 点伤害。",\n'
    '   "changed": false\n'
    '  }\n'
    ' }\n'
    '}'
)
new = (
    '  "9268": {\n'
    '   "name": "管风琴",\n'
    '   "effect_text": "攻击时，从卡组将一张随机技能卡加入手卡，该卡本回合费用 -1。'
    '在场时，每使用一张技能卡，对所有敌人造成 3 点伤害。",\n'
    '   "changed": false\n'
    '  },\n'
    '  "9269": {\n'
    '   "name": "彩虹诗",\n'
    '   "effect_text": "随机 3 个不同其他职业，各将一张随机盟友或技能卡加入手卡，'
    '其费用本局 -1。",\n'
    '   "changed": false\n'
    '  },\n'
    '  "9270": {\n'
    '   "name": "疾风乐章",\n'
    '   "effect_text": "所有盟友移动速度 +1；若为其他职业盟友，改为一回合行动两次。",\n'
    '   "changed": false\n'
    '  }\n'
    ' }\n'
    '}'
)
n = raw.count(old)
assert n == 1, "锚点命中 %d 次" % n
raw = raw.replace(old, new)

import json
d = json.loads(raw)
assert d["cards"]["9269"]["name"] == "彩虹诗" and d["cards"]["9270"]["name"] == "疾风乐章"
assert len(d["cards"]) == len(json.loads(old and raw)["cards"])
assert "\r\n" not in raw
io.open(P, "wb").write(raw.encode("utf-8"))
print("[ok] zh_canonical 插入 9269 / 9270（%d 条）" % len(d["cards"]))
