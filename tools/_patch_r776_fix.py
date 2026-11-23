# -*- coding: utf-8 -*-
"""R776 小修：技能分支常量改名 INSPIRE_ID → ANTHEM_ID（8077 激发已占用该名）。"""
import io

P = "scripts/game_engine.gd"
s = io.open(P, "rb").read().decode("utf-8")
old = "\t\tINSPIRE_ID:\r\n"
new = "\t\tANTHEM_ID:\r\n"
n = s.count(old)
print("命中", n)
assert n == 1
io.open(P, "wb").write(s.replace(old, new).encode("utf-8"))
print("OK")
