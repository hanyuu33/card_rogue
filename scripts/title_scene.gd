extends Control
## 标题界面（肉鸽版）—— 开始冒险 / 继续 / 图鉴 / 对战记录 / 设置 / 退出。
## R58：移除了「卡牌奖励（演示）」「事件：休息（演示）」两个入口（开发调试用，正式流程已覆盖）。

const UiTheme = preload("res://scripts/ui_theme.gd")

var _bg_tex: Texture2D
var _font: Font
var sfx: Sfx
var _t := 0.0
var _petals: Array = []         # {x, y, spd, ph, sc, rot, kind}  R154 飘落花瓣 / 光尘（换掉漂浮白方块）



func _ready() -> void:
	# 窗口标题固定为游戏名：开发用的引擎是 debug 构建，默认会在标题后加
	# 「(DEBUG)」（打包成独立版后同样如此），这里显式覆盖掉。headless 下跳过。
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("卡牌肉鸽")
	# R154：标题页专用背景（晨光小镇）；缺图回退战斗背景 → 再退纯色（_draw 里的 BOARD_BG）
	_bg_tex = UiAssets.title_bg()
	if _bg_tex == null:
		_bg_tex = load("res://assets/battle_bg.png")
	_font = UiTheme.font()
	sfx = Sfx.new()
	add_child(sfx)
	# R176：标题页 BGM（Holy_Place）；选人 / 地图 / 战斗各自在进入时换曲。
	Bgm.play("title")
	$Buttons/StartBtn.pressed.connect(_on_start)
	$Buttons/GalleryBtn.pressed.connect(_on_gallery)
	$Buttons/QuitBtn.pressed.connect(_on_quit)
	# R215：「录像回放」整块删掉（回放机制不再维护），换成只记结果的「对战记录」；
	# 同时补上原来缺失的「设置」入口。两者都插在「退出」之前。
	var rec_btn := Button.new()
	rec_btn.text = "对战记录"
	rec_btn.tooltip_text = "每局的最终结果（通关 / 失败 / 中断）"
	$Buttons.add_child(rec_btn)
	rec_btn.pressed.connect(_on_records)
	var set_btn := Button.new()
	set_btn.text = "设置"
	set_btn.tooltip_text = "音效 / 音乐 / 全屏"
	$Buttons.add_child(set_btn)
	set_btn.pressed.connect(_on_settings)
	# R346：剧情解锁入口 —— 条件达成后点开剧情，收下里面解锁的卡牌 / 道具。
	var story_btn := Button.new()
	story_btn.text = "查看故事"
	story_btn.tooltip_text = "成就解锁的剧情；看完会解锁新的卡牌 / 道具"
	$Buttons.add_child(story_btn)
	story_btn.pressed.connect(_on_story)
	# 续档入口（"继续游戏"）：有本地存档才显示，放在「开始」之后。
	var cont_btn := Button.new()
	cont_btn.text = "继续游戏"
	$Buttons.add_child(cont_btn)
	cont_btn.pressed.connect(_on_continue)
	cont_btn.visible = RunSave.has_save()
	# 顺序固定：开始 / 继续 / 图鉴 / 记录 / 故事 / 设置 / 退出
	$Buttons.move_child(cont_btn, 1)
	$Buttons.move_child(rec_btn, 3)
	$Buttons.move_child(story_btn, 4)
	$Buttons.move_child(set_btn, 5)
	$Buttons.move_child($Buttons/QuitBtn, 6)
	for b: Button in [$Buttons/StartBtn, $Buttons/GalleryBtn, $Buttons/QuitBtn,
			cont_btn, rec_btn, set_btn, story_btn]:
		b.pressed.connect(func(): sfx.play("click"))
	# R113 按钮主次：**一屏只有一个主按钮**（开始对战）。规格全部来自 UiTheme.apply_button，
	# 这里不写任何字号 / 圆角 / 颜色 —— 以后新界面照抄这几行即可。
	UiTheme.apply_button($Buttons/StartBtn, true)
	UiTheme.apply_button($Buttons/GalleryBtn, false)
	UiTheme.apply_button(cont_btn, false)
	UiTheme.apply_button($Buttons/QuitBtn, false)
	UiTheme.apply_button(rec_btn, false)
	UiTheme.apply_button(set_btn, false)
	UiTheme.apply_button(story_btn, false)
	# R166：难度档位不再在标题页选 —— 挪到角色选择界面（class_pick_scene）。
	# R215：设置（音效 / 音乐 / 全屏）按上次保存的值套上；上次启动留下的「没打完的一局」
	# 在这里补记成「中断」（关窗口 / 崩溃都算）。
	GameSettings.ensure_loaded()
	GameSettings.apply_display()
	RunRecord.recover()
	# R154：飘落花瓣 + 光尘（替换「漂浮白方块」—— 浅色卡背贴在浅底上只剩一个灰色占位块，
	# UI 检视报告点名它像没删干净的占位符）。花瓣缓慢下落、横向轻摆；光尘微微闪烁。
	for i in 14:
		_petals.append({
			"x": randf() * 1280.0,
			"y": randf() * 720.0,
			"spd": randf_range(14.0, 34.0),
			"ph": randf() * TAU,
			"sc": randf_range(0.7, 1.5),
			"rot": randf() * TAU,
			"kind": (1 if i % 4 == 0 else 0),   # 1/4 光尘，其余花瓣
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


func _process(delta: float) -> void:
	_t += delta
	for f: Dictionary in _petals:
		f.y += float(f.spd) * delta
		if float(f.y) > 770.0:
			f.y = -30.0
			f.x = randf() * 1280.0
	queue_redraw()


func _draw() -> void:
	if _bg_tex != null:
		draw_texture_rect(_bg_tex, Rect2(Vector2.ZERO, size), false)
		# 半透明白色罩层，让按钮和标题更清晰
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.OVERLAY_TITLE)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BOARD_BG)
	# R154：飘落花瓣（两瓣错开的扁椭圆）+ 光尘（四点小星、明灭）。低透明度，可全屏飘。
	for f: Dictionary in _petals:
		var pos := Vector2(float(f.x) + sin(_t * 0.8 + float(f.ph)) * 16.0, float(f.y))
		var sc := float(f.sc)
		var rot := float(f.rot) + sin(_t * 0.9 + float(f.ph)) * 0.35
		if int(f.kind) == 1:
			# 光尘：四点小星，alpha 呼吸
			var a := 0.28 + 0.22 * sin(_t * 2.2 + float(f.ph))
			var col := Color(1.0, 0.95, 0.75, a)
			var r := 3.2 * sc
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0, -r * 1.6), pos + Vector2(r * 0.55, 0),
				pos + Vector2(0, r * 1.6), pos + Vector2(-r * 0.55, 0)]), col)
		else:
			var col: Color = PETAL_COLORS[int(f.ph * 7.0) % PETAL_COLORS.size()]
			draw_set_transform(pos, rot, Vector2(sc, sc * 0.58))
			draw_circle(Vector2.ZERO, 7.0, col)
			draw_set_transform(pos + Vector2(cos(rot), sin(rot)) * 4.5 * sc, rot + 0.9,
					Vector2(sc * 0.7, sc * 0.42))
			draw_circle(Vector2.ZERO, 6.0, Color(col, col.a * 0.85))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# R154：标题两侧的金线卷草（程序画）—— 描金标题在 title.tscn 用 font_outline 做。
	_draw_title_ornaments()
	# 底部信息
	var ver := "v1.0-rogue · 肉鸽开发版"
	draw_string(_font, Vector2(size.x - 250, size.y - 16), ver,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_CAPTION, UiTheme.INK_500)
	draw_string(_font, Vector2(14, size.y - 16), "Godot 4.3 自包含副本",
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_CAPTION, UiTheme.INK_500)


const PETAL_COLORS: Array[Color] = [
	Color(1.00, 0.83, 0.86, 0.52),   # 樱粉
	Color(1.00, 0.93, 0.80, 0.48),   # 奶油
	Color(0.98, 0.87, 0.68, 0.44),   # 淡金
]


func _draw_title_ornaments() -> void:
	## 标题「卡 牌 肉 鸽」两侧的金线卷草：金线 + 外端小菱 + 内端小珠，左右对称。
	var cy := 205.0
	var tw := _font.get_string_size("卡 牌 肉 鸽", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	var gold := Color("c8951c")
	var gold_soft := Color(0.784, 0.584, 0.11, 0.55)
	for side: float in [-1.0, 1.0]:
		var xi: float = size.x * 0.5 + side * (tw * 0.5 + 30.0)   # 内端（贴标题）
		var xo: float = xi + side * 96.0                          # 外端
		draw_line(Vector2(xi, cy), Vector2(xo, cy), gold_soft, 4.0)
		draw_line(Vector2(xi, cy), Vector2(xo, cy), gold, 1.6)
		# 外端小菱
		var d := Vector2(xo, cy)
		draw_colored_polygon(PackedVector2Array([
			d + Vector2(0, -5.5), d + Vector2(4.0, 0),
			d + Vector2(0, 5.5), d + Vector2(-4.0, 0)]), gold)
		# 内端小珠
		draw_circle(Vector2(xi, cy), 2.6, gold)


func _on_start() -> void:
	## 开始肉鸽 run：先选角色（角色决定初始卡组追加卡 + 战斗赠品道具）→
	## 满血 + 初始卡组 + 生成 14 层地图（第一层，含第 6 层宝箱层 + 第 9 层固定休息层）→ 进冒险地图。
	## 地图层级决定本局出现的战斗关卡与事件（见 GameLayers）。
	RunSave.clear_save()   # 开新局 = 弃旧档（旧的"继续游戏"存档随之作废）
	SceneFx.goto("res://scenes/class_pick.tscn")


func _on_continue() -> void:
	## 继续游戏：读本地存档恢复当前局 → 进冒险地图（地图场景按存档状态自行路由）。
	if not RunSave.load_run():
		push_warning("RunSave：继续游戏读档失败，留在标题")
		return
	RunRecord.resume()   # 这一局接着打 → 保证有开始时间（对战记录收尾时才写得出来）
	# R323：存档若停在**一场没打完的战斗**里 → 直接回那一场；
	# 回地图的话，那一格早在进战斗时就被标成「已走过」，这场就永远打不到了。
	if not RunState.resume_battle.is_empty():
		SceneFx.goto("res://scenes/battle.tscn")
		return
	SceneFx.goto("res://scenes/map.tscn")


func _on_gallery() -> void:
	SceneFx.goto("res://scenes/gallery.tscn")


func _on_quit() -> void:
	## 还有一局没结束就退出 → 对战记录立刻补一条「中断」（不留到下次启动再猜）。
	RunRecord.finish("interrupted")
	get_tree().quit()


func _on_records() -> void:
	SceneFx.goto("res://scenes/record_list.tscn")


func _on_story() -> void:
	## R346：剧情解锁界面（条件达成的条目可以点开，看完收下解锁的卡牌 / 道具）。
	SceneFx.goto("res://scenes/story.tscn")


func _on_settings() -> void:
	SceneFx.goto("res://scenes/settings.tscn")
