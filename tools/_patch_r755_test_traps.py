# -*- coding: utf-8 -*-
"""R755：test_traps 补 ⑫ 段 —— 满栏领工具的「换下一件」子面板（换下 / 取消 / 判据唯一口）。"""
import io

P = "E:/work/card_rogue/scripts/test_traps.gd"

OLD = """	RunState.traps = [-1, -1, -1]
	RunState.tool_drop_pledge = 0
	print("TRAPS === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
"""

NEW = """	# ---- ⑫ R755：满栏领工具 → 「换下一件」子面板（换下 / 取消）----
	# ① 判据唯一口 `_tool_swap_active()`：只有「待领 + 工具 + 满栏」才走换装条。
	#    只调纯逻辑判据，不把面板挂进树（会弹窗）。
	var swp: Control = RewardPanel.new()
	RunState.traps = [7001, 7002, 7004]
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7005)
	var swp_e: Dictionary = RunState.pending_rewards[0]
	check(swp._tool_swap_active(swp_e), "R755：满栏 + 待领工具 → 走换装条")
	check(not swp._tool_swap_active({"kind": "relic", "id": 6001,
			"state": RunState.REWARD_PENDING}),
			"R755：道具条目不走换装条（它不是工具）")
	check(not swp._tool_swap_active({"kind": "tool", "id": 7005,
			"state": RunState.REWARD_CLAIMED}),
			"R755：已经领过的条目不再换")
	RunState.traps = [7001, -1, -1]
	check(not swp._tool_swap_active(swp_e), "R755：还有空位时不走换装条（直接领）")
	swp.free()
	# ② 换下：先丢旧槽再领 —— 顺序反了会白丢一件（满栏时 `gain_trap()` 直接失败）。
	RunState.traps = [7001, 7002, 7004]
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7005)
	check(RunState.discard_trap(0) == 7001, "R755：换下 = 丢掉点中的那一格（返回被丢的 id）")
	check(RunState.claim_pending_reward(0), "R755：换下后新工具当场领进来")
	check(RunState.trap_at(0) == 7005 and RunState.trap_free_slots() == 0,
			"R755：新工具补进空出的那一格，栏位仍然 3/3")
	# ③ 取消：只回列表 —— 工具栏与待领队列一字不动。
	RunState.traps = [7001, 7002, 7004]
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7005)
	check(RunState.trap_at(0) == 7001 and RunState.trap_at(2) == 7004
			and RunState.pending_rewards.size() == 1
			and str(RunState.pending_rewards[0].get("state", "")) == RunState.REWARD_PENDING,
			"R755：取消只回列表，工具栏与待领队列都不变（条目还在）")
	# ④ 源码守卫：界面接线不许被后续改动抹掉。
	var rp755 := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
	check(rp755.find("_tool_swap_cancel_rect()") >= 0
			and rp755.find('GameI18n.ui("reward", "REWARD_TOOL_SWAP_CANCEL"') >= 0,
			"R755：换装条带「取消」按钮（几何口 + 文案键）")
	var ci755 := rp755.find("_tool_swap_cancel_rect().has_point(pos)")
	check(ci755 >= 0 and rp755.substr(ci755, 200).find("_back_to_list()") >= 0,
			"R755：点「取消」= 回列表（不丢条目）")
	check(rp755.find("if not tool_full:") >= 0,
			"R755：满栏时不再画右下角「领取 / 工具栏已满」按钮（改由换装条说明）")
	check(rp755.find('UiAssets.small_icon("ui_tool_swap"') >= 0,
			"R755：换装条标题用金色交换图标（assets/ui/ui_tool_swap.png）")
	check(FileAccess.file_exists("res://assets/ui/ui_tool_swap.png")
			and FileAccess.file_exists("res://assets/ui/trap_icon_7012.png"),
			"R755：两张新素材入库（交换图标 + 石头图标）")

	RunState.traps = [-1, -1, -1]
	RunState.tool_drop_pledge = 0
	RunState.pending_rewards = []
	print("TRAPS === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
"""

raw = io.open(P, "r", encoding="utf-8", newline="").read()
assert raw.count(OLD) == 1, raw.count(OLD)
raw = raw.replace(OLD, NEW)
io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("ok")
