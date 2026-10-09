extends Control
## 标题界面（肉鸽版）—— 标题 → 图鉴 / 录像回放 / 开始冒险。
## R58：移除了「卡牌奖励（演示）」「事件：休息（演示）」两个入口（开发调试用，正式流程已覆盖）。

const UiTheme = preload("res://scripts/ui_theme.gd")

var _bg_tex: Texture2D
var _font: SystemFont
var sfx: Sfx
var _t := 0.0
var _float_cards: Array = []    # {x, y, spd, ph, sc, rot}  漂浮卡背
var _diff_btns: Array = []      # 难度档位按钮（0 / 1 / 2）
var _diff_note: Label           # 当前档位说明


func _ready() -> void:
	# 窗口标题固定为游戏名：开发用的引擎是 debug 构建，默认会在标题后加
	# 「(DEBUG)」（打包成独立版后同样如此），这里显式覆盖掉。headless 下跳过。
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("卡牌肉鸽")
	_bg_tex = load("res://assets/battle_bg.png")
	_font = UiTheme.font()
	sfx = Sfx.new()
	add_child(sfx)
	$Buttons/StartBtn.pressed.connect(_on_start)
	$Buttons/GalleryBtn.pressed.connect(_on_gallery)
	$Buttons/QuitBtn.pressed.connect(_on_quit)
	# 录像回放入口（R46）：插在「退出」之前
	var rp_btn := Button.new()
	rp_btn.text = "录像回放"
	$Buttons.add_child(rp_btn)
	$Buttons.move_child(rp_btn, $Buttons.get_child_count() - 2)
	rp_btn.pressed.connect(_on_replays)
	for b: Button in [$Buttons/StartBtn, $Buttons/GalleryBtn, $Buttons/QuitBtn]:
		b.pressed.connect(func(): sfx.play("click"))
	rp_btn.pressed.connect(func(): sfx.play("click"))
	# R113 按钮主次：**一屏只有一个主按钮**（开始对战）。规格全部来自 UiTheme.apply_button，
	# 这里不写任何字号 / 圆角 / 颜色 —— 以后新界面照抄这几行即可。
	UiTheme.apply_button($Buttons/StartBtn, true)
	UiTheme.apply_button($Buttons/GalleryBtn, false)
	UiTheme.apply_button(rp_btn, false)
	UiTheme.apply_button($Buttons/QuitBtn, false)
	_build_difficulty_row()
	# 回放中途回到标题（整局播完 / 中途退出）→ 停止回放状态
	if ReplayLog.playing:
		ReplayLog.stop_playback()
	# 漂浮卡背：随机初速/相位/大小，缓慢上飘
	for i in 6:
		_float_cards.append({
			"x": _ghost_x(),
			"y": randf() * 720.0,
			"spd": randf_range(10.0, 26.0),
			"ph": randf() * TAU,
			"sc": randf_range(0.9, 1.8),
			"rot": randf_range(-0.22, 0.22),
		})
	# 命令行 -- --screenshot：打开后自动截图退出（视觉验证用）
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_title.png"))
			get_tree().quit())
		add_child(t)
		t.start()


func _ghost_x() -> float:
	## 幽灵卡的横向出生点：只在左右留白区，**永不压住居中的标题与按钮**。
	## （原先是 `randf() * 1280.0`，会随机落在标题/按钮正后方 —— 截图里能看到压字。）
	var m := UiTheme.GHOST_CARD_MARGIN
	var left := randf() < 0.5
	return (randf() * m if left else 1.0 - m + randf() * m) * size.x


func _build_difficulty_row() -> void:
	## 难度档位选择（R47）：0 宽松 / 1 标准 / 2 困难 —— 和角色一起在开局前定好。
	## 0 = 战斗+3 血、休息 40%；1 = 战斗不回血、休息 40%；2 = 战斗不回血、休息 25%（原状）。
	## 默认 0 档；选择只存在本次运行中（每次启动都从 0 档开始）。
	var row := HBoxContainer.new()
	row.name = "DiffRow"
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.offset_top = 306.0
	row.offset_bottom = 338.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTheme.SP_3)
	add_child(row)
	var label := Label.new()
	label.text = "难度档位"
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	# 行标签用次要色，让 chip 的选中态（深墨蓝）跳出来
	label.add_theme_color_override("font_color", UiTheme.INK_600)
	row.add_child(label)
	for i in RunState.DIFFICULTY_COUNT:
		var b := Button.new()
		b.text = "%d · %s" % [i, RunState.DIFFICULTY_NAMES[i]]
		b.toggle_mode = true
		b.tooltip_text = RunState.DIFFICULTY_NOTES[i]
		# R113：小切换按钮也走唯一口（此前是 Godot 默认样式，与主按钮不是一套）
		UiTheme.apply_chip(b)
		b.pressed.connect(_on_pick_difficulty.bind(i))
		row.add_child(b)
		_diff_btns.append(b)
	var note := Label.new()
	note.name = "DiffNote"
	note.anchor_left = 0.0
	note.anchor_right = 1.0
	note.offset_top = 338.0
	note.offset_bottom = 366.0
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", _font)
	note.add_theme_font_size_override("font_size", UiTheme.FS_CAPTION)
	note.add_theme_color_override("font_color", UiTheme.INK_600)
	add_child(note)
	_diff_note = note
	_refresh_difficulty()


func _on_pick_difficulty(d: int) -> void:
	RunState.set_difficulty(d)
	sfx.play("click")
	_refresh_difficulty()


func _refresh_difficulty() -> void:
	## 三个按钮的高亮 = 当前档位（点按钮只改档位，不改动其它状态）。
	for i in _diff_btns.size():
		_diff_btns[i].button_pressed = i == RunState.difficulty
	if _diff_note != null:
		_diff_note.text = "当前：难度 %d · %s —— %s" % [RunState.difficulty,
				RunState.difficulty_name(), RunState.difficulty_note()]


func _process(delta: float) -> void:
	_t += delta
	for f: Dictionary in _float_cards:
		f.y -= float(f.spd) * delta
		if float(f.y) < -110.0:
			f.y = 830.0
			f.x = _ghost_x()
	queue_redraw()


func _draw() -> void:
	if _bg_tex != null:
		draw_texture_rect(_bg_tex, Rect2(Vector2.ZERO, size), false)
		# 半透明白色罩层，让按钮和标题更清晰
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.OVERLAY_TITLE)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BOARD_BG)
	# 幽灵卡母题（R113）：浅色卡 + 描边，只出现在左右留白区。
	# 这里**故意不用** cardback.png —— 深海军蓝贴图在浅米黄底上，任何低透明度都会兑成中灰，
	# 菱形花纹的对比度被同比例压缩，最后只剩一个「灰色占位块」。详见 ui_theme.gd 的注释。
	for f: Dictionary in _float_cards:
		var pos := Vector2(float(f.x) + sin(_t * 0.7 + float(f.ph)) * 18.0, float(f.y))
		draw_set_transform(pos, float(f.rot), Vector2(float(f.sc), float(f.sc)))
		draw_rect(Rect2(-29, -35, 58, 70), UiTheme.GHOST_CARD_FILL)
		draw_rect(Rect2(-29, -35, 58, 70), UiTheme.GHOST_CARD_LINE, false, 1.0)
		draw_rect(Rect2(-22, -28, 44, 56), UiTheme.GHOST_CARD_INNER, false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 底部信息
	var ver := "v1.0-rogue · 肉鸽开发版"
	draw_string(_font, Vector2(size.x - 250, size.y - 16), ver,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_CAPTION, UiTheme.INK_500)
	draw_string(_font, Vector2(14, size.y - 16), "Godot 4.3 自包含副本",
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_CAPTION, UiTheme.INK_500)


func _on_start() -> void:
	## 开始肉鸽 run：先选角色（角色决定初始卡组追加卡 + 战斗赠品道具）→
	## 满血 + 初始卡组 + 生成 14 层地图（第一层，含第 6 层宝箱层 + 第 9 层固定休息层）→ 进冒险地图。
	## 地图层级决定本局出现的战斗关卡与事件（见 GameLayers）。
	get_tree().change_scene_to_file("res://scenes/class_pick.tscn")


func _on_gallery() -> void:
	get_tree().change_scene_to_file("res://scenes/gallery.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _on_replays() -> void:
	get_tree().change_scene_to_file("res://scenes/replay_list.tscn")
