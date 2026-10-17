extends Control
## 对战记录（R215）—— 每局一行：开始时间 / 角色 / 结果 / 难度 / 用时。
##
## 取代原「录像回放」页（R46 的完整回放机制已删）：只留**最终结果**，
## 通关 / 失败 / 中途放弃 / **中断**（关掉游戏没打完）都会有一行，
## 写入与中断判定见 `RunRecord`。文件：`user://run_records.json`。

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_H := 56.0
const ROW_W := 980.0
const LIST_Y := 132.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _rows: Array = []            # 新在前：[{record}]——直接就是记录字典
var _hover := -1
var _scroll := 0                  # 首行下标（滚轮）
var _clear_armed := false         # 「清空」二次确认
var _last_mp := Vector2.INF


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	_refresh()
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_records.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续",
		"sub": "对战记录 · 按 Esc 返回",
	})


func _menu_items() -> Array:
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and _menu.handle_esc(event):
		return


func _refresh() -> void:
	var all := RunRecord.list_records()
	_rows = []
	for i in range(all.size() - 1, -1, -1):     # 新在前
		_rows.append(all[i])
	_scroll = 0
	_clear_armed = false
	queue_redraw()


func _process(_delta: float) -> void:
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		queue_redraw()


# ------------------------------------------------------------ 布局

func _row_rect(i: int) -> Rect2:
	return Rect2((size.x - ROW_W) / 2.0, LIST_Y + (i - _scroll) * ROW_H,
			ROW_W, ROW_H - 8.0)


func _back_rect() -> Rect2:
	return Rect2(14, 14, 110, 34)


func _clear_rect() -> Rect2:
	## 左下角（右上角被「道具 / 牌库」两个查看器占着，别压上去）。
	return Rect2(14.0, size.y - 54.0, 124.0, 34.0)


func _max_rows() -> int:
	return maxi(1, int((size.y - LIST_Y - 24.0) / ROW_H))


func _row_at(pos: Vector2) -> int:
	var n := _max_rows()
	for i in n:
		var idx := _scroll + i
		if idx >= _rows.size():
			break
		if _row_rect(idx).has_point(pos):
			return idx
	return -1


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _row_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_clear_armed = false      # 点别处 → 取消「清空」待确认
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back_to_title()
			return
		if _clear_rect().has_point(event.position):
			if _rows.is_empty():
				return
			sfx.play("click")
			if not _clear_armed:
				_clear_armed = true
				queue_redraw()
				return
			RunRecord.clear_all()
			_refresh()
			sfx.play("attack")
			return
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN
			or event.button_index == MOUSE_BUTTON_WHEEL_UP):
		var step := 3 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -3
		var hi := maxi(0, _rows.size() - _max_rows())
		_scroll = clampi(_scroll + step, 0, hi)
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _back_to_title() -> void:
	SceneFx.goto("res://scenes/title.tscn")


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	var top := Color("1c1f28")
	var bottom := Color("303443")
	for i in 36:
		var t := float(i) / 35.0
		draw_rect(Rect2(0, size.y * float(i) / 36.0, size.x, size.y / 36.0 + 1.0),
				top.lerp(bottom, t), true)
	draw_string(_font_bold, Vector2(0, 62), "对 战 记 录",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, UiTheme.SAND)
	var wins := 0
	for r: Dictionary in _rows:
		if str(r.get("result", "")) == "win":
			wins += 1
	draw_string(_font, Vector2(0, 94),
			"共 %d 局 · 通关 %d 局（中断 / 中途放弃也会记在这里）" % [_rows.size(), wins],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
	# 左上返回 / 右上清空
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	draw_rect(back, Color("414860") if hov_back else Color("343947"), true)
	draw_rect(back, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, back.position + Vector2(0, 22), "← 返回标题",
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, Color("e6e2d8"))
	var cl := _clear_rect()
	var hov_cl := cl.has_point(get_local_mouse_position()) and not _rows.is_empty()
	draw_rect(cl, Color("8a3030") if _clear_armed else (Color("4a2c2c") if hov_cl
			else Color("343947")), true)
	draw_rect(cl, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, cl.position + Vector2(0, 22),
			"确认清空？" if _clear_armed else "清空记录",
			HORIZONTAL_ALIGNMENT_CENTER, cl.size.x, UiTheme.FS_LABEL,
			Color("ffd8d8") if _clear_armed else Color("c8a8a8"))
	if _rows.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 40),
				"还没有记录 —— 从标题「开始对战」打一局，结束后这里会有一行结果。",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.INK_ON_DARK)
		return
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _rows.size():
			break
		_draw_row(idx, _rows[idx])
	if _rows.size() > _max_rows():
		draw_string(_font, Vector2(0, size.y - 12),
				"滚轮翻页 · 第 %d–%d 条 / 共 %d 条"
				% [_scroll + 1, mini(_scroll + _max_rows(), _rows.size()), _rows.size()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				UiTheme.INK_ON_DARK)


func _draw_row(idx: int, rec: Dictionary) -> void:
	var r := _row_rect(idx)
	var hov := idx == _hover
	draw_rect(r, Color("3a4152") if hov else Color("22242c"), true)
	draw_rect(r, Color("6a768c") if hov else Color("4a4e58"), false, 1.6)
	var res := str(rec.get("result", ""))
	# 结果色条（左沿）：一眼分辨通关 / 失败 / 中断
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			RunRecord.result_color(res), true)
	draw_string(_font_bold, r.position + Vector2(18, 24),
			RunRecord.fmt_time(str(rec.get("time", "?"))),
			HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_BODY, UiTheme.SAND)
	draw_string(_font_bold, r.position + Vector2(246, 24),
			"角色：%s" % PlayerClass.legacy_id(str(rec.get("class", "?"))),
			HORIZONTAL_ALIGNMENT_LEFT, 190, UiTheme.FS_BODY, Color("9fd7a5"))
	draw_string(_font_bold, r.position + Vector2(446, 24), RunRecord.result_label(res),
			HORIZONTAL_ALIGNMENT_LEFT, 140, UiTheme.FS_BODY, RunRecord.result_color(res))
	draw_string(_font, r.position + Vector2(596, 24),
			"难度 %d · 用时 %s" % [int(rec.get("difficulty", 2)),
			RunRecord.fmt_secs(int(rec.get("secs", 0)))],
			HORIZONTAL_ALIGNMENT_LEFT, 280, UiTheme.FS_LABEL, UiTheme.INK_300)
	draw_string(_font, r.position + Vector2(18, 43),
			"结束于 %s" % RunRecord.fmt_time(str(rec.get("end", ""))),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_CAPTION, Color("7d8590"))
