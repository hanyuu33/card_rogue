extends Control
## 正式版首次语言选择（R660）—— 片头之后、首页之前。
##
## 为什么单独一屏：标题页的主视觉里已经烘焙了中文标题，把语言选择塞在按钮列里
## 会同时破坏「一屏一个主按钮」和标题构图。这里用一页**可滚动列表**解决，
## 现在 3 种语言刚好排满，以后加到 10 种也只多一条滚动条。
##
## 提交时机：点「进入游戏」才落盘。玩家在选人页 / 首页前关掉窗口，下次仍会看到；
## 不会因为误触某一行就永久改掉语言。Esc 不提交，也不会把玩家困住（可直接关窗）。

const UiTheme = preload("res://scripts/ui_theme.gd")
const L10n = preload("res://scripts/l10n.gd")
const LanguageMenu = preload("res://scripts/language_menu.gd")

## R660c：标题匾加高到 100 —— 原先 82 时 32px 的「选择语言」字头
## 正好压在 10px 的 LANGUAGE 小字上（店长当场看到「language 被四个汉字挡住」）。
const HEAD_H := 100.0
const MENU_W := 620.0
const MENU_ROW_H := 56.0
const MENU_MAX_ROWS := 6
const BTN_W := 320.0
const BTN_H := 52.0

var _bg: Texture2D
var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: Control
var _selected := "zh"
var _hover_btn := false


func _ready() -> void:
	UiTheme.attach_stage(self)
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	_bg = UiAssets.language_bg()
	if _bg == null:
		_bg = UiAssets.title_art()
	if _bg == null:
		_bg = UiAssets.title_bg()
	GameSettings.ensure_loaded()
	_selected = L10n.system_language()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	_build_menu()
	resized.connect(queue_redraw)
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.8
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_language.png"))
			get_tree().quit())
		add_child(t)
		t.start()


func _build_menu() -> void:
	_menu = LanguageMenu.new()
	_menu.picked.connect(_on_picked)
	_menu.highlighted.connect(_on_highlighted)
	_menu.activated.connect(_on_activated)
	add_child(_menu)
	_layout_menu()
	_menu.setup(L10n.LANGUAGES, _selected, MENU_ROW_H)
	_menu.grab_focus.call_deferred()


func _menu_height() -> float:
	var rows := mini(L10n.LANGUAGES.size(), MENU_MAX_ROWS)
	return float(rows) * MENU_ROW_H + 16.0


func _overflow() -> bool:
	return L10n.LANGUAGES.size() > MENU_MAX_ROWS


func _layout_menu() -> void:
	## 三块（标题 / 列表 / 确认）作为一组垂直居中；语言变多时列表先长到 6 行再滚动。
	var menu_h := _menu_height()
	var hint_h := 18.0 if _overflow() else 0.0
	var total := 82.0 + 12.0 + menu_h + hint_h + 16.0 + BTN_H + 12.0 + 18.0
	var top := maxf(28.0, (size.y - total) * 0.5)
	var menu_y := top + 82.0 + 12.0
	_menu.position = Vector2((size.x - MENU_W) * 0.5, menu_y)
	_menu.size = Vector2(MENU_W, menu_h)


func _confirm_rect() -> Rect2:
	var menu_h := _menu_height()
	var hint_h := 18.0 if _overflow() else 0.0
	var total := 82.0 + 12.0 + menu_h + hint_h + 16.0 + BTN_H + 12.0 + 18.0
	var top := maxf(28.0, (size.y - total) * 0.5)
	var y := top + 82.0 + 12.0 + menu_h + hint_h + 16.0
	return Rect2((size.x - BTN_W) * 0.5, y, BTN_W, BTN_H)


func _note_base_y() -> float:
	return _confirm_rect().end.y + 30.0


func _on_picked(code: String) -> void:
	_selected = L10n.normalize(code)
	if sfx != null:
		sfx.play("click")
	queue_redraw()


func _on_highlighted(code: String) -> void:
	## 键盘 ↑↓ 只改高亮：标题和确认按钮跟着预览，真正落盘仍在「进入游戏」。
	_selected = L10n.normalize(code)
	queue_redraw()


func _on_activated(code: String) -> void:
	## 键盘 Enter = 选中并直接确认；鼠标点行仍然只预览，避免误提交。
	_selected = L10n.normalize(code)
	_confirm()


func _confirm() -> void:
	GameSettings.set_language(_selected, true)
	if sfx != null:
		sfx.play("click")
	SceneFx.goto("res://scenes/title.tscn")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _confirm_rect().has_point(event.position)
		if h != _hover_btn:
			_hover_btn = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _confirm_rect().has_point(event.position):
			_confirm()
			accept_event()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	if _bg != null:
		# cover：等比铺满，多出的部分裁掉（不能拉伸，水彩笔触会变形）
		var ts := _bg.get_size()
		var scale := maxf(size.x / maxf(ts.x, 1.0), size.y / maxf(ts.y, 1.0))
		var w := ts.x * scale
		var h := ts.y * scale
		draw_texture_rect(_bg, Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.5),
				Vector2(w, h)), false)
		draw_rect(full, Color(0.10, 0.09, 0.07, 0.28))
	else:
		draw_rect(full, UiTheme.SCREEN_BG)

	var top := _menu.position.y - 12.0
	var head := Rect2(_menu.position.x, top - HEAD_H, MENU_W, HEAD_H)
	draw_rect(head, Color(0.14, 0.11, 0.08, 0.68), true)
	draw_rect(head, Color(UiTheme.ADVENTURE_BRASS, 0.9), false, 1.2)
	_draw_head_ornaments(head)
	_draw_kicker(head)
	var title := L10n.t("language.title", _selected)
	draw_string(_font_bold, Vector2(head.position.x, head.position.y + 62.0), title,
			HORIZONTAL_ALIGNMENT_CENTER, head.size.x, UiTheme.FS_TITLE,
			UiTheme.ADVENTURE_LIGHT)
	draw_string(_font, Vector2(head.position.x, head.position.y + 84.0),
			L10n.t("language.subtitle", _selected),
			HORIZONTAL_ALIGNMENT_CENTER, head.size.x, UiTheme.FS_LABEL,
			Color(0.92, 0.87, 0.76, 0.92))

	if _overflow():
		draw_string(_font, Vector2(_menu.position.x, _menu.end.y + 14.0),
				L10n.t("language.scroll_hint", _selected),
				HORIZONTAL_ALIGNMENT_CENTER, _menu.size.x, UiTheme.FS_MICRO,
				Color(0.94, 0.90, 0.80, 0.92))

	var btn := _confirm_rect()
	var hov := _hover_btn
	UiTheme.draw_action(self, btn, true, false, hov)
	draw_string(_font_bold, Vector2(btn.position.x, btn.position.y + 33.0),
			L10n.t("language.confirm", _selected),
			HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, UiTheme.FS_SUBHEAD,
			UiTheme.ADVENTURE_LIGHT)

	var note := L10n.t("language.note", _selected)
	var ny := _note_base_y()
	# 背景是浅色水彩：先垫一层深色字影，奶油色正文才在亮部也读得清。
	draw_string(_font, Vector2(0, ny + 1.0), note, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, UiTheme.FS_LABEL, Color(0.08, 0.07, 0.05, 0.55))
	draw_string(_font, Vector2(0, ny), note, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, UiTheme.FS_LABEL, Color(0.98, 0.94, 0.84, 0.96))

	# 左上角厂牌：只做一枚小字锚点，不抢主标题。
	# ⚠️ 背景是浅色水彩（窗格 / 银杏叶），奶油金小字压在亮部只有 ~1.6:1 —— 低于
	# 「≤12px 小字 ≥5:1」的底线（R660 出图当场看见，字在但读不清）。改羊皮纸墨色，
	# 底下垫一层半透明奶油做描边，深葉与浅窗两种背景上都立得住。
	var brand := GameBrand.NAME_EN if GameBrand.NAME_EN != "" else GameBrand.NAME_CN
	draw_string(_font_bold, Vector2(34, 47.4), brand, HORIZONTAL_ALIGNMENT_LEFT,
			-1, UiTheme.FS_LABEL, Color(1.0, 0.97, 0.90, 0.45))
	draw_string(_font_bold, Vector2(34, 48), brand, HORIZONTAL_ALIGNMENT_LEFT,
			-1, UiTheme.FS_LABEL, Color("332a1e", 0.96))


func _draw_head_ornaments(head: Rect2) -> void:
	## 标题匾的两端各一枚小金菱 + 内细线：让这条深色带像「木牌」而不是一块纯色矩形。
	var inner := head.grow(-5.0)
	draw_rect(inner, Color(UiTheme.ADVENTURE_BRASS, 0.28), false, 0.8)
	for side in [-1.0, 1.0]:
		var c := Vector2(head.get_center().x + side * (head.size.x * 0.5 - 15.0),
				head.get_center().y)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -5), c + Vector2(4, 0),
			c + Vector2(0, 5), c + Vector2(-4, 0)]), UiTheme.PAGE_GOLD)
		draw_line(c + Vector2(side * 8.0, 0), c + Vector2(side * 18.0, 0),
				Color(UiTheme.ADVENTURE_BRASS, 0.55), 1.0)


func _draw_kicker(head: Rect2) -> void:
	## 字距拉开的 LANGUAGE —— 手写逐字绘制，避免依赖字体里的 letterspacing。
	var txt := L10n.t("language.kicker", _selected)
	var fs := UiTheme.FS_MICRO
	var track := 3.2
	var widths: Array[float] = []
	var total := 0.0
	for i in txt.length():
		var w := _font_bold.get_string_size(txt.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT,
				-1, fs).x
		widths.append(w)
		total += w
	total += track * float(maxi(0, txt.length() - 1))
	var x := head.position.x + (head.size.x - total) * 0.5
	for i in txt.length():
		draw_string(_font_bold, Vector2(x, head.position.y + 24.0), txt.substr(i, 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.PAGE_GOLD)
		x += widths[i] + track
