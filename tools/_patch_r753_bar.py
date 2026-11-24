# -*- coding: utf-8 -*-
"""R753：battle_scene.gd 追加按钮栏的几何 / 绘制 / 即时丢弃（CRLF 文件）。"""
p = 'scripts/battle_scene.gd'
txt = open(p, 'rb').read().decode('utf-8')
assert txt.count('\r\n') > 19000, 'expect CRLF'

anchor = 'func _start_trap_drag(slot: int, pos: Vector2) -> void:\r\n'
assert txt.count(anchor) == 1

new = '''func _discard_tool_now(slot: int) -> void:
	## R753：按钮栏上的「丢弃」——**点它就是确认**（栏本身已经是第二段动作，
	## 再套一层「同一个 × 点两次」就要按三下）。右上角「×」那条两段式路径保留不动。
	var id := RunState.trap_at(slot)
	if id <= 0:
		return
	var td: TrapData = TrapRepo.load_json().get_trap(id)
	var nm := td.trap_name if td != null else "工具"
	RunState.discard_trap(slot)
	_trap_discard_arm = -1
	_trap_discard_until = 0
	_say("已丢弃「%s」，栏位空出来了" % nm)
	queue_redraw()


func _tool_bar_layout(slot: int) -> Dictionary:
	## R753：工具按钮栏的**唯一几何口**（绘制与命中都读它）。
	## 返回 {bar, use, drop}：`use` 对非使用型是空 Rect2（不画、也不吃点击）。
	## 栏宽固定两格 —— 非使用型让「丢弃」占满整条内宽，位置与眼睛的预期一致。
	var sr := _trap_slot_rect(slot)
	var w := TOOL_BAR_BTN_W * 2.0 + TOOL_BAR_GAP + TOOL_BAR_PAD * 2.0
	var h := TOOL_BAR_BTN_H + TOOL_BAR_PAD * 2.0
	var bar := Rect2(sr.position.x - TOOL_BAR_OFFSET - w,
			sr.get_center().y - h * 0.5, w, h)
	var inner := bar.grow(-TOOL_BAR_PAD)
	var td: TrapData = TrapRepo.load_json().get_trap(RunState.trap_at(slot))
	var use_r := Rect2()
	var drop_r := inner
	if td != null and td.is_usable():
		use_r = Rect2(inner.position, Vector2(TOOL_BAR_BTN_W, inner.size.y))
		drop_r = Rect2(inner.position + Vector2(TOOL_BAR_BTN_W + TOOL_BAR_GAP, 0.0),
				Vector2(TOOL_BAR_BTN_W, inner.size.y))
	return {"bar": bar, "use": use_r, "drop": drop_r}


func _draw_tool_bar() -> void:
	## R753：按钮栏本体。只在「栏开着 + 没过期 + 槽里有货」时画 —— 与命中判定同一条闸门。
	## 用户口径「使用型两个按钮用同一个栏」：使用与丢弃并排在一栏里，不拆成两个浮层。
	if _tool_use_arm < 0 or Time.get_ticks_msec() > _tool_use_until:
		return
	var slot := _tool_use_arm
	if RunState.trap_at(slot) <= 0:
		return
	var lay := _tool_bar_layout(slot)
	var bar: Rect2 = lay["bar"]
	draw_rect(bar, Color(0.06, 0.07, 0.10, 0.94), true)
	draw_rect(bar, Color("ffd76a"), false, 2.0)
	var use_r: Rect2 = lay["use"]
	if use_r.size.x > 0.5:
		_tool_bar_btn("使用", use_r, Color("ffe6a2"), Color(0.26, 0.21, 0.09, 0.96))
	var drop_r: Rect2 = lay["drop"]
	_tool_bar_btn("丢弃", drop_r, Color("ffb9a0"), Color(0.28, 0.11, 0.10, 0.96))


func _tool_bar_btn(txt: String, r: Rect2, fg: Color, bg: Color) -> void:
	draw_rect(r, bg, true)
	draw_rect(r, Color(fg.r, fg.g, fg.b, 0.55), false, 1.5)
	_draw_string_center(_font_bold, 14, txt, r.get_center(), fg, -1)


'''
txt = txt.replace(anchor, new.replace('\n', '\r\n') + anchor, 1)
open(p, 'wb').write(txt.encode('utf-8'))
nb = open(p, 'rb').read()
print('crlf', nb.count(b'\r\n'), 'lf', nb.count(b'\n'),
      'bare', nb.count(b'\n') - nb.count(b'\r\n'))
