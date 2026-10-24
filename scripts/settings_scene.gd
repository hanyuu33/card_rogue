extends Control
## 设置页（R215）—— 音效 / 音乐 / 全屏。三项都**立刻生效并记住**（GameSettings）。
## R246：音效 / 音乐各加一行**音量**（− / + 或点条直接定位，10% 一档；同样即时生效并记住）。
##
## 入口：标题页「设置」按钮。之所以单开一页而不是塞进标题页：标题页是按钮栈
## （`Buttons` 容器），塞开关进去会把一屏一个主按钮的层次搞乱。

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_W := 520.0
const ROW_H := 54.0        # R246：5 行（3 开关 + 2 音量）要塞进原来 3 行的位置
const ROW_GAP := 10.0
const ROW_COUNT := 5
const LIST_Y := 190.0
const SEED_H := 138.0     # R241：种子面板高度
const VOL_STEP := 0.1      # R246：音量一档 10%
const VOL_NUM := 20

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _hover := -1
var _last_mp := Vector2.INF
var _seed_edit: LineEdit = null   # R241「下一局种子」输入框（唯一的原生控件）
var _seed_guard := false          # 防止 text_changed 里改 text 触发二次回调
var _seed_hover := false          # R325：「复制」按钮的悬停态（自绘按钮要自己记）


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
		"sub": "设置",
	})


# ------------------------------------------------------------ 种子（R241）

func _seed_panel_rect() -> Rect2:
	## 三行开关下面的一块 —— 本局种子（只读）+ 下一局种子（可填）。
	var last := _row_rect(ROW_COUNT - 1)
	return Rect2(last.position.x, last.end.y + 22.0, ROW_W, SEED_H)


func _seed_copy_rect() -> Rect2:
	## R325：种子面板右上角的「复制」按钮（跟在「本局种子」一行的右端）。
	var p := _seed_panel_rect()
	return Rect2(p.position.x + p.size.x - 92.0, p.position.y + 30.0, 72.0, 26.0)


func _seed_copy_text() -> String:
	## 复制什么：优先**本局种子**（有进行中的对局时）；
	## 没有对局就退回「下一局种子」——那串码同样值得抄出去分享 / 复现。
	if RunState.run_active and RunState.run_seed != 0:
		return RunState.seed_text()
	return GameSettings.next_seed_code


func _copy_seed() -> void:
	## R325：种子写进**系统剪贴板**。`DisplayServer.clipboard_set` 在桌面与安卓是同一口
	## （安卓走 JNI 的 ClipboardManager），所以手机上复制完直接长按粘贴就行。
	var code := _seed_copy_text()
	if code == "":
		UiToast.toast("还没有可复制的种子：先开一局，或在下面填「下一局种子」")
		return
	DisplayServer.clipboard_set(code)
	UiToast.toast("已复制种子 %s" % code)


func _seed_edit_rect() -> Rect2:
	var p := _seed_panel_rect()
	return Rect2(p.position.x + 132.0, p.position.y + 62.0, 214.0, 34.0)


func _build_seed_edit() -> void:
	## 原生 LineEdit（手机上点它才会弹软键盘 —— 纯 _draw 的输入框做不到这件事）。
	GameSettings.ensure_loaded()
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "留空 = 随机（10 位）"
	_seed_edit.max_length = RunState.SEED_LEN
	_seed_edit.text = GameSettings.next_seed_code
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
	## R261：只收 **A-Z / 0-9**（小写自动转大写）—— 粘贴 / 输入法带进来的其它字符当场剃掉。
	## 半截串（不足 10 位）先留在框里让人继续打，落盘只会是合法码或空（见 set_next_seed_code）。
	if _seed_guard:
		return
	var code := ""
	for i in txt.length():
		var ch := txt[i].to_upper()
		if RunState.SEED_ALPHABET.find(ch) >= 0:
			code += ch
	if code != txt:
		_seed_guard = true
		_seed_edit.text = code
		_seed_edit.caret_column = code.length()
		_seed_guard = false
	GameSettings.set_next_seed_code(code)
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
	var total := float(ROW_COUNT) * ROW_H + float(ROW_COUNT - 1) * ROW_GAP
	var y := LIST_Y + (320.0 - total) * 0.35
	return Rect2((size.x - ROW_W) / 2.0, y + i * (ROW_H + ROW_GAP), ROW_W, ROW_H)


func _vol_rects(r: Rect2) -> Array[Rect2]:
	## R246 音量行右侧的几何唯一口（画与点共用）：[−][条][+]。
	var cy := r.position.y + r.size.y / 2.0
	return [
		Rect2(r.position.x + r.size.x - 300.0, cy - 16.0, 32.0, 32.0),
		Rect2(r.position.x + r.size.x - 260.0, cy - 7.0, 118.0, 14.0),
		Rect2(r.position.x + r.size.x - 134.0, cy - 16.0, 32.0, 32.0),
	]


func _back_rect() -> Rect2:
	return Rect2(14, 14, 110, 34)


func _row_at(pos: Vector2) -> int:
	for i in ROW_COUNT:
		if _row_rect(i).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _row_at(event.position)
		var sh := _seed_copy_rect().has_point(event.position)
		if h != _hover or sh != _seed_hover:
			_hover = h
			_seed_hover = sh
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back_to_title()
			return
		if _seed_copy_rect().has_point(event.position):
			if _seed_copy_text() != "":
				sfx.play("click")
			_copy_seed()
			queue_redraw()
			return
		var i := _row_at(event.position)
		if i >= 0:
			if str(_row(i).get("kind", "toggle")) == "volume":
				var vr := _vol_rects(_row_rect(i))
				if vr[0].has_point(event.position):
					sfx.play("click")
					_nudge_volume(i, -VOL_STEP)
					return
				if vr[2].has_point(event.position):
					sfx.play("click")
					_nudge_volume(i, VOL_STEP)
					return
				if vr[1].grow(8.0).has_point(event.position):
					# 点条上任意位置直接定位（条本身就是滑块）
					sfx.play("click")
					_set_volume(i, (event.position.x - vr[1].position.x) / vr[1].size.x)
					return
				return   # 点行进空白处：不动作（别把音量行当成开关翻掉）
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
		2:
			GameSettings.set_music_on(not GameSettings.music_on)
			Bgm.set_enabled(GameSettings.music_on)
			if GameSettings.music_on:
				Bgm.play("title")   # 当场就有反馈（否则要等下一次切场景才响）
		4:
			GameSettings.set_fullscreen(not GameSettings.fullscreen)
	queue_redraw()


func _nudge_volume(i: int, delta: float) -> void:
	## R246：− / + 按一档（10%）步进，并对齐到整档（避免 10% 累积出 0.30000001）。
	var cur := _volume_of(i)
	var steps := roundf((cur + delta) * float(VOL_NUM))
	_set_volume(i, steps / float(VOL_NUM))


func _volume_of(i: int) -> float:
	GameSettings.ensure_loaded()
	return GameSettings.sfx_volume if i == 1 else GameSettings.music_volume


func _set_volume(i: int, v: float) -> void:
	## 唯一落地点：写设置 + 落到正在播的实例 + 重绘（两档音量共用）。
	var nv := clampf(v, 0.0, 1.0)
	nv = roundf(nv * float(VOL_NUM)) / float(VOL_NUM)   # 吸附到 5% 网格（点条也整齐）
	if i == 1:
		GameSettings.set_sfx_volume(nv)
		sfx.volume = nv
		if nv > 0.0:
			sfx.play("click")   # 当场听到新音量
	else:
		GameSettings.set_music_volume(nv)
		Bgm.set_volume(nv)
	queue_redraw()


func _back_to_title() -> void:
	SceneFx.goto("res://scenes/title.tscn")


# ------------------------------------------------------------ 绘制

func _row(i: int) -> Dictionary:
	GameSettings.ensure_loaded()
	match i:
		0:
			return {"title": "音效", "desc": "点击 / 出牌 / 攻击等提示音",
					"kind": "toggle", "on": GameSettings.sfx_on}
		1:
			return {"title": "音效音量", "desc": "点 − / + 调整",
					"kind": "volume", "val": GameSettings.sfx_volume}
		2:
			return {"title": "音乐", "desc": "背景音乐（标题 / 地图 / 战斗各自换曲）",
					"kind": "toggle", "on": GameSettings.music_on}
		3:
			return {"title": "音乐音量", "desc": "点 − / + 调整",
					"kind": "volume", "val": GameSettings.music_volume}
	return {"title": "全屏", "desc": "关掉则使用窗口模式（默认窗口）",
			"kind": "toggle", "on": GameSettings.fullscreen}


func _draw() -> void:
	var top := Color("1c1f28")
	var bottom := Color("303443")
	for i in 36:
		var t := float(i) / 35.0
		draw_rect(Rect2(0, size.y * float(i) / 36.0, size.x, size.y / 36.0 + 1.0),
				top.lerp(bottom, t), true)
	draw_string(_font_bold, Vector2(0, 78), "设 置",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, UiTheme.SAND)
	draw_string(_font, Vector2(0, 110), "所有设置自动保存",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	draw_rect(back, Color("414860") if hov_back else Color("343947"), true)
	draw_rect(back, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, back.position + Vector2(0, 22), "← 返回标题",
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, Color("e6e2d8"))
	for i in ROW_COUNT:
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
	var next_code := GameSettings.next_seed_code
	var tail := "当前：随机" if next_code == "" else "当前：%s" % next_code
	draw_string(_font, p.position + Vector2(356, 84), tail,
			HORIZONTAL_ALIGNMENT_LEFT, 150, UiTheme.FS_CAPTION,
			Color("9a968c") if next_code == "" else Color("f0c860"))
	draw_string(_font, p.position + Vector2(20, 120),
			"留空 = 每局随机；填入 10 位大写字母 / 数字 → 下一局用同一种子（用一次自动清空）",
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 40.0, UiTheme.FS_CAPTION, Color("7d8590"))
	# R325：一键复制 —— 10 位码手抄太容易错一位（抄错 = 复现不出同一局）。
	# 按钮紧跟「本局种子」一行右端；没有可复制的码时置灰并吞掉点击。
	var cr := _seed_copy_rect()
	var can_copy := _seed_copy_text() != ""
	var hov := _seed_hover and can_copy
	draw_rect(cr, Color("414860") if hov else Color("2b2e38"), true)
	draw_rect(cr, Color("8a93a6") if hov else Color("4a4e58"), false, 1.4)
	draw_string(_font_bold, cr.position + Vector2(0, 18), "复制",
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, UiTheme.FS_CAPTION,
			Color("f0ece2") if can_copy else Color("63687a"))


func _draw_row(i: int, d: Dictionary) -> void:
	var r := _row_rect(i)
	var hov := i == _hover
	draw_rect(r, Color("3a4152") if hov else Color("22242c"), true)
	draw_rect(r, Color("6a768c") if hov else Color("4a4e58"), false, 1.6)
	draw_string(_font_bold, r.position + Vector2(20, 24), str(d["title"]),
			HORIZONTAL_ALIGNMENT_LEFT, 160, UiTheme.FS_BODY, UiTheme.SAND)
	var is_vol := str(d.get("kind", "toggle")) == "volume"
	draw_string(_font, r.position + Vector2(20, 43), str(d["desc"]),
			HORIZONTAL_ALIGNMENT_LEFT, 190.0 if is_vol else 360, UiTheme.FS_CAPTION,
			Color("9a968c"))
	if is_vol:
		_draw_volume_row(r, float(d.get("val", 1.0)))
		return
	var on := bool(d["on"])
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


func _draw_volume_row(r: Rect2, val: float) -> void:
	## R246：音量行右侧 = [−][滑条][+][ 80% ]。三块几何走 `_vol_rects`（与点击同一份）。
	var vr := _vol_rects(r)
	var mp := get_local_mouse_position()
	for k in [0, 2]:
		var b: Rect2 = vr[k]
		var hb := b.has_point(mp)
		draw_rect(b, Color("4a5164") if hb else Color("343947"), true)
		draw_rect(b, Color("7d8aa4") if hb else Color("4a4e58"), false, 1.4)
		draw_string(_font_bold, b.position + Vector2(0, 22), "−" if k == 0 else "+",
				HORIZONTAL_ALIGNMENT_CENTER, b.size.x, UiTheme.FS_BODY, Color("e6e2d8"))
	var bar: Rect2 = vr[1]
	draw_rect(bar, Color("1b1d24"), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(val, 0.0, 1.0), bar.size.y)),
			UiTheme.SAND, true)
	draw_rect(bar, Color("4a4e58"), false, 1.2)
	draw_string(_font_bold, Vector2(r.position.x + r.size.x - 92.0, bar.position.y + 13.0),
			"%d%%" % int(roundf(val * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, 76,
			UiTheme.FS_LABEL, Color("f0c860") if val > 0.0 else Color("8b8f98"))
