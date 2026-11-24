# -*- coding: utf-8 -*-
"""R805：run_state.gd 加 `roll_legendary_relic()`（事件「诡异洋房」给必定传奇）。保持 LF。"""
import io

P = "E:/work/card_rogue/scripts/run_state.gd"
d = open(P, "rb").read().decode("utf-8")
assert d.count("\r\n") == 0, "run_state.gd 不是纯 LF"

OLD = "static func _drop_settled_batch() -> void:"
assert d.count(OLD) == 1

NEW = (
    'static func roll_legendary_relic(exclude: Array = []) -> int:\n'
    '	## R805：**必定传奇**的一件奖励道具（事件「诡异洋房 · 探索」的报酬之一）。\n'
    '	## 与 `roll_reward_relic()` 的分工：那个按「5% × 层数」摇档位，这个直接锁死传奇池。\n'
    '	## ⚠️ 传奇池空了返回 **-1**，**不回落一般池** —— 悄悄塞一件一般的进去，\n'
    '	##    卡面上承诺的「传奇」就成了假话；调用方要自己决定「池子空了怎么办」。\n'
    '	## ⚠️ 只消耗**一个** randi（不先摇 randf 判档）：档位已经固定，多摇一个随机数\n'
    '	##    只会让同一 seed 下的道具序列凭空错位。\n'
    '	var leg := _reward_pool(RelicData.TIER_LEGENDARY, exclude)\n'
    '	if leg.is_empty():\n'
    '		return -1\n'
    '	return leg[run_rng.randi() % leg.size()]\n'
    '\n'
    '\n'
    + OLD
)

d = d.replace(OLD, NEW)
assert d.count("static func roll_legendary_relic") == 1
io.open(P, "wb").write(d.encode("utf-8"))
print("ok lines=%d  crlf=%d" % (d.count("\n"), d.count("\r\n")))
