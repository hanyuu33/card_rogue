# -*- coding: utf-8 -*-
# R772 黄桃罐头：4 血 → 6 血 + 最大生命 +1，同步 test_engine.gd 相关断言（保持 CRLF）。
import io, sys

P = r"scripts/test_engine.gd"
data = open(P, "rb").read()

def rep(old: str, new: str):
    global data
    ob = old.encode("utf-8")
    nb = new.encode("utf-8")
    n = data.count(ob)
    assert n == 1, "锚点命中 %d 次（期望 1）：%r" % (n, old[:60])
    data = data.replace(ob, nb)

# 1) 注释行
rep(
    "\t# ---- 黄桃罐头（6014）：每次战斗结束回复 4 点生命 ----\r\n",
    "\t# ---- 黄桃罐头（6014）：每次战斗结束回复 6 点生命，且最大生命 +1 ----\r\n",
)

# 2) eng_pc：回血 4→6，并新增「最大生命 +1」断言
rep(
    "\tcheck(eng_pc.battle_end_heal() == 4 and eng_pc.state.hp_self == 14,\r\n"
    "\r\n"
    "\t\t\t\"黄桃罐头：战斗结束回复 4 点生命（10 → %d）\" % eng_pc.state.hp_self)\r\n",
    "\tcheck(eng_pc.battle_end_heal() == 6 and eng_pc.state.hp_self == 16,\r\n"
    "\r\n"
    "\t\t\t\"黄桃罐头：战斗结束回复 6 点生命（10 → %d）\" % eng_pc.state.hp_self)\r\n"
    "\r\n"
    "\tcheck(eng_pc.state.max_hp_self == 21,\r\n"
    "\r\n"
    "\t\t\t\"黄桃罐头：战斗结束最大生命 +1（20 → %d）\" % eng_pc.state.max_hp_self)\r\n",
)

# 3) eng_pc2：满血场景，先抬上限再回复
rep(
    "\tcheck(eng_pc2.state.hp_self == 20, \"黄桃罐头：回复不超过上限（18 + 4 → 20）\")\r\n",
    "\tcheck(eng_pc2.state.hp_self == 21 and eng_pc2.state.max_hp_self == 21,\r\n"
    "\r\n"
    "\t\t\t\"黄桃罐头：先抬上限再回复，满血也吃得进新上限（18 + 6 → 21，上限 20 → 21）\")\r\n",
)

open(P, "wb").write(data)
print("OK: test_engine.gd 已更新（保持 CRLF），共 3 处锚点替换")
