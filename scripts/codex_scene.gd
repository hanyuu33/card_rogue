extends Control
## 百科（R590）—— 卡牌图鉴 / 查看故事 的二级入口。
##
## 为什么要有这一页：主界面按钮一路加到 8 个（开始 / 继续 / 图鉴 / 记录 / 故事 /
## 设置 / 鸣谢 / 退出），竖排已经挤到上下贴边。图鉴和故事都是「看资料」，
## 归到一个「百科」里收着，主界面只留一个入口。
##
## 提示（用户口径）：有「条件已达成、还没点开看过」的故事时，
##   **主界面的「百科」按钮** 与 **本页的「查看故事」行** 两级都要亮提示点。
##   判定唯一口 = `StoryRepo.ready_count()`（内部就是 `episode_state() == READY`）；
##   标题页和本页都读它，谁都不许在界面里另写一份三态判定。
##   提示点画法唯一口 = `ui_badge.gd`（按钮上挂的控件 / 本页自绘行共用）。
##
## 以后要加「机制词条 / 术语表」之类，往 `_build_rows()` 里加一行即可，
## 主界面不用再动。
##
## 出图参数：
##   `-- --screenshot`              截本页
##   `-- --screenshot --demo`       先把成就灌满（**测试档案**，不碰玩家真实进度）→ 看得到提示点
##   `-- --screenshot --nobadge`    强制不亮提示点（「有 / 无」两张对比图用）

const UiTheme = preload("res://scripts/ui_theme.gd")
const UiRoute = preload("res://scripts/ui_route.gd")
const UiBadge = preload("res://scripts/ui_badge.gd")

const ROW_W := 660.0
const ROW_H := 96.0
const ROW_GAP := 20.0
const LIST_Y := 286.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _repo: StoryRepo = null
## 已达成、待点开看过的故事段数（0 = 不亮提示点）。
var _ready_n := 0
var _rows: Array = []
var _hover := -1
var _last_mp := Vector2.INF


func _ready() -> void:
	UiTheme.attach_stage(self)   # R519：宽屏下内容居中，背景溢出铺满两侧
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	# 顶层页面：把上一轮留下的返回去向清掉（否则下一级界面会莫名退回百科）。
	UiRoute.clear()
	var args := OS.get_cmdline_user_args()
	if "--demo" in args:
		ProfileData.set_test_mode()   # 出图 / 验收：不写玩家真实档案
	# 提示数量：与标题页、故事页**同源**（StoryRepo.ready_count → episode_state）。
	# `check_achievements` 幂等，先把「这一局刚达成、还没记账」的成就补上，
	# 免得玩家刚通关回主界面却看不到提示。
	_repo = StoryRepo.load_json()
	ProfileData.check_achievements(_repo)
	_ready_n = _repo.ready_count()
	if "--nobadge" in args:
		_ready_n = 0
	_build_rows()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": GameI18n.ui("map", "CODEX_MENU_BACK", "继续"),
		"sub": GameI18n.ui("map", "CODEX_MENU_SUBTITLE", "百科"),
	})
	# 命令行 -- --screenshot：打开后自动截图退出（视觉验证用）
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_codex.png"))
			get_tree().quit())
		add_child(t)
		t.start()


func _build_rows() -> void:
	## 条目表：一行 = 一个二级入口。`badge` = 该行的提示点数字（0 = 不亮）。
	_rows = [
		{
			"title": GameI18n.ui("map", "CODEX_GALLERY_TITLE", "卡牌图鉴"),
			"sub": GameI18n.ui("map", "CODEX_GALLERY_SUBTITLE", "玩家卡牌 / 敌人图鉴 · 按种类、费用、职业筛选"),
			"target": "res://scenes/gallery.tscn",
			"badge": 0,
		},
		{
			"title": GameI18n.ui("map", "CODEX_STORY_TITLE", "查看故事"),
			"sub": GameI18n.ui("map", "CODEX_STORY_SUBTITLE", "成就解锁的剧情 · 看完把卡牌 / 道具加进奖励池"),
			"target": "res://scenes/story.tscn",
			"badge": _ready_n,
		},
	]


func _menu_items() -> Array:
	return [
		{"text": func(): return GameI18n.ui("map", "CODEX_MENU_SOUND_ON", "音效：开") if sfx.enabled else GameI18n.ui("map", "CODEX_MENU_SOUND_OFF", "音效：关"),
			"fn": _toggle_sound, "keep_open": true},
		{"text": GameI18n.ui("map", "CODEX_MENU_BACK_TITLE", "返回标题"), "fn": _back},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


# ------------------------------------------------------------ 几何

func _back_rect() -> Rect2:
	return Rect2(14, 14, 110, 34)


func _row_rect(i: int) -> Rect2:
	return Rect2((size.x - ROW_W) / 2.0, LIST_Y + float(i) * (ROW_H + ROW_GAP), ROW_W, ROW_H)


func _row_at(pos: Vector2) -> int:
	for i in _rows.size():
		if _row_rect(i).has_point(pos):
			return i
	return -1


# ------------------------------------------------------------ 输入

func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and _menu.handle_esc(event):
		return


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back()
			return
		var hit := _row_at(event.position)
		if hit >= 0:
			sfx.play("click")
			_open(hit)


func _process(_delta: float) -> void:
	# hover 靠鼠标位置变化驱动（`_gui_input` 在指针移出控件后就不再来事件了）。
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		var h := _row_at(mp)
		if h != _hover:
			_hover = h
			queue_redraw()


func _open(i: int) -> void:
	var row: Dictionary = _rows[i]
	var target := str(row.get("target", ""))
	if target == "":
		return
	# 下一级界面的「返回」要回到本页 —— `SceneFx.goto` 不带来源，去向记在 UiRoute。
	UiRoute.set_back("res://scenes/codex.tscn")
	SceneFx.goto(target)


func _back() -> void:
	UiRoute.clear()
	SceneFx.goto("res://scenes/title.tscn")


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	UiTheme.draw_page(self, UiTheme.bleed_rect(self))   # R519：铺满窗口
	draw_string(_font_bold, Vector2(0, 108), GameI18n.ui("map", "CODEX_TITLE", "百 科"), HORIZONTAL_ALIGNMENT_CENTER,
			size.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	draw_string(_font, Vector2(0, 140), GameI18n.ui("map", "CODEX_SUBTITLE", "卡牌与故事，都收在这里"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	var back := _back_rect()
	UiTheme.draw_action(self, back, false, false, back.has_point(get_local_mouse_position()))
	draw_string(_font_bold, back.position + Vector2(0, 22), GameI18n.ui("map", "CODEX_BACK", "← 返回"),
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	for i in _rows.size():
		_draw_row(i, _rows[i])
	if _ready_n > 0:
		# 提示点的说明只写一句；具体有几段就写在圆点里，别在正文再重复一遍。
		draw_string(_font, Vector2(0, size.y - 58),
				GameI18n.ui("map", "CODEX_BADGE_HINT", "金色圆点 = 有已达成、还没点开看过的故事"),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)


func _draw_row(i: int, row: Dictionary) -> void:
	var r := _row_rect(i)
	var badge := int(row.get("badge", 0))
	var hov := i == _hover
	# 有提示的行用「可点的米色底」，没提示的用纸底 —— 与故事页列表同一套语义。
	# 两行同底：底色只表示「这一行可点」，提示与否交给圆点 ——
	# 出图第一版给没提示的行用了纸白底，看着像禁用，两行不在一个层级上。
	var bg: Color = UiTheme.ADVENTURE_INPUT
	if hov:
		bg = bg.lightened(0.08)
	draw_rect(r, bg, true)
	draw_rect(r, UiTheme.ADVENTURE_BRASS, false, 1.6)
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			UiTheme.PAGE_INK.darkened(0.2), true)
	draw_string(_font_bold, r.position + Vector2(26, 44), str(row.get("title", "")),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130.0, UiTheme.FS_SUBHEAD, UiTheme.PAGE_INK)
	draw_string(_font, r.position + Vector2(26, 72), str(row.get("sub", "")),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130.0, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
	# 右侧：提示点在内、箭头贴边 —— 先看到「有新东西」，再看它去哪。
	var cy := r.position.y + r.size.y * 0.5
	var ax := r.end.x - 34.0
	var chev: Color = Color("514735") if hov else Color("a08f6e")
	draw_polyline(PackedVector2Array([
		Vector2(ax - 4.0, cy - 8.0), Vector2(ax + 3.0, cy), Vector2(ax - 4.0, cy + 8.0),
	]), chev, 2.2, true)
	if badge > 0:
		UiBadge.draw_badge(self, Vector2(ax - 34.0, cy), badge, _font_bold)
