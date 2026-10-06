extends Control
## 标题界面（肉鸽版）—— 标题 → 图鉴 / 录像回放 / 开始冒险。
## R58：移除了「卡牌奖励（演示）」「事件：休息（演示）」两个入口（开发调试用，正式流程已覆盖）。

var _bg_tex: Texture2D
var _back_tex: Texture2D
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
	_back_tex = load("res://assets/cardback.png")
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	sfx = Sfx.new()
	add_child(sfx)
	$Buttons/StartBtn.pressed.connect(_on_start)
	$Buttons/GalleryBtn.pressed.connect(_on_gallery)
	$Buttons/QuitBtn.pressed.connect(_on_quit)
	# 录像回放入口（R46）：插在「退出」之前
	var cjk := SystemFont.new()
	cjk.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	var rp_btn := Button.new()
	rp_btn.text = "录像回放"
	rp_btn.add_theme_font_override("font", cjk)
	rp_btn.add_theme_font_size_override("font_size", 20)
	$Buttons.add_child(rp_btn)
	$Buttons.move_child(rp_btn, $Buttons.get_child_count() - 2)
	rp_btn.pressed.connect(_on_replays)
	for b: Button in [$Buttons/StartBtn, $Buttons/GalleryBtn, $Buttons/QuitBtn]:
		b.pressed.connect(func(): sfx.play("click"))
	rp_btn.pressed.connect(func(): sfx.play("click"))
	_build_difficulty_row()
	# 回放中途回到标题（整局播完 / 中途退出）→ 停止回放状态
	if ReplayLog.playing:
		ReplayLog.stop_playback()
	# 漂浮卡背：随机初速/相位/大小，缓慢上飘
	for i in 6:
		_float_cards.append({
			"x": randf() * 1280.0,
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
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var label := Label.new()
	label.text = "难度档位"
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("3a4152"))
	row.add_child(label)
	for i in RunState.DIFFICULTY_COUNT:
		var b := Button.new()
		b.text = "%d · %s" % [i, RunState.DIFFICULTY_NAMES[i]]
		b.toggle_mode = true
		b.tooltip_text = RunState.DIFFICULTY_NOTES[i]
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 15)
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
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color("6a7280"))
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
			f.x = randf() * 1280.0
	queue_redraw()


func _draw() -> void:
	if _bg_tex != null:
		draw_texture_rect(_bg_tex, Rect2(Vector2.ZERO, size), false)
		# 半透明白色罩层，让按钮和标题更清晰
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.55))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("e9e7e2"))
	# 漂浮卡背（淡）+ 左右摇曳
	if _back_tex != null:
		for f: Dictionary in _float_cards:
			var pos := Vector2(float(f.x) + sin(_t * 0.7 + float(f.ph)) * 18.0, float(f.y))
			draw_set_transform(pos, float(f.rot), Vector2(float(f.sc), float(f.sc)))
			draw_texture_rect(_back_tex, Rect2(-29, -35, 58, 70), false,
					Color(0.25, 0.28, 0.38, 0.14))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 底部信息
	var ver := "v1.0-rogue · 肉鸽开发版"
	draw_string(_font, Vector2(size.x - 250, size.y - 16), ver,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8a8a8a"))
	draw_string(_font, Vector2(14, size.y - 16), "Godot 4.3 自包含副本",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8a8a8a"))


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
