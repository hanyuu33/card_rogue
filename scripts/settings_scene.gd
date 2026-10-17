extends Control
## 设置页（R215）—— 音效 / 音乐 / 全屏。三项都**立刻生效并记住**（GameSettings）。
##
## 入口：标题页「设置」按钮。之所以单开一页而不是塞进标题页：标题页是按钮栈
## （`Buttons` 容器），塞开关进去会把一屏一个主按钮的层次搞乱。

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_W := 520.0
const ROW_H := 64.0
const ROW_GAP := 14.0
const LIST_Y := 220.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _hover := -1
var _last_mp := Vector2.INF


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	GameSettings.ensure_loaded()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_settings.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续",
		"sub": "设置 · 按 Esc 返回",
	})


func _menu_items() -> Array:
	return [
		{"text": "返回标题", "fn": _back_to_title},
	]


func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and _menu.handle_esc(event):
		return


func _process(_delta: float) -> void:
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		queue_redraw()


# ------------------------------------------------------------ 布局 / 输入

func _row_rect(i: int) -> Rect2:
	var total := 3.0 * ROW_H + 2.0 * ROW_GAP
	var y := LIST_Y + (320.0 - total) * 0.35
	return Rect2((size.x - ROW_W) / 2.0, y + i * (ROW_H + ROW_GAP), ROW_W, ROW_H)


func _back_rect() -> Rect2:
	return Rect2(14, 14, 110, 34)


func _row_at(pos: Vector2) -> int:
	for i in 3:
		if _row_rect(i).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _row_at(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back_to_title()
			return
		var i := _row_at(event.position)
		if i >= 0:
			sfx.play("click")
			_flip(i)
			return
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _flip(i: int) -> void:
	GameSettings.ensure_loaded()
	match i:
		0:
			GameSettings.set_sfx_on(not GameSettings.sfx_on)
			sfx.enabled = GameSettings.sfx_on
			if sfx.enabled:
				sfx.play("click")
		1:
			GameSettings.set_music_on(not GameSettings.music_on)
			Bgm.set_enabled(GameSettings.music_on)
			if GameSettings.music_on:
				Bgm.play("title")   # 当场就有反馈（否则要等下一次切场景才响）
		2:
			GameSettings.set_fullscreen(not GameSettings.fullscreen)
	queue_redraw()


func _back_to_title() -> void:
	SceneFx.goto("res://scenes/title.tscn")


# ------------------------------------------------------------ 绘制

func _row(i: int) -> Dictionary:
	GameSettings.ensure_loaded()
	match i:
		0:
			return {"title": "音效", "desc": "点击 / 出牌 / 攻击等提示音",
					"on": GameSettings.sfx_on}
		1:
			return {"title": "音乐", "desc": "背景音乐（标题 / 地图 / 战斗各自换曲）",
					"on": GameSettings.music_on}
	return {"title": "全屏", "desc": "关掉则使用窗口模式（默认窗口）",
			"on": GameSettings.fullscreen}


func _draw() -> void:
	var top := Color("1c1f28")
	var bottom := Color("303443")
	for i in 36:
		var t := float(i) / 35.0
		draw_rect(Rect2(0, size.y * float(i) / 36.0, size.x, size.y / 36.0 + 1.0),
				top.lerp(bottom, t), true)
	draw_string(_font_bold, Vector2(0, 78), "设 置",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, UiTheme.SAND)
	draw_string(_font, Vector2(0, 110), "点一行即可切换 · 自动保存，下次启动仍然有效",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	draw_rect(back, Color("414860") if hov_back else Color("343947"), true)
	draw_rect(back, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, back.position + Vector2(0, 22), "← 返回标题",
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, Color("e6e2d8"))
	for i in 3:
		_draw_row(i, _row(i))
	draw_string(_font, Vector2(0, size.y - 28),
			"提示：Esc 菜单里的「音效：开/关」与这里同一份设置，两边同步。",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
			UiTheme.INK_ON_DARK)


func _draw_row(i: int, d: Dictionary) -> void:
	var r := _row_rect(i)
	var hov := i == _hover
	var on := bool(d["on"])
	draw_rect(r, Color("3a4152") if hov else Color("22242c"), true)
	draw_rect(r, Color("6a768c") if hov else Color("4a4e58"), false, 1.6)
	draw_string(_font_bold, r.position + Vector2(20, 27), str(d["title"]),
			HORIZONTAL_ALIGNMENT_LEFT, 160, UiTheme.FS_BODY, UiTheme.SAND)
	draw_string(_font, r.position + Vector2(20, 47), str(d["desc"]),
			HORIZONTAL_ALIGNMENT_LEFT, 360, UiTheme.FS_CAPTION, Color("9a968c"))
	# 右侧开关：药丸底 + 圆点（开 = 绿 / 关 = 灰），文字跟着走
	var sw := Rect2(r.position.x + r.size.x - 96.0, r.position.y + r.size.y / 2.0 - 15.0,
			76.0, 30.0)
	draw_rect(sw, Color("2f6b3a") if on else Color("3a3d46"), true)
	draw_rect(sw, Color("5aa06a") if on else Color("555a66"), false, 1.4)
	var knob_x := sw.position.x + (sw.size.x - 24.0 if on else 4.0)
	draw_circle(Vector2(knob_x + 10.0, sw.position.y + 15.0), 11.0,
			Color("d8f0dc") if on else Color("8b8f98"))
	draw_string(_font_bold, Vector2(sw.position.x - 46.0, sw.position.y + 21.0),
			"开" if on else "关", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_LABEL,
			Color("9fd7a5") if on else Color("8b8f98"))
