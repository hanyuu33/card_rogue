#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R800：西语校验器里写死的卡数 334 → 336。"""
P = "i18n/validate_spanish.py"
d = open(P, "rb").read().decode("utf-8")

pairs = [
    ("# 卡牌：334 个稳定 ID（R799 加连斩 9272 / 炮火就位 9273；",
     "# 卡牌：336 个稳定 ID（R800 加余音 9274 / 音符 9275；R799 加连斩 9272 / 炮火就位 9273；"),
    ('check(len(CARDS_ES["cards"]) == 334, "cards 共 334 张")',
     'check(len(CARDS_ES["cards"]) == 336, "cards 共 336 张")'),
]
for old, new in pairs:
    assert d.count(old) == 1, "count=%d for %r" % (d.count(old), old[:40])
    d = d.replace(old, new)

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
assert b.count(b"\r\n") == 0, "该文件应为纯 LF"
print("validate_spanish ok (LF %d)" % (b.count(b"\n")))
