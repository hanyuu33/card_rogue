# -*- coding: utf-8 -*-
# R772 洞窟绳：逃跑返还 1 块巧克力。在 test_engine.gd 的洞窟绳灰掉测试之后追加断言（保持 CRLF）。
import io, sys

P = r"scripts/test_engine.gd"
data = open(P, "rb").read()

anchor = (
    "\t\t\"R367 绳子：灰掉之后 `can_use_cave_rope` 为 false（不能逃第二次）\")\r\n"
).encode("utf-8")

n = data.count(anchor)
assert n == 1, "锚点命中 %d 次（期望 1）" % n

insert = (
    "\r\n"
    "\t# ---- R772 洞窟绳：逃跑退还 1 块巧克力（第三层不返还）----\r\n"
    "\r\n"
    "\tvar r772_choco_bak: int = RunState.chocolate\r\n"
    "\r\n"
    "\tvar r772_layer_bak: int = RunState.current_layer\r\n"
    "\r\n"
    "\tvar r772_boss_bak: bool = RunState.boss_pending\r\n"
    "\r\n"
    "\tRunState.current_layer = GameLayers.LAYER_DEFAULT\r\n"
    "\r\n"
    "\tRunState.chocolate = 5\r\n"
    "\r\n"
    "\tRunState.cave_rope_refund()\r\n"
    "\r\n"
    "\tcheck(RunState.chocolate == 6,\r\n"
    "\r\n"
    "\t\t\"R772 洞窟绳：逃跑返还 1 块巧克力（5 → 6）\")\r\n"
    "\r\n"
    "\tRunState.chocolate = 0\r\n"
    "\r\n"
    "\tRunState.boss_pending = true\r\n"
    "\r\n"
    "\tRunState.cave_rope_refund()\r\n"
    "\r\n"
    "\tcheck(RunState.chocolate == 1 and not RunState.boss_pending,\r\n"
    "\r\n"
    "\t\t\"R772 洞窟绳：最后一格逃了返还 1 块，并撤销 boss_pending\")\r\n"
    "\r\n"
    "\tRunState.current_layer = GameLayers.LAYER_THREE\r\n"
    "\r\n"
    "\tRunState.chocolate = 0\r\n"
    "\r\n"
    "\tRunState.cave_rope_refund()\r\n"
    "\r\n"
    "\tcheck(RunState.chocolate == 0,\r\n"
    "\r\n"
    "\t\t\"R772 洞窟绳：第三层不收步数，逃跑不返还巧克力\")\r\n"
    "\r\n"
    "\tRunState.chocolate = r772_choco_bak\r\n"
    "\r\n"
    "\tRunState.current_layer = r772_layer_bak\r\n"
    "\r\n"
    "\tRunState.boss_pending = r772_boss_bak\r\n"
).encode("utf-8")

data = data.replace(anchor, anchor + insert)
open(P, "wb").write(data)
print("OK: test_engine.gd 已追加 R772 洞窟绳返还巧克力断言（保持 CRLF）")
