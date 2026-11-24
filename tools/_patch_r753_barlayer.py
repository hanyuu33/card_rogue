# -*- coding: utf-8 -*-
"""R753：按钮栏改画在独立高层 CanvasItem 上（CRLF 文件）。

原因：右侧「敌方生命 / 回合结束」都是子节点，绘制顺序在 `self._draw()` 之后 ——
在自己身上画按钮栏会被它们整块盖住（实测截图里只看得到槽、看不到按钮）。
"""
p = 'scripts/battle_scene.gd'
txt = open(p, 'rb').read().decode('utf-8')
assert txt.count('\r\n') > 19000


def rep(old, new):
    global txt
    old_c = old.replace('\n', '\r\n')
    new_c = new.replace('\n', '\r\n')
    c = txt.count(old_c)
    assert c == 1, (c, old_c[:70])
    txt = txt.replace(old_c, new_c, 1)


# ① 成员变量
rep('''var _tool_use_arm := -1
''', '''var _tool_use_arm := -1
## R753：按钮栏的绘制层（独立 CanvasItem、z_index 高）。见 `_ready` 里的创建处。
var _tool_bar_layer: Control = null
''')

# ② _ready 里创建
rep('''	info_clip = _ic
''', '''	info_clip = _ic
	# R753：工具按钮栏画在**独立的高层 CanvasItem** 上。它要盖住右侧那些面板
	# （敌方生命 / 回合结束 / 消耗 / 弃牌），而它们是子节点、绘制顺序在 `self._draw()`
	# **之后** —— 直接在本体里画会被整块盖掉（R753 实测：截图里只有槽、没有按钮）。
	# mouse_filter = IGNORE：它只负责画，命中判定仍走 `_gui_input` 的矩形判断。
	var tbl := Control.new()
	tbl.name = "ToolBarLayer"
	tbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	tbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tbl.z_index = 400
	tbl.draw.connect(func(): _paint_tool_bar(tbl))
	add_child(tbl)
	_tool_bar_layer = tbl
''')

# ③ _draw_tool_bar 改成「只排重绘」，另加真正的绘制
rep('''func _draw_tool_bar() -> void:
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
''', '''func _draw_tool_bar() -> void:
	## R753：本体的 `_draw()` 每次重绘时，把按钮栏那一层也排一次重绘。
	## 真正的笔画在 `_paint_tool_bar()` 里（画在独立高层上，见 `_ready`）。
	if _tool_bar_layer != null:
		_tool_bar_layer.queue_redraw()


func _paint_tool_bar(ci: CanvasItem) -> void:
	## R753：按钮栏本体。只在「栏开着 + 没过期 + 槽里有货」时画 —— 与命中判定同一条闸门。
	## 用户口径「使用型两个按钮用同一个栏」：使用与丢弃并排在一栏里，不拆成两个浮层。
	if _tool_use_arm < 0 or Time.get_ticks_msec() > _tool_use_until:
		return
	var slot := _tool_use_arm
	if RunState.trap_at(slot) <= 0:
		return
	var lay := _tool_bar_layout(slot)
	var bar: Rect2 = lay["bar"]
	ci.draw_rect(bar, Color(0.06, 0.07, 0.10, 0.94), true)
	ci.draw_rect(bar, Color("ffd76a"), false, 2.0)
	var use_r: Rect2 = lay["use"]
	if use_r.size.x > 0.5:
		_tool_bar_btn(ci, "使用", use_r, Color("ffe6a2"), Color(0.26, 0.21, 0.09, 0.96))
	var drop_r: Rect2 = lay["drop"]
	_tool_bar_btn(ci, "丢弃", drop_r, Color("ffb9a0"), Color(0.28, 0.11, 0.10, 0.96))


func _tool_bar_btn(ci: CanvasItem, txt: String, r: Rect2, fg: Color, bg: Color) -> void:
	## 自绘按钮（不挂 Button 节点：那会在拖牌经过时抢走松手事件，R391 的老教训）。
	var px := 14
	ci.draw_rect(r, bg, true)
	ci.draw_rect(r, Color(fg.r, fg.g, fg.b, 0.55), false, 1.5)
	var fw := _font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc := _font_bold.get_ascent(px)
	var dsc := _font_bold.get_descent(px)
	var p := Vector2(r.get_center().x - fw * 0.5,
			r.get_center().y + (asc - dsc) * 0.5)
	ci.draw_string(_font_bold, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fg)
''')

open(p, 'wb').write(txt.encode('utf-8'))
nb = open(p, 'rb').read()
print('crlf', nb.count(b'\r\n'), 'lf', nb.count(b'\n'),
      'bare', nb.count(b'\n') - nb.count(b'\r\n'))
