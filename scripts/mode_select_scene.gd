extends Control
## R762：开始游戏后的模式选择。标准模式仍进原选人页；每日模式固定配置直接开局。
## 本页也展示本地成绩与 Steam 前十；任何网络失败都不挡住两个开局按钮。

const UiTheme = preload("res://scripts/ui_theme.gd")

var _font: Font
var _font_bold: Font
var _cfg: Dictionary = {}
var _attempt: Dictionary = {}
var _daily_btn: Button
var _steam_btn: Button
var _steam_entries: Array = []
var _steam_status := ""
var _board_request: DailyLeaderboard = null


func _ready() -> void:
	UiTheme.attach_stage(self)
	GameSettings.ensure_loaded()   # --lang=en 等出图覆盖只改本进程，不写玩家设置
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	Bgm.play("class_pick")
	_cfg = DailyChallenge.config_for_date(DailyChallenge.today())
	_attempt = DailyChallenge.attempt_for(str(_cfg.get("date", "")))
	_steam_status = _t("DAILY_STEAM_IDLE", "连接后读取今日前十")
	_make_buttons()
	_start_day_watch()
	# R767：这一页停留时间短，按「马上就会用到」的顺序排队：
	# 选人场景 → 默认选中职业的 CG（整屏背景，最贵的一张）→ 头像 → 地图。
	# 队列前面几个基本能在玩家点按钮前读完，安卓上就不会在切场景时黑屏卡住。
	SceneWarm.warm_all([
		"res://scenes/class_pick.tscn",
		UiAssets.path_for("class_cg_" + UiAssets.class_key(str(_cfg.get("class", "")))),
		"res://assets/ui/class_cg_forest.png",
		"res://assets/ui/class_avatar_forest.png",
		"res://assets/ui/class_avatar_rogue.png",
		"res://assets/ui/class_avatar_mech.png",
		"res://scenes/map.tscn",
	])
	if "--screenshot" in OS.get_cmdline_user_args():
		var timer := Timer.new()
		timer.wait_time = 0.6
		timer.one_shot = true
		timer.timeout.connect(func():
			get_viewport().get_texture().get_image().save_png(
					ProjectSettings.globalize_path("res://screenshot_mode_select.png"))
			get_tree().quit())
		add_child(timer)
		timer.start()


func _t(key: String, fallback: String) -> String:
	return GameI18n.ui("shell", key, fallback)


func _make_buttons() -> void:
	var back := Button.new()
	back.text = "← " + _t("MODE_BACK", "返回标题")
	back.position = Vector2(20, 20)
	back.custom_minimum_size = Vector2(150, 40)
	UiTheme.apply_button(back)
	back.pressed.connect(func(): SceneFx.goto("res://scenes/title.tscn"))
	add_child(back)

	var standard := Button.new()
	standard.text = _t("MODE_STANDARD_START", "标准模式 · 选择角色")
	standard.position = Vector2(170, 460)
	standard.custom_minimum_size = Vector2(360, 56)
	standard.size = standard.custom_minimum_size
	UiTheme.apply_button(standard, true)
	standard.pressed.connect(func(): SceneFx.goto("res://scenes/class_pick.tscn"))
	add_child(standard)

	_daily_btn = Button.new()
	_daily_btn.custom_minimum_size = Vector2(360, 56)
	_daily_btn.size = _daily_btn.custom_minimum_size
	_daily_btn.position = Vector2(750, 460)
	UiTheme.apply_button(_daily_btn, true)
	_daily_btn.pressed.connect(_start_daily)
	add_child(_daily_btn)
	_sync_daily_button()

	_steam_btn = Button.new()
	_steam_btn.text = _t("DAILY_STEAM_REFRESH", "刷新")
	_steam_btn.position = Vector2(1000, 572)
	_steam_btn.custom_minimum_size = Vector2(140, 30)
	_steam_btn.size = _steam_btn.custom_minimum_size
	UiTheme.apply_button(_steam_btn)
	_steam_btn.disabled = not SteamAchievements.is_ready()
	_steam_btn.pressed.connect(_request_steam_board)
	add_child(_steam_btn)


func _sync_daily_button() -> void:
	_daily_btn.disabled = not _attempt.is_empty()
	_daily_btn.text = (_t("DAILY_USED", "今日已挑战") if not _attempt.is_empty()
			else _t("DAILY_START", "开始今日挑战"))


func _start_day_watch() -> void:
	## R850：这一页可能一直是同一份场景（挂着过夜、或者早上才回来接着看）。
	## 日界一跳就整页重取，别让昨天的「今日已挑战」压着新的一天。
	var t := Timer.new()
	t.name = "DayWatch"
	t.wait_time = 20.0
	t.timeout.connect(_sync_day)
	add_child(t)
	t.start()


func _sync_day() -> void:
	var date := DailyChallenge.today()
	if date == str(_cfg.get("date", "")):
		return
	_cfg = DailyChallenge.config_for_date(date)
	_attempt = DailyChallenge.attempt_for(date)
	_steam_entries = []
	_steam_status = _t("DAILY_STEAM_IDLE", "连接后读取今日前十")
	_sync_daily_button()
	queue_redraw()


func _start_daily() -> void:
	# 先消耗今日次数，再建局；重进程序不能刷新。已有局由标题「继续游戏」恢复。
	if not DailyChallenge.begin_attempt(_cfg):
		_attempt = DailyChallenge.attempt_for(str(_cfg.get("date", "")))
		_sync_daily_button()
		return
	RunState.set_difficulty(int(_cfg.get("difficulty", DailyChallenge.FIXED_DIFFICULTY)))
	RunState.start_run([], GameLayers.LAYER_DEFAULT, str(_cfg.get("class", "")),
			int(_cfg.get("seed", 0)), "", _cfg)
	RunRecord.begin_run(str(_cfg.get("class", "")))
	SceneFx.goto("res://scenes/map.tscn")


func _request_steam_board() -> void:
	if _board_request != null and is_instance_valid(_board_request):
		return
	_steam_entries = []
	_steam_status = _t("DAILY_STEAM_LOADING", "正在读取……")
	_steam_btn.disabled = true
	_board_request = DailyLeaderboard.request_board(self, str(_cfg.get("date", "")),
			int(_cfg.get("rules", DailyChallenge.RULES_VERSION)))
	if _board_request == null:
		_steam_status = _t("DAILY_STEAM_OFFLINE", "Steam 未连接 · 本地成绩仍保留")
		_steam_btn.disabled = false
		queue_redraw()
		return
	# R850：请求跨过日界就作废 —— 迟到的榜属于昨天那张卡，别糊到今天的页面上。
	var req_date := str(_cfg.get("date", ""))
	_board_request.board_ready.connect(func(entries: Array):
		if req_date != str(_cfg.get("date", "")):
			_board_request = null
			return
		_steam_entries = entries
		_steam_status = ""
		_steam_btn.disabled = false
		queue_redraw())
	_board_request.board_failed.connect(func(reason: String):
		if req_date != str(_cfg.get("date", "")):
			_board_request = null
			return
		_steam_status = _t("DAILY_STEAM_FAILED", "读取失败 · 不影响本地成绩") + " (" + reason + ")"
		_steam_btn.disabled = false
		queue_redraw())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		SceneFx.goto("res://scenes/title.tscn")
		get_viewport().set_input_as_handled()


func _draw() -> void:
	UiTheme.draw_page(self, UiTheme.bleed_rect(self))
	draw_string(_font_bold, Vector2(0, 82), _t("MODE_TITLE", "选择游戏模式"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_TITLE, UiTheme.PAGE_INK)
	draw_string(_font, Vector2(0, 112), _t("MODE_SUBTITLE", "自由构筑，或挑战今天所有人相同的一局"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)

	var sr := Rect2(120, 145, 460, 390)
	var dr := Rect2(700, 145, 460, 390)
	UiTheme.draw_panel_bg(self, sr)
	UiTheme.draw_panel_bg(self, dr)
	draw_string(_font_bold, Vector2(150, 202), _t("MODE_STANDARD", "标准模式"),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	draw_string(_font_bold, Vector2(730, 202), _t("MODE_DAILY", "每日挑战"),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	_wrapped(_t("MODE_STANDARD_DESC", "自选角色与难度，也可输入种子。\n卡组、道具和剧情进度按标准规则累积。"),
			Vector2(150, 242), 395)
	var date := str(_cfg.get("date", ""))
	var cid := str(_cfg.get("class", ""))
	var seed_code := RunState.seed_text_of(int(_cfg.get("seed", 0)))
	var lines := [
		date + " · " + _t("DAILY_CLASS", "固定角色") + "：" + PlayerClass.name_of(cid),
		_t("DAILY_DIFFICULTY", "固定难度") + "：%d · %s" % [
				int(_cfg.get("difficulty", 2)), _t("DAILY_DIFFICULTY_NAME_2", "严酷")]
				+ " · " + _t("DAILY_DECK", "卡组") + "：" + DailyModifiers.deck_label(),
		_t("DAILY_SEED", "今日种子") + "：" + seed_code,
	]
	var y := 246.0
	for line: String in lines:
		for wrapped: String in TextWrap.wrap_plain(_font, line, 420, UiTheme.FS_BODY):
			draw_string(_font, Vector2(730, y), wrapped, HORIZONTAL_ALIGNMENT_LEFT, 420,
					UiTheme.FS_BODY, UiTheme.PAGE_INK)
			y += 24.0
		y += 4.0
	# R767：今日四条修正（2 增益 + 2 减益）。名称按性质上色，效果只写数值 ——
	# 玩家扫一眼就知道今天是「爽局」还是「苦局」，不用点进去试。
	draw_string(_font_bold, Vector2(730, y + 8.0), _t("DAILY_MODS", "今日修正"),
			HORIZONTAL_ALIGNMENT_LEFT, 420, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	y += 26.0
	var mods: Variant = _cfg.get("mods", [])
	if mods is Array:
		for k: Variant in (mods as Array):
			var e := DailyModifiers.entry(str(k))
			var col := Color("9a493e")
			if str(e.get("kind", "")) == "buff":
				col = UiTheme.PAGE_GREEN
			var one := DailyModifiers.line_of(str(k))
			var wraps := TextWrap.wrap_plain(_font, one, 420, UiTheme.FS_CAPTION)
			if wraps.size() > 1:
				one = wraps[0] + "…"     # 极端语种（西语）会超宽，压成一行别把面板撑破
			draw_string(_font, Vector2(730, y), one, HORIZONTAL_ALIGNMENT_LEFT, 420,
					UiTheme.FS_CAPTION, col)
			y += 20.0
	# 底部一行：还没打过 → 说明「每天一次」；打过了 → 今日成绩。
	var foot := _t("DAILY_ONCE", "每天一次 · 开局即计次 · 可续档")
	var foot_col := UiTheme.PAGE_MUTED
	if not _attempt.is_empty():
		foot = _t("DAILY_PLAYING", "今日挑战进行中")
		foot_col = UiTheme.PAGE_GREEN
		var result := str(_attempt.get("result", "playing"))
		if result != "playing":
			foot = _t("DAILY_RESULT", "今日成绩") + "：%d · %s" % [
					int(_attempt.get("score", 0)), RunRecord.result_label(result)]
	draw_string(_font, Vector2(730, 452), foot, HORIZONTAL_ALIGNMENT_LEFT, 420,
			UiTheme.FS_CAPTION, foot_col)

	_draw_boards()


func _wrapped(text: String, pos: Vector2, width: float) -> void:
	var y := pos.y
	for para: String in text.split("\n"):
		for line: String in TextWrap.wrap_plain(_font, para, width, UiTheme.FS_BODY):
			draw_string(_font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, width,
					UiTheme.FS_BODY, UiTheme.PAGE_INK)
			y += 27.0
		y += 8.0


func _draw_boards() -> void:
	var lr := Rect2(120, 562, 540, 140)
	var sr := Rect2(700, 562, 460, 140)
	UiTheme.draw_info_card(self, lr)
	UiTheme.draw_info_card(self, sr)
	draw_string(_font_bold, Vector2(140, 588), _t("DAILY_LOCAL_BOARD", "本地成绩 · 高分优先"),
			HORIZONTAL_ALIGNMENT_LEFT, 480, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	var local := DailyChallenge.local_scores(3)
	if local.is_empty():
		draw_string(_font, Vector2(140, 620), _t("DAILY_NO_SCORE", "还没有已结算的每日挑战"),
				HORIZONTAL_ALIGNMENT_LEFT, 480, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
	for i in local.size():
		var a: Dictionary = local[i]
		var row := "%d. %s · %d · %s" % [i + 1, str(a.get("date", "")),
				int(a.get("score", 0)), RunRecord.result_label(str(a.get("result", "")))]
		draw_string(_font, Vector2(140, 620 + i * 25), row, HORIZONTAL_ALIGNMENT_LEFT, 490,
				UiTheme.FS_CAPTION, UiTheme.PAGE_INK)
	draw_string(_font_bold, Vector2(720, 588), _t("DAILY_STEAM_BOARD", "Steam 今日榜"),
			HORIZONTAL_ALIGNMENT_LEFT, 260, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	if _steam_entries.is_empty():
		var status_y := 620.0
		for line: String in TextWrap.wrap_plain(_font, _steam_status, 420, UiTheme.FS_CAPTION):
			draw_string(_font, Vector2(720, status_y), line, HORIZONTAL_ALIGNMENT_LEFT, 420,
					UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
			status_y += 20.0
			if status_y > 660.0:
				break
	for i in mini(3, _steam_entries.size()):
		var e: Dictionary = _steam_entries[i]
		var row := "#%s · %d" % [str(e.get("global_rank", i + 1)), int(e.get("score", 0))]
		draw_string(_font, Vector2(720, 620 + i * 25), row, HORIZONTAL_ALIGNMENT_LEFT, 420,
				UiTheme.FS_CAPTION, UiTheme.PAGE_INK)
