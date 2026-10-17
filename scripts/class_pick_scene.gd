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
	return Rect2(40.0, 96.0, PANEL_W, size.y - 214.0)


func _diff_rect(i: int) -> Rect2:
	var p := _panel_rect()
	var w := (PANEL_W - 40.0 - 2.0 * 12.0) / 3.0
	return Rect2(p.position.x + 20.0 + i * (w + 12.0), p.position.y + p.size.y - 158.0, w, 42.0)


func _confirm_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 20.0, p.position.y + p.size.y - 96.0, PANEL_W - 40.0, 58.0)


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
	var y := p.position.y + 54.0
	draw_string(_font_bold, Vector2(x, y), PlayerClass.name_of(cid),
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_TITLE, Color("f2ead0"))
	y += 32.0
	draw_string(_font, Vector2(x, y), PlayerClass.subtitle_of(cid),
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_LABEL,
			UiTheme.class_color(cid).lightened(0.5))
	y += 30.0
	# 初始最大生命（R182：按职业不同，选职业界面明示）
	y += 4.0
	draw_string(_font, Vector2(x, y), "初始最大生命",
			HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, UiTheme.FS_LABEL, Color("cfcabb"))
	draw_string(_font_bold, Vector2(x + w * 0.5, y), "%d" % PlayerClass.base_hp_of(cid),
			HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5, UiTheme.FS_HEADING,
			UiTheme.class_color(cid).lightened(0.4))
	y += 28.0
	for para: String in PlayerClass.desc_of(cid).split("\n"):
		for line: String in _wrap_text(para, w, 14):
			draw_string(_font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, w,
					UiTheme.FS_LABEL, Color("cfcabb"))
			y += 22.0
		y += 6.0
	# 难度档位
	draw_string(_font_bold, Vector2(x, _diff_rect(0).position.y - 16.0), "难度档位",
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_BODY, Color("e0b23c"))
	for i in RunState.DIFFICULTY_COUNT:
		var dr := _diff_rect(i)
		var on := RunState.difficulty == i
		draw_rect(dr, Color(0.96, 0.78, 0.30, 0.94) if on else Color(1, 1, 1, 0.10), true)
		draw_rect(dr, UiTheme.ACCENT_GOLD if on else Color(1, 1, 1, 0.30), false, 2.0)
		draw_string(_font, Vector2(dr.position.x, dr.position.y + 28.0),
				"%d %s" % [i, RunState.DIFFICULTY_NAMES[i]], HORIZONTAL_ALIGNMENT_CENTER, dr.size.x,
				UiTheme.FS_LABEL, Color("1a1c22") if on else Color("e6e2d8"))
	draw_string(_font, Vector2(x, _confirm_rect().position.y - 14.0),
			RunState.difficulty_note(), HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_CAPTION,
			UiTheme.INK_ON_DARK)
	# 确认进入
	var cr := _confirm_rect()
	draw_rect(cr, Color("c8951c"), true)
	draw_rect(cr, Color("f2c14e"), false, 2.0)
	draw_string(_font_bold, Vector2(cr.position.x, cr.position.y + 38.0), "确认进入",
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
			for i in RunState.DIFFICULTY_COUNT:
				if _diff_rect(i).has_point(pos):
					RunState.set_difficulty(i)
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
	RunState.start_run([], GameLayers.LAYER_DEFAULT, cid)
	RunRecord.begin_run(cid)   # 本局开始：对战记录从这里计时
	SceneFx.goto("res://scenes/map.tscn")
