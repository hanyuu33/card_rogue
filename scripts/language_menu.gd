extends Control
## 可滚动语言列表（R660）—— 设置页下拉与首次语言选择共用。
##
## 现在只有 3 种语言，一个面板刚好排满；以后加到 10 种也不需要改界面：
## 列表按行绘制，超过可视行数自动出现右侧滚动条，滚轮 / 拖动 / ↑↓ 都能浏览。
##
## 纪律：本组件只负责「列出注册表 + 选中一行 + 发 picked 信号」，不写设置、不切场景。
## 因此设置页（即时生效）和首次选择页（确认后生效）可以复用同一种交互，各自决定提交时机。

const UiTheme = preload("res://scripts/ui_theme.gd")

signal picked(code: String)
signal highlighted(code: String)
signal activated(code: String)

const PAD := 8.0
const BAR_W := 10.0

var row_height := 50.0
var _items: Array = []
var _selected := ""
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
	# 弹层必须自己吃鼠标事件，否则点列表会把下面的设置行也翻掉。
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	resized.connect(_clamp_scroll)


func setup(items: Array, selected: String, row_h := 50.0) -> void:
	_items = items.duplicate(true)
	row_height = maxf(row_h, 36.0)
	_selected = selected
	if _index_of(_selected) < 0 and not _items.is_empty():
		_selected = str((_items[0] as Dictionary).get("code", ""))
	_hover = -1
	_scroll = 0
	_ensure_visible(_index_of(_selected))
	queue_redraw()


func selected_code() -> String:
	return _selected


func visible_rows() -> int:
	var h := maxf(size.y - PAD * 2.0, row_height)
	return maxi(1, int(floor(h / row_height)))


func _max_scroll() -> int:
	return maxi(0, _items.size() - visible_rows())


func _index_of(code: String) -> int:
	for i in _items.size():
		if str((_items[i] as Dictionary).get("code", "")) == code:
			return i
	return -1


func _clamp_scroll() -> void:
	var m := _max_scroll()
	if _scroll > m:
		_scroll = m
	if _scroll < 0:
		_scroll = 0
	queue_redraw()


func _set_scroll(v: int) -> void:
	var nv := clampi(v, 0, _max_scroll())
	if nv == _scroll:
		return
	_scroll = nv
	queue_redraw()


func _ensure_visible(idx: int) -> void:
	if idx < 0:
		return
	if idx < _scroll:
		_scroll = idx
	elif idx >= _scroll + visible_rows():
		_scroll = idx - visible_rows() + 1
	_clamp_scroll()


func select_code(code: String, emit := false) -> void:
	var idx := _index_of(code)
	if idx < 0:
		return
	_selected = code
	_ensure_visible(idx)
	queue_redraw()
	if emit:
		picked.emit(code)


func _row_at(pos: Vector2) -> int:
	if pos.x < PAD or pos.y < PAD:
		return -1
	if _items.size() > visible_rows() and pos.x >= size.x - PAD - BAR_W:
		return -1   # 右侧滚动条区域不放给行点击（避免想拖条却选中一行）
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
			if not _drag_moved and idx >= 0:
				_selected = str((_items[idx] as Dictionary).get("code", ""))
				_ensure_visible(idx)
				queue_redraw()
				picked.emit(_selected)
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
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var k := event as InputEventKey
		if k.echo:
			return
		var idx := _index_of(_selected)
		match k.keycode:
			KEY_UP:
				idx = maxi(0, idx - 1)
				_selected = str((_items[idx] as Dictionary).get("code", _selected))
				_ensure_visible(idx)
				highlighted.emit(_selected)
				queue_redraw()
				accept_event()
			KEY_DOWN:
				idx = mini(_items.size() - 1, idx + 1)
				_selected = str((_items[idx] as Dictionary).get("code", _selected))
				_ensure_visible(idx)
				highlighted.emit(_selected)
				queue_redraw()
				accept_event()
			KEY_ENTER, KEY_KP_ENTER:
				if _index_of(_selected) >= 0:
					# 鼠标点行发 picked（只预览 / 设置页即时生效）；
					# 键盘 Enter 发 activated（首次选择页直接确认，否则自绘按钮键盘碰不到）。
					activated.emit(_selected)
					accept_event()


func _draw() -> void:
	if _items.is_empty():
		return
	var full := Rect2(Vector2.ZERO, size)
	# 列表用「一叠纸卡」而不是九宫格卷轴：九宫格四角有 34px 装饰，最后一行副标题
	# 会被卷边压住（R660 首次出图当场看见）。纸卡边框与设置页的行卡同一套语言。
	UiTheme.draw_info_card(self, full, false)

	var overflow := _items.size() > visible_rows()
	var content_w := size.x - PAD * 2.0 - (BAR_W + 4.0 if overflow else 0.0)
	var rows := visible_rows()
	for k in rows:
		var idx := _scroll + k
		if idx >= _items.size():
			break
		var r := Rect2(PAD, PAD + float(k) * row_height, content_w, row_height - 4.0)
		_draw_row(idx, r)

	if overflow:
		_draw_bar()


func _draw_row(idx: int, r: Rect2) -> void:
	var d: Dictionary = _items[idx]
	var code := str(d.get("code", ""))
	var sel := code == _selected
	var hov := idx == _hover
	if sel:
		draw_rect(r, UiTheme.ADVENTURE_FOREST, true)
		draw_rect(r, UiTheme.ADVENTURE_BRASS_LIT, false, 1.4)
	elif hov:
		draw_rect(r, UiTheme.ADVENTURE_INPUT, true)
		draw_rect(r, UiTheme.ADVENTURE_BRASS, false, 1.0)
	else:
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.32), true)

	var ink := UiTheme.ADVENTURE_LIGHT if sel else UiTheme.PAGE_INK
	var meta_ink := Color(0.88, 0.84, 0.74) if sel else UiTheme.PAGE_MUTED
	var native := str(d.get("native", code))
	var en := str(d.get("en", ""))
	var two_line := row_height >= 46.0
	# ⚠️ baseline 是**行内坐标**：前面已经加过 r.position，这里不能再加一次 r.position.y，
	# 否则第二行会被推到第三行、第三行直接画出面板（R660 截图当场抓到）。
	var baseline := 22.0 if two_line else 24.0
	draw_string(_font_bold, r.position + Vector2(15.0, baseline), native,
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 52.0, UiTheme.FS_BODY, ink)
	if two_line and en != "" and en != native:
		draw_string(_font, r.position + Vector2(15.0, 39.0), en,
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 52.0, UiTheme.FS_MICRO, meta_ink)

	if sel:
		# 选中标记：金色小菱形 + 内圈，和选择界面的「封蜡」语气一致，不额外做对勾图标。
		var c := Vector2(r.end.x - 18.0, r.get_center().y)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -6), c + Vector2(5, 0),
			c + Vector2(0, 6), c + Vector2(-5, 0)]), UiTheme.PAGE_GOLD)
		draw_circle(c, 2.0, UiTheme.ADVENTURE_FOREST)
	elif idx < _items.size() - 1:
		# 行与行之间压一条极淡金线；不画边框，保持「一叠纸」的轻感。
		var y := r.end.y + 2.0
		draw_line(Vector2(r.position.x + 12.0, y), Vector2(r.end.x - 12.0, y),
				Color(UiTheme.PAGE_GOLD, 0.28), 1.0)


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
