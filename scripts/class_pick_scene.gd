extends Control
## 角色选择（R166 改版）—— 不再摆三张大卡，而是：
##   ① 一排在底部的**头像**（只有头，占面积小）；
##   ② 点某个头像 → **背景换成该职业的 CG**（16:9 整屏），
##      左侧一块**不遮挡 CG 人物**的面板放：职业名 / 副标题 / 介绍 / **难度档位**；
##   ③ 点「确认进入」才开局。
## 难度不再在标题页选（R166 起挪到这里，与职业一起在开局前定好）。
## 角色决定两件事（见 PlayerClass）：初始卡组专属卡 + 战斗赠品道具。

const UiTheme = preload("res://scripts/ui_theme.gd")

const AV := 96.0                       # 头像边长（小，别占太多面积）
const AV_GAP := 30.0
const PANEL_W := 416.0
# R223：难度档位从「三个固定按钮」改成「左箭头 / 档位盒 / 右箭头」一行（0~10 共 11 档，
# 钳制不循环）。下面那条 debuff 文本随之变宽变高。
# R224：文本口径改成「只写当前档新增」（用户口径），通常一行就够；行数预算仍按 3 行留。
const DIFF_ARROW_W := 44.0     # 箭头按钮宽
const DIFF_ROW_H := 38.0       # 档位行高
const DIFF_GAP := 8.0          # 箭头与档位盒的间距
const NOTE_LINES := 3          # 当前档新增 debuff 文本行数预算（FS_CAPTION 12px / 行距 14）
const NOTE_LH := 14.0
const SUM_LINES := 2           # 数值摘要行数预算（FS_MICRO 10px / 行距 12）
const SUM_LH := 12.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null      # Esc 主菜单（R148）
var _hover := -1              # 悬停的头像下标
var _selected := -1           # 已选职业下标（_ready 里默认置 0 = 第一角色；-1 仅作初值）
var _picked := false


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	# R176：角色选择 BGM（Piano_Refreshing）—— 与标题同曲系，进选人不断氛围。
	Bgm.play("class_pick")
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	# -- --screenshot：自动截图退出（视觉验证用）
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("screenshot_class_pick.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	# 出图核验用：`-- --screenshot --sel N` 预选第 N 个职业（看 CG + 面板态）。
	# 默认选中第一个角色（R167：进入即选中，不再「默认不选」）。
	_selected = 0
	var uargs := OS.get_cmdline_user_args()
	for ai in uargs.size():
		if uargs[ai] == "--sel" and ai + 1 < uargs.size():
			_selected = clampi(int(uargs[ai + 1]), 0, PlayerClass.ids().size() - 1)
	# R223：`-- --screenshot --diff N` 预选难度档位（0~10，看累计 debuff 文本的换行情况）。
	for ai in uargs.size():
		if uargs[ai] == "--diff" and ai + 1 < uargs.size():
			RunState.set_difficulty(int(uargs[ai + 1]))
	queue_redraw()
	# R148：Esc 主菜单
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续选角色",
		"sub": "选择角色 · 按 Esc 返回",
	})


# ──────────────────────────────────────────────────────────────
# 几何（绘制与命中**同源**，改版式只改这里）
# ──────────────────────────────────────────────────────────────

func _av_rect(i: int) -> Rect2:
	var n := PlayerClass.ids().size()
	var total := n * AV + maxi(0, n - 1) * AV_GAP
	var x0 := (size.x - total) / 2.0
	return Rect2(x0 + i * (AV + AV_GAP), size.y - AV - 64.0, AV, AV)


func _panel_rect() -> Rect2:
	# R223：底边从 size.y-214 改为 -190（给难度档位块让出空间）；
	# 头像行顶边 = size.y-160，靠这 30px 缝隙分开。
	return Rect2(40.0, 96.0, PANEL_W, size.y - 190.0)


# 难度档位行：左箭头 / 档位盒 / 右箭头（R223，原来是三按钮 _diff_rect(i)）。
# 从面板底边往上排：确认钮(54) -8- 摘要(SUM) -2- 累计文本(NOTE) -6- 档位行(38)。
func _diff_row_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 20.0, p.end.y - 154.0 - DIFF_ROW_H, PANEL_W - 40.0, DIFF_ROW_H)


func _diff_left_rect() -> Rect2:
	var r := _diff_row_rect()
	return Rect2(r.position.x, r.position.y, DIFF_ARROW_W, DIFF_ROW_H)


func _diff_right_rect() -> Rect2:
	var r := _diff_row_rect()
	return Rect2(r.end.x - DIFF_ARROW_W, r.position.y, DIFF_ARROW_W, DIFF_ROW_H)


func _diff_box_rect() -> Rect2:
	var r := _diff_row_rect()
	return Rect2(r.position.x + DIFF_ARROW_W + DIFF_GAP, r.position.y,
			r.size.x - 2.0 * (DIFF_ARROW_W + DIFF_GAP), DIFF_ROW_H)


func _note_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 20.0, p.end.y - 106.0 - NOTE_LINES * NOTE_LH,
			PANEL_W - 40.0, NOTE_LINES * NOTE_LH)


func _summary_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 20.0, p.end.y - 80.0 - SUM_LINES * SUM_LH,
			PANEL_W - 40.0, SUM_LINES * SUM_LH)


func _confirm_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 20.0, p.end.y - 72.0, PANEL_W - 40.0, 54.0)


# ──────────────────────────────────────────────────────────────

func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	if _selected < 0:
		draw_rect(full, UiTheme.SCREEN_BG)
		draw_string(_font, Vector2(0, 288), "选择与你同行的精灵……",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_TITLE, UiTheme.INK_300)
		draw_string(_font, Vector2(0, 330), "点头像查看该角色，再选难度、确认进入",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.INK_ON_DARK)
	else:
		var cid := PlayerClass.ids()[_selected]
		var cg := UiAssets.class_cg(cid)
		if cg != null:
			draw_texture_rect_region(cg, full, CardFace.cover_region(cg.get_size(), full), Color.WHITE)
		else:
			draw_rect(full, UiTheme.SCREEN_BG)
		_draw_panel(cid)
	for i in PlayerClass.ids().size():
		_draw_avatar(i)


func _draw_avatar(i: int) -> void:
	var cid := PlayerClass.ids()[i]
	var r := _av_rect(i)
	var sel := i == _selected
	var cc: Color = UiTheme.class_color(cid)
	draw_rect(r, Color(0.04, 0.05, 0.08, 0.55), true)
	var tex := UiAssets.class_avatar(cid)
	if tex != null:
		var fr := CardFace.fit_rect(tex.get_size(), r.grow(-6.0))
		draw_texture_rect(tex, fr, false)
	else:
		# 缺图回退：职业圆徽（再缺则只留框）
		var badge := UiAssets.class_badge(cid)
		if badge != null:
			draw_texture_rect(badge, r.grow(-8.0), false)
	draw_rect(r, cc if sel else Color(1, 1, 1, 0.25), false, 4.0 if sel else 2.0)
	if i == _hover and not sel:
		draw_rect(r.grow(3.0), Color(1, 1, 1, 0.55), false, 2.0)
	draw_string(_font_bold, Vector2(r.position.x, r.end.y + 24.0), PlayerClass.name_of(cid),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_LABEL, Color("f2ead0"))
	# 初始最大生命（R182：选职业界面明示，便于对比）
	var hp_txt := "生命 %d" % PlayerClass.base_hp_of(cid)
	draw_string(_font, Vector2(r.position.x, r.end.y + 44.0), hp_txt,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_CAPTION,
			UiTheme.class_color(cid).lightened(0.35))


func _draw_panel(cid: String) -> void:
	var p := _panel_rect()
	draw_rect(p, Color(0.05, 0.06, 0.09, 0.80), true)
	draw_rect(p, UiTheme.class_color(cid), false, 2.5)
	var x := p.position.x + 20.0
	var w := PANEL_W - 40.0
	var y := p.position.y + 46.0
	draw_string(_font_bold, Vector2(x, y), PlayerClass.name_of(cid),
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_TITLE, Color("f2ead0"))
	y += 30.0
	draw_string(_font, Vector2(x, y), PlayerClass.subtitle_of(cid),
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_LABEL,
			UiTheme.class_color(cid).lightened(0.5))
	y += 30.0
	# 初始最大生命（R182：按职业不同，选职业界面明示）
	y += 2.0
	draw_string(_font, Vector2(x, y), "初始最大生命",
			HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, UiTheme.FS_LABEL, Color("cfcabb"))
	draw_string(_font_bold, Vector2(x + w * 0.5, y), "%d" % PlayerClass.base_hp_of(cid),
			HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5, UiTheme.FS_HEADING,
			UiTheme.class_color(cid).lightened(0.4))
	y += 26.0
	# 角色介绍（R223：字号降到 FS_CAPTION / 行距 17，给下面的难度档位块腾垂直空间）
	for para: String in PlayerClass.desc_of(cid).split("\n"):
		for line: String in _wrap_text(para, w, UiTheme.FS_CAPTION):
			draw_string(_font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, w,
					UiTheme.FS_CAPTION, Color("cfcabb"))
			y += 17.0
		y += 4.0
	# 难度档位（R223：左箭头 / 档位盒 / 右箭头，0~10 共 11 档，钳制不循环）
	draw_string(_font_bold, Vector2(x, _diff_row_rect().position.y - 13.0), "难度档位",
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_BODY, Color("e0b23c"))
	var d := clampi(RunState.difficulty, 0, RunState.DIFFICULTY_COUNT - 1)
	var lr := _diff_left_rect()
	var rr := _diff_right_rect()
	draw_rect(lr, Color(1, 1, 1, 0.10), true)
	draw_rect(lr, Color(1, 1, 1, 0.30), false, 2.0)
	draw_rect(rr, Color(1, 1, 1, 0.10), true)
	draw_rect(rr, Color(1, 1, 1, 0.30), false, 2.0)
	var arrow_on := Color("f2ead0")
	var arrow_off := Color("6b675f")
	draw_string(_font_bold, Vector2(lr.position.x, lr.position.y + 26.0), "<",
			HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, UiTheme.FS_HEADING,
			arrow_on if d > 0 else arrow_off)
	draw_string(_font_bold, Vector2(rr.position.x, rr.position.y + 26.0), ">",
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_HEADING,
			arrow_on if d < RunState.DIFFICULTY_COUNT - 1 else arrow_off)
	var br := _diff_box_rect()
	draw_rect(br, Color(0.96, 0.78, 0.30, 0.94), true)
	draw_rect(br, UiTheme.ACCENT_GOLD, false, 2.0)
	draw_string(_font_bold, Vector2(br.position.x, br.position.y + 26.0),
			"%d  %s" % [d, RunState.DIFFICULTY_NAMES[d]], HORIZONTAL_ALIGNMENT_CENTER, br.size.x,
			UiTheme.FS_HEADING, Color("1a1c22"))
	# 当前档新增 debuff 文本（R224：只写当前档这一条；高档继承的低档 debuff
	# 由下面那行数值摘要体现 —— 摘要列的都是「实际生效」的数值）
	var ny := _note_rect().position.y + 11.0
	for line: String in _wrap_text(RunState.difficulty_note(), w, UiTheme.FS_CAPTION):
		draw_string(_font, Vector2(x, ny), line, HORIZONTAL_ALIGNMENT_LEFT, w,
				UiTheme.FS_CAPTION, UiTheme.INK_ON_DARK)
		ny += NOTE_LH
	# 数值摘要（金钱 / 巧克力恒定显示，其余只在生效时列出）
	var sy := _summary_rect().position.y + 10.0
	for line: String in _wrap_text(RunState.difficulty_summary(), w, UiTheme.FS_MICRO):
		draw_string(_font, Vector2(x, sy), line, HORIZONTAL_ALIGNMENT_LEFT, w,
				UiTheme.FS_MICRO, UiTheme.INK_ON_DARK)
		sy += SUM_LH
	# 确认进入
	var cr := _confirm_rect()
	draw_rect(cr, Color("c8951c"), true)
	draw_rect(cr, Color("f2c14e"), false, 2.0)
	draw_string(_font_bold, Vector2(cr.position.x, cr.position.y + 37.0), "确认进入",
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, UiTheme.FS_HEADING, Color("1a1c22"))


func _wrap_text(t: String, max_w: float, px: int) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	for ch in t:
		if _font.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w \
				and cur != "":
			out.append(cur)
			cur = ch
		else:
			cur += ch
	out.append(cur)
	return out


func _menu_items() -> Array:
	## 本界面的 Esc 菜单项（R148）。每次打开都会重新调用，文案永远最新。
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _on_back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _on_back_to_title() -> void:
	## 流程界面里直接回标题 = **放弃本局**（与战斗中「返回标题」同一口径）。
	if RunState.run_active:
		RunState.end_run()
	SceneFx.goto("res://scenes/title.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and _menu.handle_esc(event):
		return
	if _picked:
		return
	# R223：键盘 ←/→ 也能调难度档位（与点箭头同效果）
	if event is InputEventKey and event.pressed and _selected >= 0:
		match event.keycode:
			KEY_LEFT:
				RunState.set_difficulty(RunState.difficulty - 1)
				sfx.play("click")
				queue_redraw()
			KEY_RIGHT:
				RunState.set_difficulty(RunState.difficulty + 1)
				sfx.play("click")
				queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _picked:
		return
	if event is InputEventMouseMotion:
		var idx := -1
		for i in PlayerClass.ids().size():
			if _av_rect(i).grow(5.0).has_point(event.position):
				idx = i
		if idx != _hover:
			_hover = idx
			queue_redraw()   # R186：悬停变化才重绘（原来靠 _process 每帧重绘）
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if _selected >= 0:
			if _confirm_rect().has_point(pos):
				_choose(PlayerClass.ids()[_selected])
				return
			if _diff_left_rect().has_point(pos) or _diff_right_rect().has_point(pos):
				var dir := -1 if _diff_left_rect().has_point(pos) else 1
				RunState.set_difficulty(RunState.difficulty + dir)
				sfx.play("click")
				queue_redraw()   # R186（原来靠 _process 每帧重绘）
				return
		for i in PlayerClass.ids().size():
			if _av_rect(i).grow(5.0).has_point(pos):
				_selected = i
				sfx.play("click")
				queue_redraw()   # R186（原来靠 _process 每帧重绘）
				return


func _choose(cid: String) -> void:
	_picked = true
	sfx.play("click")
	# 角色决定：初始卡组追加的专属卡 + 战斗赠品道具（见 PlayerClass）。
	# 地图由 RunState.start_run 用本局种子生成（同一种子必然生成同一张图）。
	# R241：设置页填了「下一局种子」就用它（复现用）；填 0 则现摇一个。
	GameSettings.ensure_loaded()
	var want_seed: int = GameSettings.next_seed
	RunState.start_run([], GameLayers.LAYER_DEFAULT, cid, want_seed)
	# 指定种子**用一次就清空**：否则玩家会莫名其妙「每局地图都一样」。
	# 要再复现同一局，回设置页把种子再填一次即可（记录详情里能查到那串数字）。
	if want_seed != 0:
		GameSettings.set_next_seed(0)
	RunRecord.begin_run(cid)   # 本局开始：对战记录从这里计时
	SceneFx.goto("res://scenes/map.tscn")
