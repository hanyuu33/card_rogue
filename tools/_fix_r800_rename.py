#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R800：把音符的结算函数 `_note` 改名 `_note_spell`。

理由：同文件里已有 `_note_card_played` / `_note_card_changed` / `_note_unit_entered`
（都是「记录/通知」语义），`_note` 夹在中间极易被后来的人读错。
"""
P = "scripts/game_engine.gd"
d = open(P, "rb").read().decode("utf-8")

pairs = [
    ("func _note(side: String) -> String:\r\n",
     "func _note_spell(side: String) -> String:\r\n"),
    ("\t\tNOTE_ID:\r\n\t\t\treturn _note(side)\r\n",
     "\t\tNOTE_ID:\r\n\t\t\treturn _note_spell(side)\r\n"),
]
for old, new in pairs:
    assert d.count(old) == 1, "count=%d for %r" % (d.count(old), old[:40])
    d = d.replace(old, new)

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
assert b.count(b"\n") == b.count(b"\r\n"), "行尾被改成 LF 了"
print("rename ok: CRLF %d" % b.count(b"\r\n"))
