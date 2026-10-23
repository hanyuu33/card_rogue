extends Control
## 故事 / 剧情解锁界面（R346）—— 主界面「查看故事」进来这里。
##
## 三段状态（`StoryRepo.episode_state()` 是唯一判定口）：
##   locked  条件没达成 → 标题灰掉、右侧写条件与进度（`0 / 1`）
##   ready   条件达成、还没点开看过 → 金色「可查看」，点开弹正文
##   read    看过了 → 绿色「已查看」（卡牌 / 道具已经发放）
##
## 用户口径（R346）：「解锁时在故事界面点击查看故事解锁，之后可以解锁一些卡牌/道具
## 加入奖励池」—— 所以**条件达成 ≠ 发奖励**，必须在正文面板里点「收下」才发。
##
## 现在是**空壳期**：正文全部为空（显示「（这一段故事还没有写。）」），`grants` 也全空。
## 填内容只需要改 `stories.json`，这个界面一行都不用动。
##
## 出图参数：
##   `-- --screenshot`                 直接截列表
##   `-- --screenshot --demo`          先把全部剧情解锁（写进**测试档案**，不碰真实进度）再截
##   `-- --screenshot --demo --story N` 再打开第 N 段（0 起）的正文面板

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_H := 76.0
const ROW_W := 980.0
const LIST_Y := 132.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _repo: StoryRepo = null
var _episodes: Array = []
var _hover := -1
var _scroll := 0
var _sel := -1                       # 打开的正文下标（-1 = 列表）
var _toast := ""                     # 底部一次性提示（「已解锁」/「条件还没达成」）
var _toast_t := 0.0
var _last_mp := Vector2.INF


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	var args := OS.get_cmdline_user_args()
	# 出图 / 验收用：把剧情全部解锁（**测试档案**，不写玩家真实进度）
	if "--demo" in args:
		ProfileData.set_test_mode()
	_repo = StoryRepo.load_json()
	_refresh()
	if "--demo" in args:
		_satisfy_all()
	ProfileData.check_achievements(_repo)
	ProfileData.flush()
	if "--screenshot" in OS.get_cmdline_user_args():
		var di := args.find("--story")
		if di >= 0 and di + 1 < args.size() and not _episodes.is_empty():
			_open_detail(clampi(int(args[di + 1]), 0, _episodes.size() - 1))
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_story.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续",
		"sub": "故事 · 按 Esc 返回",
	})


func _menu_items() -> Array:
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _refresh() -> void:
	_episodes = _repo.episodes.duplicate()
	_scroll = 0
	queue_redraw()


func _satisfy_all() -> void:
	## 出图用：把每个成就的条件「灌满」（只改内存，`--demo` 已经切成测试档案）。
	for ach: Dictionary in _repo.achievements:
		var need := int(ach.get("min", 1))
		var key := str(ach.get("stat", ""))
		if key != "":
			ProfileData.bump(key, need)
		else:
			ProfileData.bump(str(ach.get("stat_prefix", "demo:")) + "__demo", need)
	ProfileData.check_achievements(_repo)


# ------------------------------------------------------------ 几何

func _row_rect(i: int) -> Rect2:
	return Rect2((size.x - ROW_W) / 2.0, LIST_Y + (i - _scroll) * ROW_H,
			ROW_W, ROW_H - 10.0)


func _back_rect() -> Rect2:
	return Rect2(14, 14, 110, 34)


func _max_rows() -> int:
	return maxi(1, int((size.y - LIST_Y - 30.0) / ROW_H))


func _row_at(pos: Vector2) -> int:
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _episodes.size():
			break
		if _row_rect(idx).has_point(pos):
			return idx
	return -1


func _detail_rect() -> Rect2:
	return Rect2((size.x - 900.0) / 2.0, 92.0, 900.0, size.y - 150.0)


func _detail_close_rect() -> Rect2:
	var r := _detail_rect()
	return Rect2(r.end.x - 50.0, r.position.y + 10.0, 36.0, 30.0)


func _claim_rect() -> Rect2:
	var r := _detail_rect()
	return Rect2(r.end.x - 216.0, r.end.y - 56.0, 192.0, 40.0)


# ------------------------------------------------------------ 输入

func _unhandled_input(event: InputEvent) -> void:
	if _sel >= 0 and event is InputEventKey and event.pressed \
			and event.keycode == KEY_ESCAPE:
		_close_detail()
		get_viewport().set_input_as_handled()
		return
	if _menu != null and _menu.handle_esc(event):
		return


func _gui_input(event: InputEvent) -> void:
	# 正文面板打开时，输入全交给面板
	if _sel >= 0:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			if _claim_rect().has_point(event.position):
				_claim(_sel)
				return
			if _detail_close_rect().has_point(event.position) \
					or not _detail_rect().has_point(event.position):
				sfx.play("click")
				_close_detail()
		return
	if event is InputEventMouseMotion:
		_hover = _row_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back_to_title()
			return
		var hit := _row_at(event.position)
		if hit >= 0:
			sfx.play("click")
			_open_detail(hit)
			return
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN
			or event.button_index == MOUSE_BUTTON_WHEEL_UP):
		var step := 2 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -2
		var hi := maxi(0, _episodes.size() - _max_rows())
		_scroll = clampi(_scroll + step, 0, hi)
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _open_detail(idx: int) -> void:
	if idx < 0 or idx >= _episodes.size():
		return
	_sel = idx
	_hover = -1
	queue_redraw()


func _close_detail() -> void:
	_sel = -1
	queue_redraw()


func _claim(idx: int) -> void:
	var ep: Dictionary = _episodes[idx]
	var eid := str(ep.get("id", ""))
	var res := ProfileData.claim_episode(_repo, eid)
	if not bool(res.get("ok", false)):
		_set_toast(str(res.get("reason", "现在还不能解锁")))
		sfx.play("lose")
		return
	sfx.play("win")
	var cards: Array = res.get("cards", [])
	var relics: Array = res.get("relics", [])
	if cards.is_empty() and relics.is_empty():
		_set_toast("已解锁（这一段暂时没有额外奖励）")
	else:
		_set_toast("已解锁：卡牌 %d 张 · 道具 %d 件已加入奖励池" % [cards.size(), relics.size()])
	_close_detail()
	queue_redraw()


func _set_toast(msg: String) -> void:
	_toast = msg
	_toast_t = 3.0
	queue_redraw()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t = maxf(0.0, _toast_t - delta)
		if _toast_t <= 0.0:
			_toast = ""
		queue_redraw()
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		queue_redraw()


func _back_to_title() -> void:
	SceneFx.goto("res://scenes/title.tscn")


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	var top := Color("171a22")
	var bottom := Color("2b3040")
	for i in 36:
		var t := float(i) / 35.0
		draw_rect(Rect2(0, size.y * float(i) / 36.0, size.x, size.y / 36.0 + 1.0),
				top.lerp(bottom, t), true)
	draw_string(_font_bold, Vector2(0, 62), "故 事", HORIZONTAL_ALIGNMENT_CENTER,
			size.x, UiTheme.FS_HEADING, UiTheme.SAND)
	var unlocked := 0
	var read := 0
	for ep: Dictionary in _episodes:
		var st := _repo.episode_state(str(ep.get("id", "")))
		if st != StoryRepo.STATE_LOCKED:
			unlocked += 1
		if st == StoryRepo.STATE_READ:
			read += 1
	draw_string(_font, Vector2(0, 94),
			"已解锁 %d / %d 段 · 已读 %d 段 · 达成条件后点开才能收下这一段的内容"
			% [unlocked, _episodes.size(), read],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
	# 返回
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	draw_rect(back, Color("414860") if hov_back else Color("343947"), true)
	draw_rect(back, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, back.position + Vector2(0, 22), "← 返回标题",
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, Color("e6e2d8"))
	if _episodes.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 40),
				"还没有任何剧情段（stories.json 是空的）。",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.INK_ON_DARK)
		return
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _episodes.size():
			break
		_draw_row(idx, _episodes[idx])
	if _episodes.size() > _max_rows():
		draw_string(_font, Vector2(0, size.y - 12),
				"滚轮翻页 · 第 %d–%d 段 / 共 %d 段"
				% [_scroll + 1, mini(_scroll + _max_rows(), _episodes.size()), _episodes.size()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				UiTheme.INK_ON_DARK)
	if _toast != "":
		var tw := minf(size.x - 80.0, 720.0)
		var tr := Rect2((size.x - tw) / 2.0, size.y - 62.0, tw, 34.0)
		draw_rect(tr, Color(0.08, 0.09, 0.12, 0.92), true)
		draw_rect(tr, Color("c8951c"), false, 1.6)
		draw_string(_font_bold, tr.position + Vector2(0, 23), _toast,
				HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, UiTheme.FS_LABEL, Color("f2d99a"))
	if _sel >= 0 and _sel < _episodes.size():
		_draw_detail()


func _draw_row(idx: int, ep: Dictionary) -> void:
	var r := _row_rect(idx)
	var eid := str(ep.get("id", ""))
	var st := _repo.episode_state(eid)
	var hov := idx == _hover
	var locked := st == StoryRepo.STATE_LOCKED
	var bg := Color("22242c")
	if not locked:
		bg = Color("2a3040")
	if hov:
		bg = bg.lightened(0.08)
	draw_rect(r, bg, true)
	draw_rect(r, Color("6a768c") if hov else Color("444a58"), false, 1.6)
	# 左沿状态色条
	var stripe := Color("4a4e58")
	if st == StoryRepo.STATE_READY:
		stripe = Color("c8951c")
	elif st == StoryRepo.STATE_READ:
		stripe = Color("4f9e6a")
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y), stripe, true)
	# 章节小标
	var chap := str(ep.get("chapter", "?"))
	draw_string(_font, r.position + Vector2(20, 26), chap,
			HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_CAPTION, Color("7d8590"))
	# 标题（锁着就是 ？？？）
	var title := _repo.episode_label(ep)
	var tcol := Color("6f7684") if locked else Color("f2ead0")
	draw_string(_font_bold, r.position + Vector2(20, 52), title,
			HORIZONTAL_ALIGNMENT_LEFT, 560, UiTheme.FS_SUBHEAD, tcol)
	# 右侧状态
	var tag := "未达成"
	var tcol2 := Color("8a8f9c")
	if st == StoryRepo.STATE_READY:
		tag = "可查看"
		tcol2 = Color("f0c860")
	elif st == StoryRepo.STATE_READ:
		tag = "已查看"
		tcol2 = Color("8fd7a5")
	draw_string(_font_bold, r.position + Vector2(r.size.x - 130, 34), tag,
			HORIZONTAL_ALIGNMENT_RIGHT, 110, UiTheme.FS_BODY, tcol2)
	# 条件提示 / 简介
	var sub := ""
	if locked:
		sub = _repo.requirement_text(eid)
	elif st == StoryRepo.STATE_READY:
		sub = "点开查看这一段（看过才会收下卡牌 / 道具）"
	else:
		sub = "已读完"
	draw_string(_font, r.position + Vector2(r.size.x - 470, 58), sub,
			HORIZONTAL_ALIGNMENT_RIGHT, 450, UiTheme.FS_CAPTION, Color("9aa0ad"))


func _draw_detail() -> void:
	var r := _detail_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.58), true)
	draw_rect(r, Color("1e2129"), true)
	draw_rect(r, Color("6a768c"), false, 2.0)
	var ep: Dictionary = _episodes[_sel]
	var eid := str(ep.get("id", ""))
	var st := _repo.episode_state(eid)
	var x0 := r.position.x + 28.0
	var x1 := r.end.x - 28.0
	var w := x1 - x0
	draw_string(_font_bold, Vector2(x0, r.position.y + 38.0), _repo.episode_label(ep),
			HORIZONTAL_ALIGNMENT_LEFT, w - 60.0, UiTheme.FS_HEADING, UiTheme.SAND)
	# 关闭
	var cr := _detail_close_rect()
	draw_rect(cr, Color("4a2c2c") if cr.has_point(get_local_mouse_position())
			else Color("343947"), true)
	draw_string(_font_bold, cr.position + Vector2(0, 22), "×",
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, UiTheme.FS_BODY, Color("e6e2d8"))
	draw_line(Vector2(x0, r.position.y + 54.0), Vector2(x1, r.position.y + 54.0),
			Color("3d424e"), 1.0)
	# 正文
	var y := r.position.y + 82.0
	if st == StoryRepo.STATE_LOCKED:
		draw_string(_font_bold, Vector2(x0, y), "这一段还没有解锁",
				HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_BODY, Color("c8a8a8"))
		y += 28.0
		for line: String in TextWrap.wrap_plain(_font, _repo.requirement_text(eid),
				w, UiTheme.FS_LABEL):
			draw_string(_font, Vector2(x0, y), line, HORIZONTAL_ALIGNMENT_LEFT, w,
					UiTheme.FS_LABEL, Color("9aa0ad"))
			y += 22.0
	else:
		for line2: String in _wrapped_body(eid, w):
			if y > r.end.y - 96.0:
				draw_string(_font, Vector2(x0, y), "…", HORIZONTAL_ALIGNMENT_LEFT, w,
						UiTheme.FS_BODY, Color("6f7684"))
				break
			draw_string(_font, Vector2(x0, y), line2, HORIZONTAL_ALIGNMENT_LEFT, w,
					UiTheme.FS_BODY, Color("dcd8cd"))
			y += 26.0
	# 奖励预览（这一段的 grants）
	var g := _repo.episode_grants(eid)
	var cards: Array = g.get("cards", [])
	var relics: Array = g.get("relics", [])
	var gy := r.end.y - 92.0
	draw_line(Vector2(x0, gy - 16.0), Vector2(x1, gy - 16.0), Color("3d424e"), 1.0)
	var gtxt := "看完这一段没有额外奖励。"
	if not cards.is_empty() or not relics.is_empty():
		gtxt = "看完解锁：卡牌 %d 张 · 道具 %d 件（加入奖励池）" % [cards.size(), relics.size()]
	draw_string(_font, Vector2(x0, gy), gtxt, HORIZONTAL_ALIGNMENT_LEFT, w - 220.0,
			UiTheme.FS_LABEL, Color("b9ae8a"))
	# 收下按钮
	var br := _claim_rect()
	var can := st == StoryRepo.STATE_READY
	var hov := br.has_point(get_local_mouse_position())
	var bcol := Color("c8951c") if can else Color("3a3e48")
	if can and hov:
		bcol = Color("e0b23c")
	draw_rect(br, bcol, true)
	draw_rect(br, Color("f2c14e") if can else Color("4a4e58"), false, 2.0)
	var btxt := "收下这一段"
	if st == StoryRepo.STATE_READ:
		btxt = "已经看过"
	elif not can:
		btxt = "条件未达成"
	draw_string(_font_bold, br.position + Vector2(0, 27), btxt,
			HORIZONTAL_ALIGNMENT_CENTER, br.size.x, UiTheme.FS_BODY,
			Color("1a1c22") if can else Color("7d8590"))


func _wrapped_body(eid: String, w: float) -> Array[String]:
	var out: Array[String] = []
	for para: String in _repo.episode_text_lines(eid):
		for line: String in TextWrap.wrap_plain(_font, para, w, UiTheme.FS_BODY):
			out.append(line)
	return out
