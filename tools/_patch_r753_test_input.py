# -*- coding: utf-8 -*-
"""R753：test_trap_input.gd 增补「使用/丢弃」按钮栏与石头拖放（LF 文件）。"""
p = 'scripts/test_trap_input.gd'
txt = open(p, 'rb').read().decode('utf-8')
assert txt.count('\r\n') == 0

old = '''	# ---- ⑨ 底图合一：两处共用一张，停用版不在 assets/ui ----
'''
assert txt.count(old) == 1

new = '''	# ---- ⑧d R753：单击任意工具 → 弹出「使用 / 丢弃」按钮栏（同一个栏）----
	# 用户口径：「不管是那种类型的道具，都要有单击后弹出丢弃按钮。
	#            使用型两个按钮用同一个栏」。
	RunState.traps = [-1, -1, -1]
	RunState.gain_trap(7005)      # 使用型（小血瓶）
	_sc._tool_use_arm = -1
	_sc._tool_use_until = 0
	_sc.engine.state.max_hp_self = 20
	_sc.engine.state.hp_self = 10
	_feed(_mb(s0, true))
	_feed(_mb(s0, false))
	check(_sc._tool_use_arm == 0, "按钮栏：单击有货的槽就弹出来（不只使用型）")
	var lay_use: Dictionary = _sc._tool_bar_layout(0)
	var use_r: Rect2 = lay_use["use"]
	var drop_r: Rect2 = lay_use["drop"]
	check(use_r.size.x > 0.5 and drop_r.size.x > 0.5 and not use_r.intersects(drop_r),
			"按钮栏：使用型的「使用」「丢弃」并排在同一栏里（互不重叠）")
	check(use_r.get_center().x < drop_r.get_center().x, "按钮栏：左「使用」右「丢弃」")
	# 点「丢弃」→ 当场丢掉：栏本身就是第二段动作，不再要求点两下。
	_feed(_mb(drop_r.get_center(), true))
	check(RunState.trap_at(0) == -1 and _sc._tool_use_arm == -1,
			"按钮栏：点「丢弃」→ 工具丢掉、栏自己收起")
	check(_sc.engine.state.hp_self == 10, "按钮栏：丢弃不触发工具效果")

	# 同一栏里的「使用」（双击那条路已经在 ⑧b 验过）。
	RunState.traps = [-1, -1, -1]
	RunState.gain_trap(7005)
	_sc.engine.state.hp_self = 10
	_feed(_mb(s0, true))
	_feed(_mb(s0, false))
	lay_use = _sc._tool_bar_layout(0)
	use_r = lay_use["use"]
	_feed(_mb(use_r.get_center(), true))
	check(RunState.trap_at(0) == -1 and _sc.engine.state.hp_self == 14,
			"按钮栏：点「使用」→ 当场结算并摘槽")
	check(_sc._tool_use_arm == -1, "按钮栏：用掉之后栏自己收起")

	# 放置型（炼金炸弹）：同一栏里只有「丢弃」，没有「使用」，而且丢掉不会顺手埋下去。
	RunState.traps = [-1, -1, -1]
	RunState.gain_trap(7001)
	_sc.engine.state.trap_fields.clear()
	_feed(_mb(s0, true))
	_feed(_mb(s0, false))
	var lay_bomb: Dictionary = _sc._tool_bar_layout(0)
	check(_sc._tool_use_arm == 0, "按钮栏：放置型工具单击同样弹出栏")
	check((lay_bomb["use"] as Rect2).size.x < 0.5
			and (lay_bomb["drop"] as Rect2).size.x > 0.5,
			"按钮栏：放置型只给「丢弃」（没有使用）")
	_feed(_mb((lay_bomb["drop"] as Rect2).get_center(), true))
	check(RunState.trap_at(0) == -1, "按钮栏：放置型也能一键丢掉")
	check(_sc.engine.state.trap_fields.is_empty(), "按钮栏：丢弃放置型不会顺手把它埋下去")

	# ---- ⑧e R753：石头（7012）要拖到**敌方单位**身上才砸得下去 ----
	RunState.traps = [-1, -1, -1]
	RunState.gain_trap(7012)
	_sc._tool_use_arm = -1
	_sc._tool_use_until = 0
	_sc.engine.state.trap_fields.clear()
	var sk_card := CardData.new()
	sk_card.id = 9101
	sk_card.card_name = "石头探针"
	sk_card.kind = "盟友"
	sk_card.health = 40
	sk_card.power = 0
	sk_card.attack_range = 1
	sk_card.move_speed = 1
	var sk_foe := Placement.new()
	sk_foe.card = sk_card
	sk_foe.owner = GameEngine.SIDE_OPPONENT
	sk_foe.health = 40
	var sk_cell := Vector2i(4, 0)
	_sc.engine.state.board[sk_cell] = sk_foe
	_feed(_mb(_slot(0), true))
	_arm_drag(_slot(0))
	check(_sc._trap_drag_slot == 0 and _sc._trap_drag_cells.has(sk_cell),
			"石头：开始拖时，高亮的是敌方单位所在的格子（不是空格）")
	_feed(_mb(_sc._cell_center(sk_cell), false))
	check(sk_foe.health == 25, "石头：砸中敌方单位 → 15 点伤害（40 → 25）")
	check(RunState.trap_at(0) == -1, "石头：砸完就从工具栏摘掉")
	check(_sc.engine.state.trap_fields.is_empty(), "石头：不会顺手埋成陷阱")
	_sc.engine.state.board.erase(sk_cell)

	# ---- ⑨ 底图合一：两处共用一张，停用版不在 assets/ui ----
'''

txt = txt.replace(old, new, 1)
open(p, 'wb').write(txt.encode('utf-8'))
print('lf', txt.count('\n'), 'crlf', txt.count('\r\n'))
