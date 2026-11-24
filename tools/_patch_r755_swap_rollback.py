# -*- coding: utf-8 -*-
"""R755：`_swap_tool()` 失败回滚 —— 领不进来就把旧工具放回原槽，别让玩家白丢一件。"""
import io

P = "E:/work/card_rogue/scripts/reward_panel.gd"
raw = io.open(P, "r", encoding="utf-8", newline="").read()

OLD = """func _swap_tool(slot: int) -> void:
	## R695：丢掉旧槽 → 立刻把这条工具领进来（`claim_pending_reward` 会填第一个空槽）。
	## ⚠️ 顺序不能反：先领后丢的话，满栏时 `gain_trap()` 直接失败，玩家白丢一个工具。
	var old := RunState.discard_trap(slot)
	if old <= 0:
		return
	if RunState.claim_pending_reward(_sel):
		_back_to_list()
"""

NEW = """func _swap_tool(slot: int) -> void:
	## R695：丢掉旧槽 → 立刻把这条工具领进来（`claim_pending_reward` 会填第一个空槽）。
	## ⚠️ 顺序不能反：先领后丢的话，满栏时 `gain_trap()` 直接失败，玩家白丢一个工具。
	## R755：**失败要回滚** —— 队列可能在中途被别处改过（读档 / 剧情奖励），
	## 领不进来时把旧工具放回原槽，不能让人白丢一件。
	var old := RunState.discard_trap(slot)
	if old <= 0:
		return
	if RunState.claim_pending_reward(_sel):
		_back_to_list()
		return
	RunState.traps[slot] = old
"""

assert raw.count(OLD) == 1, raw.count(OLD)
raw = raw.replace(OLD, NEW)
io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("ok")
