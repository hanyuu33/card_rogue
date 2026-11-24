# -*- coding: utf-8 -*-
"""R753：battle_scene.gd 六处改动（工具按钮栏 + 石头落点）。
CRLF 文件，一律二进制读写，改完复核行尾。
"""
p = 'scripts/battle_scene.gd'
txt = open(p, 'rb').read().decode('utf-8')
assert txt.count('\r\n') > 19000, 'expect CRLF'


def rep(old, new):
    global txt
    old_c = old.replace('\n', '\r\n')
    new_c = new.replace('\n', '\r\n')
    c = txt.count(old_c)
    assert c == 1, (c, old_c[:70])
    txt = txt.replace(old_c, new_c, 1)


# ---- A：常量 ----
rep('''const TOOL_USE_ARM_MS := 2600
''', '''const TOOL_USE_ARM_MS := 2600
## R753（用户口径「不管是哪种类型的道具，都要有单击后弹出丢弃按钮。使用型两个按钮用同一个栏」）：
## 单击任意有货的槽 → 在槽**左侧**弹出一个小按钮栏。使用型 = 「使用」+「丢弃」两格；
## 其余（放置型 / 直接伤害型）= 同一栏里一格更宽的「丢弃」。
## 位置算法与命中判定共用 `_tool_bar_layout()` 一份几何 —— 画在一处、判在另一处迟早错位。
const TOOL_BAR_BTN_W := 52.0
const TOOL_BAR_BTN_H := 32.0
const TOOL_BAR_GAP := 6.0
const TOOL_BAR_PAD := 5.0
const TOOL_BAR_OFFSET := 10.0     ## 按钮栏右缘与槽左缘的间距
''')

# ---- B：按下时先判按钮栏 ----
rep('''			var ts := _trap_slot_at(event.position)
			# R695：槽角上的「×」优先 —— 它压在槽里，先判它才能点到丢弃。
''', '''			var ts := _trap_slot_at(event.position)
			# R753：按钮栏（单击任意有货的槽弹出）优先级最高 —— 它画在槽外侧、压着棋盘，
			# 所以必须在「是不是点在槽里」之前判。
			if _tool_use_arm >= 0 and RunState.trap_at(_tool_use_arm) > 0 \\
					and Time.get_ticks_msec() <= _tool_use_until:
				var bs := _tool_use_arm
				var lay := _tool_bar_layout(bs)
				var use_r: Rect2 = lay["use"]
				var drop_r: Rect2 = lay["drop"]
				if use_r.size.x > 0.5 and use_r.has_point(event.position):
					var tud: TrapData = TrapRepo.load_json().get_trap(RunState.trap_at(bs))
					_tool_use_arm = -1
					_tool_use_until = 0
					_trap_press_slot = -1
					_press_idx = -1
					_grid_drag_arm = false
					_grid_dragging = false
					_info_drag_arm = false
					_info_dragging = false
					if tud != null and tud.is_usable():
						_use_tool_slot(bs, tud)
					queue_redraw()
					return
				if drop_r.has_point(event.position):
					_trap_press_slot = -1
					_press_idx = -1
					_grid_drag_arm = false
					_grid_dragging = false
					_info_drag_arm = false
					_info_dragging = false
					_discard_tool_now(bs)
					_tool_use_arm = -1
					_tool_use_until = 0
					return
			# R695：槽角上的「×」优先 —— 它压在槽里，先判它才能点到丢弃。
''')

# ---- C：松手轻点 → 所有工具都弹栏 ----
rep('''				var tid := RunState.trap_at(_trap_press_slot)
				var td: TrapData = TrapRepo.load_json().get_trap(tid)
				if td != null and td.is_usable():
					_tool_use_arm = _trap_press_slot
					_tool_use_until = Time.get_ticks_msec() + TOOL_USE_ARM_MS
					_say("「%s」：再点一下即使用 —— %s" % [td.trap_name, td.desc])
				elif td != null:
					_say("「%s」：%s" % [td.trap_name, td.desc])
''', '''				var tid := RunState.trap_at(_trap_press_slot)
				var td: TrapData = TrapRepo.load_json().get_trap(tid)
				# R753：**所有**工具点一下都弹按钮栏（不只使用型）——
				# 「丢弃」从此不需要去够右上角那个小 ×。
				if td != null:
					_tool_use_arm = _trap_press_slot
					_tool_use_until = Time.get_ticks_msec() + TOOL_USE_ARM_MS
					if td.is_usable():
						_say("「%s」：点「使用」或再点一下即使用 —— %s" % [td.trap_name, td.desc])
					else:
						_say("「%s」：%s" % [td.trap_name, td.desc])
''')

# ---- D：拖放起点改成落点唯一口 ----
rep('''	var t0: TrapData = TrapRepo.load_json().get_trap(RunState.trap_at(slot))
	if t0 != null and t0.is_usable():
		# R690：使用型工具（小血瓶 / 法力药剂）不需要落点 → 拒绝进入拖放。
		# 松手那一下会把「拖」转成上膛提示（R752：点两下才结算，见 `_tool_use_arm`）。
		_trap_press_slot = -1
		_say("「%s」点两下就能用，不用拖" % t0.trap_name)
		return
''', '''	var t0: TrapData = TrapRepo.load_json().get_trap(RunState.trap_at(slot))
	if t0 != null and t0.is_usable():
		# R690：使用型工具（小血瓶 / 法力药剂）不需要落点 → 拒绝进入拖放。
		# 松手那一下会把「拖」转成按钮栏（R752/R753：点「使用」才结算，见 `_tool_use_arm`）。
		_trap_press_slot = -1
		_say("「%s」点「使用」就能用，不用拖" % t0.trap_name)
		return
''')

rep('''	_trap_drag_cells = engine.trap_legal_cells()
	if _trap_drag_cells.is_empty():
		_say("没有可以放置工具的空格")
''', '''	# R753：落点候选的唯一口 —— 石头（直接伤害型）要的是**敌方单位格**，
	# 放置型要的是**空格**，两种都在 `GameEngine.trap_drop_cells()` 里分。
	_trap_drag_cells = engine.trap_drop_cells(RunState.trap_at(slot))
	if _trap_drag_cells.is_empty():
		if t0 != null and t0.direct_damage > 0:
			_say("场上没有可以砸的敌人")
		else:
			_say("没有可以放置工具的空格")
''')

# ---- E：松手结算分两支 ----
rep('''	var c2 := Vector2i(int(cell.x), int(cell.y))
	if not engine.place_trap(id, c2):
		_say("这格已经不能放置工具了")
		return
	RunState.consume_trap(slot)   # 放置那一刻才从栏位移除（R663 口径）
	var td: TrapData = TrapRepo.load_json().get_trap(id)
	var nm := td.trap_name if td != null else "工具"
	_say("已布置「%s」，敌人踩到就会触发" % nm)
	queue_redraw()
''', '''	var c2 := Vector2i(int(cell.x), int(cell.y))
	var td: TrapData = TrapRepo.load_json().get_trap(id)
	# R753 石头（7012）：落点是**敌方单位**，砸下去当场结算，不埋进格子。
	# 伤害与致死收尾都在 `use_tool_on_unit()`（唯一口）；这里只负责摘槽与提示。
	if td != null and td.direct_damage > 0:
		if not engine.use_tool_on_unit(id, c2):
			_say("这一下没砸到人（要有敌方单位才砸得下去）")
			return
		RunState.consume_trap(slot)
		_say("「%s」砸中目标：%d 点伤害" % [td.trap_name, td.direct_damage])
		queue_redraw()
		return
	if not engine.place_trap(id, c2):
		_say("这格已经不能放置工具了")
		return
	RunState.consume_trap(slot)   # 放置那一刻才从栏位移除（R663 口径）
	var nm := td.trap_name if td != null else "工具"
	_say("已布置「%s」，敌人踩到就会触发" % nm)
	queue_redraw()
''')

# ---- F：槽内罩层 → 只留金边提示，栏画在外面 ----
rep('''			# R752：使用型工具已上膛 → 整格盖一层「使用」罩层（这就是那个「使用按钮」）。
			# 判定与命中共用同一个有效期：过时自动收起，不会挂着等人误触。
			if _tool_use_arm == i and Time.get_ticks_msec() <= _tool_use_until:
				draw_rect(r.grow(-2.0), Color(0.05, 0.06, 0.09, 0.80), true)
				draw_rect(r.grow(-2.0), Color("ffd76a"), false, 2.5)
				_draw_string_center(_font_bold, 15, "使用", r.get_center(), Color("ffe6a2"), -1)
''', '''			# R753：栏开着的那一格加一圈金边 —— 「你正在操作的是它」。
			# 按钮本身不再盖在槽里（那会挡住图标），改成画在槽左侧的按钮栏里。
			if _tool_use_arm == i and Time.get_ticks_msec() <= _tool_use_until:
				draw_rect(r.grow(-2.0), Color("ffd76a"), false, 2.5)
''')

rep('''			Color("e4bd62"), -1)
''', '''			Color("e4bd62"), -1)
	# R753：按钮栏画在最后 —— 必须压在槽之上（它探到槽左侧的棋盘上）。
	_draw_tool_bar()
''')

open(p, 'wb').write(txt.encode('utf-8'))
nb = open(p, 'rb').read()
print('crlf', nb.count(b'\r\n'), 'lf', nb.count(b'\n'),
      'bare', nb.count(b'\n') - nb.count(b'\r\n'))
