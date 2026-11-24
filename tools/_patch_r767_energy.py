# -*- coding: utf-8 -*-
"""R767：把 `state.energy = FieldState.ENERGY_PER_TURN` 换成 RunState.energy_per_turn()。
game_engine.gd 是 CRLF，必须按字节改（Edit 工具会整篇转 LF）。"""
import sys

P = "scripts/game_engine.gd"
b = open(P, "rb").read()
assert b.count(b"\r\n") > 0 and b.count(b"\r\n") == b.count(b"\n"), "期望纯 CRLF"

OLD2 = b"\t\tstate.energy = FieldState.ENERGY_PER_TURN\r\n"
OLD1 = b"\tstate.energy = FieldState.ENERGY_PER_TURN\r\n"
NEW2 = ("\t\t# R767：我方每回合费用统一走 RunState.energy_per_turn()\n"
        "\t\t# （每日修饰的「灵光 +1 / 滞涩 −1」就叠在它里面，标准局等于常量）\n"
        "\t\tstate.energy = RunState.energy_per_turn()\n").encode("utf-8")
NEW1 = ("\t# R767：同上（开局那一次）\n"
        "\tstate.energy = RunState.energy_per_turn()\n").encode("utf-8")

c2 = b.count(OLD2)
c1 = b.count(OLD1)
print("两 tab:", c2, " 单 tab:", c1)
if c2 != 1 or c1 != 2:
    print("计数不符，放弃（单 tab 模式会同时命中 2tab 行，故应为 2 = 1+1）")
    sys.exit(1)

b = b.replace(OLD2, NEW2.replace(b"\n", b"\r\n"), 1)
b = b.replace(OLD1, NEW1.replace(b"\n", b"\r\n"), 1)
open(P, "wb").write(b)

left = open(P, "rb").read()
print("剩余 FIELD 引用:", left.count(b"state.energy = FieldState.ENERGY_PER_TURN"))
print("CRLF ok:", left.count(b"\r\n") == left.count(b"\n"))
print("新调用点:", left.count(b"RunState.energy_per_turn()"))
