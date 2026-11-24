# -*- coding: utf-8 -*-
"""R836e：修 smoke 断言里的类型错误 —— `self_relics` 是 Array[int]，
传无类型字面量 `[6084]` 会 `Invalid assignment` 并**静默跳过后面所有断言**
（不报 SMOKE FAIL，只打一行 SCRIPT ERROR，很容易看漏）。
"""
ROOT = "E:/work/card_rogue/"
TE = "scripts/test_smoke.gd"
b = open(ROOT + TE, "rb").read()

old = (
    "\tRunState.relics = [6084]\r\n"
    "\tRunState.spent_relics = []\r\n"
    "\tscene.engine.self_relics = [6084]\r\n"
).encode("utf-8")
new = (
    "\tvar clk_ids: Array[int] = [6084]      # ⚠️ 必须是 Array[int]：self_relics 有类型\r\n"
    "\tRunState.relics = clk_ids\r\n"
    "\tRunState.spent_relics = []\r\n"
    "\tscene.engine.self_relics = clk_ids\r\n"
).encode("utf-8")
assert b.count(old) == 1, b.count(old)
b = b.replace(old, new)
open(ROOT + TE, "wb").write(b)
print("smoke 类型修正完成")
