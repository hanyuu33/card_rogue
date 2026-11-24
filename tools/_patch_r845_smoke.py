# -*- coding: utf-8 -*-
"""R845：负重减轻 从史诗(2)降为稀有(1) → smoke 卡面断言同步。
test_smoke.gd 是 CRLF，必须按字节改写，不能整篇转 LF。"""
import io, sys

P = "scripts/test_smoke.gd"
old = "if lt == null or lt.cost != 0 or lt.rarity != 2:\r\n\t\t_smoke_fail(\"负重减轻：卡面应是 0 费史诗技能\")\r\n"
new = "if lt == null or lt.cost != 0 or lt.rarity != 1:\r\n\t\t_smoke_fail(\"负重减轻：卡面应是 0 费稀有技能\")\r\n"

with io.open(P, "r", encoding="utf-8", newline="") as f:
    s = f.read()

n = s.count(old)
assert n == 1, "锚点命中 %d 次，应为 1" % n
s = s.replace(old, new)

with io.open(P, "w", encoding="utf-8", newline="") as f:
    f.write(s)

# 复核
with io.open(P, "rb") as f:
    raw = f.read()
print("CRLF 行数:", raw.count(b"\r\n"), " 裸 LF 行数:", raw.count(b"\n") - raw.count(b"\r\n"))
print("剩余旧断言:", raw.count("0 费史诗技能".encode("utf-8")))
print("新断言:", raw.count("0 费稀有技能".encode("utf-8")))
