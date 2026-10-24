extends Control
## 故事 / 剧情解锁界面（R346）—— 主界面「查看故事」进来这里。
##
## 三段状态（`StoryRepo.episode_state()` 是唯一判定口）：
##   locked  条件没达成          锁        标题灰掉，右侧写条件与进度（`0 / 1`）
##   ready   条件达成、还没点开过 亮点（环+中心点）  金色，点开弹正文
##   read    已经看过            对勾      绿色（卡牌 / 道具已加入奖励池）
##
## ⚠️ R347 用户口径：**状态不要用文字，用一个小图标表示**。
##    所以列表行右侧、顶部总览、正文面板标题前一律只画图标，
##    不写「未达成 / 可查看 / 已查看 / 已读完」这类状态词。
##    * 图标唯一口 = `_draw_state_icon()`，配色唯一口 = `_state_color()`
##      （左沿色条 / 顶部图例 / 正文面板都读它，别在别处再判一次三态）。
##    * 列表行的副标题仍可写东西，但只能是**条件**（锁着时的达成进度）
##      或**这一段给什么**（可查看时的解锁内容）—— 这两样不是状态。
##
## 用户口径（R346）：「解锁时在故事界面点击查看故事解锁，之后可以解锁一些卡牌/道具
## 加入奖励池」—— 所以**条件达成 ≠ 发奖励**，必须在正文面板里点「收下」才发。
##
## 现在是**空壳期**：正文全部为空（显示「（这一段故事还没有写。）」），`grants` 也全空。
## 填内容只需要改 `stories.json`，这个界面一行都不用动。
##
## 解锁动画（R352）：在正文面板点「收下这一段」后，拿到的卡牌 / 道具会**逐个浮现**
## 出来（名字 + 稀有度 + 类型），玩家一眼看清「往奖励池里加了什么」。
## 动画是纯时间驱动（`_reveal_t` + `_process` 推进），不用 Tween —— 这样截图能精确停在
## 任意一帧，出图验收不用赌一个 `await`。
##
## 出图参数：
##   `-- --screenshot`                 直接截列表
##   `-- --screenshot --reveal`        演一遍解锁动画（测试档案；第 1 段的条件直接灌满）
##   `-- --screenshot --demo`          先把全部剧情解锁（写进**测试档案**，不碰真实进度）再截
##   `-- --screenshot --demomix`       凑齐三种状态：第 0 段已读、第 1 段可查看、其余未达成
##   `-- --screenshot --demo --story N` 再打开第 N 段（0 起）的正文面板

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_H := 76.0
const ROW_W := 980.0
const LIST_Y := 132.0
## R352 解锁动画的节奏：每张间隔 / 单张淡入时长 / 行高。
const REVEAL_INTERVAL := 0.30
const REVEAL_FADE := 0.26
const REVEAL_ROW_H := 92.0

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
## R352 解锁动画的条目：{kind, name, sub, col}。非空 = 动画正在播 / 播完等点击。
var _reveal: Array = []
var _reveal_t := 0.0


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	var args := OS.get_cmdline_user_args()
	# 出图 / 验收用：把剧情全部解锁（**测试档案**，不写玩家真实进度）
	var demo := "--demo" in args or "--demomix" in args
	if demo:
		ProfileData.set_test_mode()
	_repo = StoryRepo.load_json()
	_refresh()
	if "--demomix" in args:
		_demo_mix()
	elif "--demo" in args:
		_satisfy_all()
	ProfileData.check_achievements(_repo)
	ProfileData.flush()
	if "--reveal" in args:
		# 出图：在**测试档案**里把第 1 段的条件灌满并直接收下 → 演解锁动画。
		# 走的是真实链路（claim_episode → _start_reveal），不是硬造数据。
		# ⚠️ 必须先 set_test_mode：否则 claim 会写玩家真实档案 —— 而且第二次出图时
		#    真实档案里已是「已领取」，claim 返回空 → 动画根本不播（R353 踩过）。
		ProfileData.set_test_mode()
		_satisfy_all()
		if not _episodes.is_empty():
			var rv_res := ProfileData.claim_episode(_repo,
					str((_episodes[0] as Dictionary).get("id", "")))
			_start_reveal(rv_res.get("cards", []), rv_res.get("relics", []))
	if "--screenshot" in OS.get_cmdline_user_args():
		var di := args.find("--story")
		if di >= 0 and di + 1 < args.size() and not _episodes.is_empty():
			_open_detail(clampi(int(args[di + 1]), 0, _episodes.size() - 1))
		var t := Timer.new()
		t.wait_time = 1.05 if not _reveal.is_empty() else 0.6
		# `--shotwait <秒>`：手动指定截图时机（比如要拍解锁动画播完后的「继续」按钮）。
		var swi := args.find("--shotwait")
		if swi >= 0 and swi + 1 < args.size():
			t.wait_time = maxf(0.1, float(str(args[swi + 1])))
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_story.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续",
		"sub": "故事",
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


func _demo_mix() -> void:
	## 出图用：一次凑齐三种状态 —— 第 0 段「已读」、第 1 段「可查看」、其余「未达成」。
	## 只改**测试档案**（`--demomix` 已在 `_ready` 里先 `set_test_mode()`）。
	## ⚠️ 顺序要紧：`mark_story_read()` 之前该段必须先 `unlock_story()` ——
	##    `episode_state()` 里 read 的判定在最前面，没有 unlocked 就直接标 read 的话
	##    「解锁过」这一步等于被跳过（不是崩，是状态语义不对）。
	# R359：空正文的段落现在恒为 locked，出图要凑齐三态就得给第 1 段**内存里**塞一行
	# 占位正文（只改这个 repo 实例，绝不写 stories.json）。
	if _episodes.size() > 1:
		var dem_ep: Dictionary = _episodes[1]
		if not _repo.has_content(str(dem_ep.get("id", ""))):
			dem_ep["text"] = ["（出图占位：这一段正文还没写）"]
	for i in mini(2, _episodes.size()):
		ProfileData.unlock_story(str((_episodes[i] as Dictionary).get("id", "")))
	if not _episodes.is_empty():
		ProfileData.mark_story_read(str((_episodes[0] as Dictionary).get("id", "")))


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
	# R352 解锁动画：播完之前吞掉所有点击，播完点一下关掉（别让玩家漏看奖励）。
	if not _reveal.is_empty():
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT and _reveal_finished():
			sfx.play("click")
			_reveal = []
			queue_redraw()
		return
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
	_close_detail()
	# R352：不再只弹一行 toast —— 拿到的每一样都会在解锁动画里逐个浮现。
	_start_reveal(res.get("cards", []), res.get("relics", []))


func _set_toast(msg: String) -> void:
	_toast = msg
	_toast_t = 3.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _reveal.is_empty() and not _reveal_finished():
		_reveal_t += delta
		queue_redraw()
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


# ------------------------------------------------------------ 三态图标

func _state_color(st: String) -> Color:
	## 三态配色唯一口：左沿色条 / 顶部图例 / 列表图标 / 正文面板标题前全读它。
	## 想改「可查看是金、已读是绿」只改这里一处。
	if st == StoryRepo.STATE_READY:
		return Color("f0c860")     # 金：有东西可看，等你点开
	if st == StoryRepo.STATE_READ:
		return Color("8fd7a5")     # 绿：看过了，东西已经发下来
	return Color("6f7684")         # 灰：条件还没达成


func _draw_state_icon(c: Vector2, st: String, k := 1.0) -> void:
	## 三态小图标（R347：状态**只用图标**，不写文字）。`c` = 图标中心，`k` = 缩放。
	##   locked → 锁：半圆锁梁 + 方形锁身 + 钥匙孔
	##   ready  → 亮点：圆环 + 中心实心点（「有新东西」的通用语汇）
	##   read   → 对勾：三段折线
	## 三者形态差得够远（实心块 / 环 / 折线），缩到 10px 也不会认错。
	var col := _state_color(st)
	var rad := 12.0 * k
	if st == StoryRepo.STATE_LOCKED:
		# 锁梁：上半圆，开口朝下扣在锁身上
		draw_arc(c + Vector2(0, -rad * 0.30), rad * 0.46, PI, TAU, 18, col, 2.0 * k, true)
		# 锁身（重心比中心略低，所以整体上移一点看起来才「坐在中间」）
		draw_rect(Rect2(c + Vector2(-rad * 0.72, -rad * 0.30), Vector2(rad * 1.44, rad * 1.06)),
				col, true)
		# 钥匙孔：挖背景色做不出真孔，涂一个半透明暗点即可
		draw_circle(c + Vector2(0, rad * 0.10), rad * 0.16, Color(0, 0, 0, 0.5), true)
	elif st == StoryRepo.STATE_READY:
		draw_arc(c, rad * 0.78, 0.0, TAU, 28, col, 2.2 * k, true)
		draw_circle(c, rad * 0.34, col, true)
	else:
		draw_polyline(PackedVector2Array([
			c + Vector2(-rad * 0.62, rad * 0.02),
			c + Vector2(-rad * 0.16, rad * 0.52),
			c + Vector2(rad * 0.66, -rad * 0.52),
		]), col, 2.8 * k, true)


func _draw_legend(center: Vector2, counts: Dictionary) -> void:
	## 顶部三态总览：`图标 + 数量` × 3，整体以 `center` 居中。
	## 三种状态**恒常显示**，数量为 0 也照样画（颜色压淡）—— 忽有忽无的图例等于没有。
	var states := [StoryRepo.STATE_LOCKED, StoryRepo.STATE_READY, StoryRepo.STATE_READ]
	var box := 96.0
	var x := center.x - box * 1.5
	for st: String in states:
		var n := int(counts.get(st, 0))
		var col := _state_color(st)
		if n == 0:
			col.a = 0.32
		_draw_state_icon(Vector2(x + 16.0, center.y), st, 0.82)
		draw_string(_font_bold, Vector2(x + 34.0, center.y + 6.0), str(n),
				HORIZONTAL_ALIGNMENT_LEFT, 52.0, UiTheme.FS_BODY, col)
		x += box


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
	# 顶部总览：三态**只给图标 + 数量**（R347 用户口径），不写「已解锁 / 已读」这类状态词。
	var counts := {StoryRepo.STATE_LOCKED: 0, StoryRepo.STATE_READY: 0,
			StoryRepo.STATE_READ: 0}
	for ep: Dictionary in _episodes:
		var st := _repo.episode_state(str(ep.get("id", "")))
		counts[st] = int(counts.get(st, 0)) + 1
	_draw_legend(Vector2(size.x / 2.0, 96.0), counts)
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
				"第 %d–%d 段 / 共 %d 段"
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
	if not _reveal.is_empty():
		_draw_reveal()


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
	# 左沿状态色条（与右侧图标同源；压暗一档免得抢标题）
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			_state_color(st).darkened(0.34), true)
	# 章节小标
	var chap := str(ep.get("chapter", "?"))
	draw_string(_font, r.position + Vector2(20, 26), chap,
			HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_CAPTION, Color("7d8590"))
	# 标题（锁着就是 ？？？）
	var title := _repo.episode_label(ep)
	var tcol := Color("6f7684") if locked else Color("f2ead0")
	draw_string(_font_bold, r.position + Vector2(20, 52), title,
			HORIZONTAL_ALIGNMENT_LEFT, 480, UiTheme.FS_SUBHEAD, tcol)
	# 右侧状态：**只画图标**（R347 用户口径：「不要用文字，用一个小图标表示」）
	_draw_state_icon(Vector2(r.end.x - 40.0, r.position.y + r.size.y * 0.5), st)
	# 副标题：锁着 → 条件与进度（这是**条件**，不是状态，要留）；
	#        可查看 → 这一段给什么（没挂东西就空着）；已读 → 空着。
	#        R347 起不再写「点开查看这一段」「已读完」这类状态文字。
	var sub := ""
	if locked:
		sub = _repo.requirement_text(eid)
	elif st == StoryRepo.STATE_READY:
		sub = _grants_summary(eid)
	if sub != "":
		draw_string(_font, r.position + Vector2(r.size.x - 470, 58), sub,
				HORIZONTAL_ALIGNMENT_RIGHT, 372, UiTheme.FS_CAPTION, Color("9aa0ad"))


func _grants_summary(eid: String) -> String:
	## 「可查看」行副标题：这一段看完给什么。什么都没挂 → 空串
	## （不写「无奖励」三个字占地方，玩家看图标就知道能点了）。
	var g := _repo.episode_grants(eid)
	var nc := (g.get("cards", []) as Array).size()
	var nr := (g.get("relics", []) as Array).size()
	if nc == 0 and nr == 0:
		return ""
	var parts: Array[String] = []
	if nc > 0:
		parts.append("卡牌 %d" % nc)
	if nr > 0:
		parts.append("道具 %d" % nr)
	return "解锁：" + " · ".join(parts)


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
	# 标题前也放同一个小图标（列表里认什么、打开还是什么，不用再读文字判断）
	_draw_state_icon(Vector2(x0 + 11.0, r.position.y + 30.0), st, 0.95)
	draw_string(_font_bold, Vector2(x0 + 34.0, r.position.y + 38.0), _repo.episode_label(ep),
			HORIZONTAL_ALIGNMENT_LEFT, w - 94.0, UiTheme.FS_HEADING, UiTheme.SAND)
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


# ------------------------------------------------------------ 解锁动画（R352）

func _start_reveal(cards: Array, relics: Array) -> void:
	## 把「这一段给了什么」整理成动画条目并开播。
	## cards / relics 是 `ProfileData.claim_episode()` 的返回（**本次新解锁的**，
	## 已经解锁过的不会重复出现在这里）。
	_reveal = []
	var crepo := CardRepo.load_json()
	for v: Variant in cards:
		var c := crepo.get_card(int(v))
		if c == null:
			continue
		var rar := clampi(c.rarity, 0, 6)
		_reveal.append({
			"kind": "card",
			"name": c.card_name,
			"sub": "%s · %s · %d 费" % [CardData.RARITY_NAMES[rar],
					c.kind, c.cost],
			"col": CardData.RARITY_COLORS[rar],
		})
	var rrepo := RelicRepo.load_json()
	for v2: Variant in relics:
		var r := rrepo.get_relic(int(v2))
		if r == null:
			continue
		_reveal.append({
			"kind": "relic",
			"name": r.relic_name,
			"sub": "道具 · %s" % r.tier_label(),
			"col": r.tier_color(),
		})
	_reveal_t = 0.0
	if _reveal.is_empty():
		_set_toast("已解锁（这一段没有额外奖励）")
	queue_redraw()


func _reveal_finished() -> bool:
	## 最后一条也淡入完了 → 可以点掉。
	if _reveal.is_empty():
		return false
	var n := _reveal.size()
	return _reveal_t >= (n - 1) * REVEAL_INTERVAL + REVEAL_FADE + 0.30


func _draw_reveal() -> void:
	## 解锁动画：全屏压暗 + 居中面板，奖励条目逐个淡入并轻微上浮。
	## 用 `_draw()` 而不是 Control 节点 —— 与这个界面其它部分一致，且截图稳定。
	var n := _reveal.size()
	var panel_h := 156.0 + REVEAL_ROW_H * n
	var r := Rect2((size.x - 620.0) / 2.0, (size.y - panel_h) / 2.0, 620.0, panel_h)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.76), true)
	draw_rect(r, Color("1c1f27"), true)
	draw_rect(r, Color("c8951c"), false, 2.0)
	draw_string(_font_bold, Vector2(r.position.x, r.position.y + 44), "解 锁",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_HEADING, UiTheme.SAND)
	draw_string(_font, Vector2(r.position.x, r.position.y + 70),
			"以下内容已加入奖励池",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_LABEL, Color("9aa0ad"))
	for i in n:
		var a := clampf((_reveal_t - i * REVEAL_INTERVAL) / REVEAL_FADE, 0.0, 1.0)
		if a <= 0.0:
			continue
		var item: Dictionary = _reveal[i]
		var col: Color = item.get("col", Color("e8e4da"))
		var y := r.position.y + 92.0 + i * REVEAL_ROW_H + (1.0 - a) * 16.0
		var row := Rect2(r.position.x + 36.0, y, r.size.x - 72.0, REVEAL_ROW_H - 14.0)
		draw_rect(row, Color(0.13, 0.145, 0.19, 0.92 * a), true)
		draw_rect(row, Color(col.r, col.g, col.b, 0.88 * a), false, 1.6)
		draw_rect(Rect2(row.position.x, row.position.y, 5.0, row.size.y),
				Color(col.r, col.g, col.b, a), true)
		draw_string(_font_bold, row.position + Vector2(22, 32),
				str(item.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT,
				row.size.x - 44, UiTheme.FS_SUBHEAD, Color(0.96, 0.93, 0.86, a))
		draw_string(_font, row.position + Vector2(22, 58),
				str(item.get("sub", "")), HORIZONTAL_ALIGNMENT_LEFT,
				row.size.x - 44, UiTheme.FS_CAPTION, Color(0.66, 0.69, 0.75, a))
	if _reveal_finished():
		# R353：「继续」画成按钮 —— 可交互性靠 UI 表达，不写「点击任意处继续」。
		var btn := Rect2(r.position.x + r.size.x / 2.0 - 70.0, r.end.y - 34.0, 140.0, 28.0)
		draw_rect(btn, Color(0.30, 0.40, 0.26, 0.95), true)
		draw_rect(btn, Color("c8f0a0"), false, 1.5)
		draw_string(_font_bold, btn.position + Vector2(0, 19), "继 续",
				HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, UiTheme.FS_CAPTION, Color("0e2010"))
