extends Control
## R818：Mod 列表 —— 设置页「模组」页的可滚动列表，一行一个 mod + 右侧启停开关。
##
## 纪律同 LanguageMenu：**只负责列出来 + 发信号**，不写 cfg、不碰 DataPaths。
## 谁改启停、什么时候让数据层重算，全由设置页决定（不在对局里才立刻生效）。
##
## 空列表不在这里画提示 —— 直接 `visible = false`，让设置页在下面那层画空状态，
## 省得两处各写一套「没装 mod」的文案。

const UiTheme = preload("res://scripts/ui_theme.gd")

signal toggled(id: String, on: bool)

const PAD := 8.0
const BAR_W := 10.0
const SW_W := 60.0
const SW_H := 26.0

var row_height := 54.0
var _items: Array = []
var _hover := -1
var _scroll := 0
var _font: Font
var _font_bold: Font
var _dragging := false
var _drag_start_y := 0.0
var _drag_start_scroll := 0
var _drag_moved := false
var _touch_accum := 0.0


func _ready() -> void:
	# 必须自己吃鼠标事件，否则点列表会把下面的设置行也翻掉。
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	resized.connect(_clamp_scroll)


func setup(items: Array, row_h := 54.0) -> void:
	_items = items.duplicate(true)
	row_height = maxf(row_h, 44.0)
	_hover = -1
	_scroll = 0
	_clamp_scroll()
	queue_redraw()


func count() -> int:
	return _items.size()


func visible_rows() -> int:
	var h := maxf(size.y - PAD * 2.0, row_height)
	return maxi(1, int(floor(h / row_height)))


func _max_scroll() -> int:
	return maxi(0, _items.size() - visible_rows())


func _clamp_scroll() -> void:
	var m := _max_scroll()
	_scroll = clampi(_scroll, 0, m)
	queue_redraw()


func _set_scroll(v: int) -> void:
	var nv := clampi(v, 0, _max_scroll())
	if nv == _scroll:
		return
	_scroll = nv
	queue_redraw()


func _row_at(pos: Vector2) -> int:
	if pos.x < PAD or pos.y < PAD:
		return -1
	if _items.size() > visible_rows() and pos.x >= size.x - PAD - BAR_W:
		return -1   # 右侧滚动条区域不放给行点击（避免想拖条却切换了一个 mod）
	var i := int((pos.y - PAD) / row_height) + _scroll
	if i < 0 or i >= _items.size():
		return -1
	return i


func _refresh_hover(pos: Vector2) -> void:
	var h := _row_at(pos)
	if h != _hover:
		_hover = h
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			var dy := mm.position.y - _drag_start_y
			if absf(dy) > 6.0:
				_drag_moved = true
			var steps := int(absf(dy) / (row_height * 0.62))
			if steps > 0:
				_set_scroll(_drag_start_scroll - int(signf(dy)) * steps)
		else:
			_refresh_hover(mm.position)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_scroll(_scroll - 1)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_scroll(_scroll + 1)
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			grab_focus()
			_dragging = true
			_drag_moved = false
			_drag_start_y = mb.position.y
			_drag_start_scroll = _scroll
			_refresh_hover(mb.position)
			accept_event()
			return
		if _dragging:
			_dragging = false
			var idx := _row_at(mb.position)
			# 拖动过就不算点击 —— 否则一次滚动会顺手关掉一个 mod。
			if not _drag_moved and idx >= 0:
				var d: Dictionary = _items[idx]
				var nv := not bool(d.get("enabled", true))
				d["enabled"] = nv       # 本地先翻，画面立刻有反馈
				queue_redraw()
				toggled.emit(str(d.get("id", "")), nv)
			accept_event()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touch_accum += sd.relative.y
		var step := row_height * 0.62
		while absf(_touch_accum) >= step:
			_set_scroll(_scroll - int(signf(_touch_accum)))
			_touch_accum -= signf(_touch_accum) * step
		accept_event()


func _draw() -> void:
	if _items.is_empty():
		return
	var full := Rect2(Vector2.ZERO, size)
	UiTheme.draw_info_card(self, full, false)
	var overflow := _items.size() > visible_rows()
	var content_w := size.x - PAD * 2.0 - (BAR_W + 4.0 if overflow else 0.0)
	for k in visible_rows():
		var idx := _scroll + k
		if idx >= _items.size():
			break
		var r := Rect2(PAD, PAD + float(k) * row_height, content_w, row_height - 4.0)
		_draw_row(idx, r)
	if overflow:
		_draw_bar()


func _draw_row(idx: int, r: Rect2) -> void:
	var d: Dictionary = _items[idx]
	var on := bool(d.get("enabled", true))
	var hov := idx == _hover
	draw_rect(r, UiTheme.ADVENTURE_INPUT if hov else Color(1.0, 1.0, 1.0, 0.32), true)
	if hov:
		draw_rect(r, UiTheme.ADVENTURE_BRASS, false, 1.0)

	var ink := UiTheme.PAGE_INK if on else Color("8b8f98")
	var meta_ink := UiTheme.PAGE_MUTED if on else Color("9a9ea6")
	var text_w := r.size.x - SW_W - 44.0
	draw_string(_font_bold, r.position + Vector2(15.0, 24.0), str(d.get("name", "")),
			HORIZONTAL_ALIGNMENT_LEFT, text_w, UiTheme.FS_BODY, ink)
	# 副行：版本 · 作者。两个都没有就不画，别留一条空荡荡的副行。
	var meta := _meta_text(d)
	if meta != "":
		draw_string(_font, r.position + Vector2(15.0, 44.0), meta,
				HORIZONTAL_ALIGNMENT_LEFT, text_w, UiTheme.FS_MICRO, meta_ink)

	# 右侧开关：药丸 + 圆点，与设置页的开关同一套画法（关掉时整行压灰）
	var sw := Rect2(r.position.x + r.size.x - SW_W - 14.0,
			r.position.y + r.size.y / 2.0 - SW_H / 2.0, SW_W, SW_H)
	var track := StyleBoxFlat.new()
	track.bg_color = UiTheme.ADVENTURE_FOREST if on else UiTheme.ADVENTURE_INPUT
	track.border_color = UiTheme.ADVENTURE_BRASS
	track.set_border_width_all(1)
	track.set_corner_radius_all(int(SW_H / 2.0))
	track.corner_detail = 12
	track.anti_aliasing = true
	draw_style_box(track, sw)
	var knob := StyleBoxFlat.new()
	knob.bg_color = UiTheme.PAGE_PAPER
	knob.border_color = UiTheme.ADVENTURE_BRASS
	knob.set_border_width_all(1)
	knob.set_corner_radius_all(10)
	knob.corner_detail = 12
	knob.anti_aliasing = true
	var knob_x := sw.position.x + (sw.size.x - 20.0 if on else 4.0)
	draw_style_box(knob, Rect2(knob_x, sw.position.y + 3.0, 16.0, SW_H - 6.0))


func _meta_text(d: Dictionary) -> String:
	var parts := PackedStringArray()
	var v := str(d.get("version", "")).strip_edges()
	if v != "":
		parts.append("v" + v.trim_prefix("v"))
	var a := str(d.get("author", "")).strip_edges()
	if a != "":
		parts.append(a)
	return "  ·  ".join(parts)


func _draw_bar() -> void:
	var track := Rect2(size.x - PAD - BAR_W, PAD, BAR_W, size.y - PAD * 2.0)
	draw_rect(track, Color(0.30, 0.26, 0.18, 0.18), true)
	draw_rect(track, UiTheme.ADVENTURE_BRASS, false, 0.8)
	var total := float(maxi(_items.size(), 1))
	var ratio := float(visible_rows()) / total
	var th := maxf(22.0, track.size.y * ratio)
	var denom := float(maxi(_max_scroll(), 1))
	var t := float(_scroll) / denom
	var y := track.position.y + (track.size.y - th) * t
	var thumb := Rect2(track.position.x + 2.0, y, BAR_W - 4.0, th)
	draw_rect(thumb, UiTheme.ADVENTURE_BRASS, true)
	draw_rect(thumb, UiTheme.ADVENTURE_BRASS_LIT, false, 0.8)
