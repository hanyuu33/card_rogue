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
const SEED_H := 138.0     # R241：种子面板高度

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _hover := -1
var _last_mp := Vector2.INF
var _seed_edit: LineEdit = null   # R241「下一局种子」输入框（唯一的原生控件）
var _seed_guard := false          # 防止 text_changed 里改 text 触发二次回调


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
	_build_seed_edit()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续",
		"sub": "设置 · 按 Esc 返回",
	})


# ------------------------------------------------------------ 种子（R241）

func _seed_panel_rect() -> Rect2:
	## 三行开关下面的一块 —— 本局种子（只读）+ 下一局种子（可填）。
	var last := _row_rect(2)
	return Rect2(last.position.x, last.end.y + 22.0, ROW_W, SEED_H)


func _seed_edit_rect() -> Rect2:
	var p := _seed_panel_rect()
	return Rect2(p.position.x + 132.0, p.position.y + 62.0, 214.0, 34.0)


func _build_seed_edit() -> void:
	## 原生 LineEdit（手机上点它才会弹软键盘 —— 纯 _draw 的输入框做不到这件事）。
	GameSettings.ensure_loaded()
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "留空 = 随机"
	_seed_edit.max_length = 10
	_seed_edit.text = "" if GameSettings.next_seed == 0 else str(GameSettings.next_seed)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1b1d24")
	sb.border_color = Color("4a4e58")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	_seed_edit.add_theme_stylebox_override("normal", sb)
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = Color("23262f")
	sbf.border_color = Color("8f9ab4")
	sbf.set_border_width_all(1)
	sbf.set_corner_radius_all(4)
	sbf.content_margin_left = 8.0
	sbf.content_margin_right = 8.0
	_seed_edit.add_theme_stylebox_override("focus", sbf)
	_seed_edit.add_theme_font_override("font", _font)
	_seed_edit.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	_seed_edit.add_theme_color_override("font_color", Color("ece7db"))
	_seed_edit.add_theme_color_override("caret_color", UiTheme.SAND)
	_seed_edit.add_theme_color_override("placeholder_color", Color("7d8590"))
	_seed_edit.text_changed.connect(_on_seed_changed)
	add_child(_seed_edit)
	_sync_seed_edit()
	resized.connect(_sync_seed_edit)


func _sync_seed_edit() -> void:
	if _seed_edit == null:
		return
	var r := _seed_edit_rect()
	_seed_edit.position = r.position
	_seed_edit.size = r.size


func _on_seed_changed(txt: String) -> void:
	## 只收数字：粘贴 / 输入法带进来的其它字符当场剃掉。
	if _seed_guard:
		return
	var digits := ""
	for i in txt.length():
		var ch := txt[i]
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits != txt:
		_seed_guard = true
		_seed_edit.text = digits
		_seed_edit.caret_column = digits.length()
		_seed_guard = false
	GameSettings.set_next_seed(int(digits) if digits != "" else 0)
	queue_redraw()


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
	_draw_seed_panel()
	draw_string(_font, Vector2(0, size.y - 28),
			"提示：种子决定整局的地图 / 掉落 / 摇卡；同一种子新开一局可复现同一局。",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
			UiTheme.INK_ON_DARK)


func _draw_seed_panel() -> void:
	## R241：种子面板 —— ① 本局种子（只读，继续游戏会沿用它）② 下一局种子（可填）。
	var p := _seed_panel_rect()
	draw_rect(p, Color("22242c"), true)
	draw_rect(p, Color("4a4e58"), false, 1.6)
	draw_string(_font_bold, p.position + Vector2(20, 26), "随机种子",
			HORIZONTAL_ALIGNMENT_LEFT, 200, UiTheme.FS_BODY, UiTheme.SAND)
	var cur := "本局种子：%s" % RunState.seed_text()
	if not RunState.run_active:
		cur = "本局种子：—（当前没有进行中的对局）"
	draw_string(_font, p.position + Vector2(20, 50), cur,
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 40.0, UiTheme.FS_LABEL,
			Color("9fd7a5") if RunState.run_active else Color("9a968c"))
	draw_string(_font_bold, p.position + Vector2(20, 84), "下一局种子",
			HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_LABEL, Color("ece7db"))
	var tail := "当前：随机" if GameSettings.next_seed == 0 else "当前：%d" % GameSettings.next_seed
	draw_string(_font, p.position + Vector2(356, 84), tail,
			HORIZONTAL_ALIGNMENT_LEFT, 150, UiTheme.FS_CAPTION,
			Color("9a968c") if GameSettings.next_seed == 0 else Color("f0c860"))
	draw_string(_font, p.position + Vector2(20, 120),
			"留空 = 每局随机；填入数字 → 下一局用同一种子（用一次自动清空）",
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 40.0, UiTheme.FS_CAPTION, Color("7d8590"))


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
