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
## ⚠️ R682 用户口径改口：「两个按钮都去掉，明暗地显示一段：点击任意位置关闭」。
##    正文面板因此**既没有「收下」、也没有右上角 X**，底部只留一行压暗的小字。
##    「收下」没有取消，只是并进了「关」：点任意位置关掉面板时，这一段若是 ready
##    就顺手发下来（`_close_detail()` 是唯一口），发的仍是 `ProfileData.claim_episode()`，
##    解锁动画照播。R346 的「条件达成 ≠ 发奖励」依旧成立 —— 触发点仍然是玩家的
##    **一次点击**，不是「条件一达成自动到账」。
##
## 六章正文已齐；未来新增空正文段时仍由通用 locked 规则挡住。
## 填内容只需要改 `stories.json`，这个界面不用另开特例。
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
##   `-- --scrollto N`                 列表钉在滚动 N 行（一张图看到上箭头 + 下箭头 + 滑块）
##   `-- --longstory`                  正文在内存里接三遍（验证正文滚动，不写 stories.json）
##
## 滚动（R671）：**列表与正文都给「细滚动条 + 双箭头」**，见规范 §4.12.2。
##   用户口径：「没有下拉条，也没有提示箭头，玩家可能意识不到故事下面还有」——
##   实测 11 段只显示 7 行、右侧全空白，唯一的线索是底部那行 12px 小字；
##   正文更糟：超出可视区直接画「…」就 break，**后面的字根本没落笔**。
##   所以这里对 §4.12「不画滚动条」破例：阅读容器要的是「还剩多少」，箭头答不了。
##   * 几何唯一口：`_list_track()` / `_body_track()` / `_bar_thumb_rect()`（画与拖同源）
##   * 滚动位移唯一口：`_set_list_scroll()` / `_set_body_scroll()`（含 clamp）
##   * 手势唯一口：`UiDrag.scroll_delta()`（滚轮 / 鼠标拖 / 触屏拖同一套，规范 §4.12.1）
##   ⚠️ 点击一律「按下记意图、抬起才执行」：触屏滑动的第一个事件就是 pressed，
##      按下即打开会让「滑动列表」永远变成「误开一段」。

const UiTheme = preload("res://scripts/ui_theme.gd")
const UiRoute = preload("res://scripts/ui_route.gd")

const ROW_H := 76.0
const ROW_W := 980.0
const LIST_Y := 132.0
## R352 解锁动画的节奏：每张间隔 / 单张淡入时长 / 行高。
const REVEAL_INTERVAL := 0.30
const REVEAL_FADE := 0.26
const REVEAL_ROW_H := 92.0
## R671 滚动提示：列表与正文共用同一套「细滚动条 + 双箭头」。
const ScrollHint = preload("res://scripts/ui_scroll_hint.gd")
const UiDrag = preload("res://scripts/ui_drag.gd")
const BAR_W := 8.0             ## 滚动条视觉宽
const BAR_HIT_W := 20.0        ## 拖动命中区宽（比视觉宽 —— 只画不留命中等于点不到）
const BODY_LINE_H := 26.0      ## 正文行距（与旧绘制一致，别再算第二份）
const BODY_TEXT_INSET := 20.0  ## 有滚动条时正文右侧让出的宽度

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
## R671 滚动：正文行偏移 / 正文换行缓存 / 缓存对应的正文宽度。
var _body_scroll := 0
var _body_lines: Array[String] = []
var _body_w_cached := -1.0
## R671 拖动：正在拖哪条滚动条（"" / "list" / "body"）+ 按下点相对滑块顶的偏移。
var _bar_drag := ""
var _bar_grab_dy := 0.0
## R671 按下位置（抬起才执行）：列表行 / 收下 / 关闭 —— 触屏滑动不算点击（规范 §4.12.1）。
var _press_pos := Vector2.INF
var _breath_acc := 0.0
## R671 拖动余量（像素）：折成整行剩下的部分留到下一次，慢拖也不会卡住不动。
var _drag_accum := 0.0


func _ready() -> void:
	UiTheme.attach_stage(self)   # R519：宽屏下内容居中，背景溢出铺满两侧
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
			var si := clampi(int(args[di + 1]), 0, _episodes.size() - 1)
			if "--longstory" in args:
				# 出图：把这一段正文在**内存里**接三遍，专门验证正文滚动条 / 上下箭头
				# （真实故事目前最长 161 字，装得下 —— 长文本是给译文和以后的章节留的余量）。
				var raw: Array = (_episodes[si] as Dictionary).get("text", [])
				var long_text: Array = []
				for _k in 3:
					long_text.append_array(raw)
				(_episodes[si] as Dictionary)["text"] = long_text
			_open_detail(si)
		# 出图：把列表钉在滚动中段，一张图能同时看到上箭头 + 下箭头 + 滑块。
		var bi := args.find("--scrollto")
		if bi >= 0 and bi + 1 < args.size():
			_scroll = clampi(int(args[bi + 1]), 0,
					maxi(0, _episodes.size() - _max_rows()))
		# 出图：正文滚到第 N 行（配合 --longstory 拍「上箭头也出现」的样子）。
		var bsi := args.find("--bodyscroll")
		if bsi >= 0 and bsi + 1 < args.size():
			_body_scroll = maxi(0, int(args[bsi + 1]))
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
		"back": GameI18n.ui("shell", "STORY_MENU_CONTINUE", "继续"),
		"sub": GameI18n.ui("shell", "STORY_MENU_SUBTITLE", "故事"),
	})


func _menu_items() -> Array:
	return [
		{"text": func(): return GameI18n.ui("shell", "STORY_SOUND_ON", "音效：开") if sfx.enabled else GameI18n.ui("shell", "STORY_SOUND_OFF", "音效：关"),
			"fn": _toggle_sound, "keep_open": true},
		# R590：文案跟着去向走（从百科进来写「返回百科」），行为不变。
		{"text": func(): return GameI18n.ui("shell", "STORY_MENU_BACK_CODEX", "返回百科") if UiRoute.has_back() else GameI18n.ui("shell", "STORY_MENU_BACK_TITLE", "返回标题"),
					"fn": _back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _refresh() -> void:
	# R534：列表 = 全部 episode + 追加故事（profiles，排在最后）。
	_episodes = _repo.entries.duplicate()
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
			# R596：带数值后缀下限的条件要灌一个真实达标后缀，__demo 不能冒充难度。
			var suffix_min := int(ach.get("stat_suffix_min", -1))
			var suffix := "__demo" if suffix_min < 0 else str(suffix_min)
			ProfileData.bump(str(ach.get("stat_prefix", "demo:")) + suffix, need)
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


# ------------------------------------------------------------ 滚动几何（R671）
#
# ⚠️ 绘制与命中**必须同源**：滚动条画在哪、哪里能拖，都只读下面这几个函数。
#    分开算一次是「看得见摸不到」的经典来源。

func _list_max_scroll() -> int:
	return maxi(0, _episodes.size() - _max_rows())


func _list_track() -> Rect2:
	## 列表滚动条：竖排在列表右沿**外侧**的空白带里（1280 宽时右沿 1130，右侧还剩 150）。
	## 窄屏放不下就贴回窗口右边缘 —— 别让滚动条跑到屏幕外。
	var right := (size.x + ROW_W) * 0.5
	var x := minf(right + 14.0, size.x - BAR_W - 10.0)
	var top := LIST_Y
	var bottom := LIST_Y + _max_rows() * ROW_H - 10.0
	return Rect2(x, top, BAR_W, bottom - top)


func _list_bar_hit() -> Rect2:
	## 拖动命中区比视觉条宽（BAR_HIT_W > BAR_W）：8px 宽的条手指根本点不准。
	var t := _list_track()
	return Rect2(t.position.x - (BAR_HIT_W - BAR_W) * 0.5, t.position.y - 4.0,
			BAR_HIT_W, t.size.y + 8.0)


func _body_top() -> float:
	## 正文第一行的**基线**。从 r.y+82 下移到 +94：给「上面还有」的上箭头留出
	## 两枚 chevron 的高度（旧值会让箭头压在标题分隔线上）。
	return _detail_rect().position.y + 94.0


func _body_bottom() -> float:
	## 正文可视区底界（不含）。比旧截断线（r.end.y - 96）收到 -136：
	## 下箭头要落在奖励分隔线（r.end.y - 108）**上方**，否则箭头压着「看完解锁…」那行。
	return _detail_rect().end.y - 136.0


func _body_rows() -> int:
	return maxi(1, int(floor((_body_bottom() - _body_top()) / BODY_LINE_H)) + 1)


func _body_max_scroll() -> int:
	return maxi(0, _body_lines.size() - _body_rows())


func _body_overflow() -> bool:
	return _body_lines.size() > _body_rows()


func _body_text_w() -> float:
	## 正文宽度**恒按「有滚动条」算**（左侧恒定，不随溢出与否变）。
	## ⚠️ 别写成「有溢出才收窄」—— 收窄会改变换行 → 行数变 → 溢出判断自己抖，
	##    实测在临界长度上滑块会一帧有一帧无。
	return _detail_rect().size.x - 56.0 - BODY_TEXT_INSET


func _body_track() -> Rect2:
	var r := _detail_rect()
	return Rect2(r.end.x - 26.0, _body_top() - 16.0, BAR_W,
			_body_bottom() - _body_top() + 16.0)


func _body_bar_hit() -> Rect2:
	var t := _body_track()
	return Rect2(t.position.x - (BAR_HIT_W - BAR_W) * 0.5, t.position.y,
			BAR_HIT_W, t.size.y)


func _bar_thumb_rect(track: Rect2, ratio: float, t: float) -> Rect2:
	## 滑块矩形 —— **绘制与拖动共用**。两处各算一次，就会出现「看到的位置点不到」。
	## 最小 22px：内容再长，滑块也不能细成一条线（手指点不到、眼睛看不见）。
	var th := clampf(track.size.y * clampf(ratio, 0.04, 1.0), 22.0, track.size.y)
	var y := track.position.y + (track.size.y - th) * clampf(t, 0.0, 1.0)
	return Rect2(track.position.x, y, track.size.x, th)


func _bar_grab_offset(track: Rect2, ratio: float, t: float, my: float) -> float:
	## 按下点相对滑块顶的偏移。点在轨道空白处 = 抓住滑块中心（滑块直接跟过去）。
	var th := _bar_thumb_rect(track, ratio, t)
	if my < th.position.y or my > th.end.y:
		return th.size.y * 0.5
	return my - th.position.y


func _bar_scroll_at(track: Rect2, ratio: float, max_scroll: int, my: float) -> int:
	## 鼠标 y → 滚动量（抓取式：滑块顶始终跟着指针，拖多久都不会越拖越偏）。
	var th := _bar_thumb_rect(track, ratio, 0.0)
	var travel := maxf(track.size.y - th.size.y, 1.0)
	var t := clampf((my - _bar_grab_dy - track.position.y) / travel, 0.0, 1.0)
	return int(round(t * float(max_scroll)))


func _draw_bar(track: Rect2, ratio: float, t: float) -> void:
	## 细滚动条（轨道 + 滑块）。配色沿用语言选择页的 BRASS 系，不新造令牌。
	## ⚠️ 滑块用 BRASS 再压暗一档：原色压在米色纸面上只差 ~70 灰阶，
	##    1280 下看就是一条若有若无的淡线 —— 玩家认不出那是「能拖的」。
	## ⚠️ 只在**真的溢出**时调用：装得下却挂一根条，等于骗玩家「下面还有」。
	var lit := track.grow(7.0).has_point(get_local_mouse_position())
	draw_rect(track, Color(0.30, 0.26, 0.18, 0.22), true)
	draw_rect(track, Color(UiTheme.ADVENTURE_BRASS, 0.70), false, 0.8)
	var thumb := _bar_thumb_rect(track, ratio, t)
	var fill := UiTheme.ADVENTURE_BRASS.darkened(0.16 if lit else 0.26)
	draw_rect(thumb, fill, true)
	draw_rect(thumb, Color(UiTheme.ADVENTURE_BRASS_LIT, 0.92), false, 0.8)


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
		_detail_input(event)
		return
	_list_input(event)


func _list_input(event: InputEvent) -> void:
	## 列表页：滚轮 / 拖滚动条 / 按住内容拖 / 点行。
	## R671 起「按下只记意图、抬起才执行」（规范 §4.12.1 第 2 条）：
	## 触屏一滑，最先到的就是 pressed —— 按下即打开的话，滑动列表必然误开一段。
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _bar_drag == "list":
			_set_list_scroll(_bar_scroll_at(_list_track(),
					float(_max_rows()) / float(maxi(1, _episodes.size())),
					_list_max_scroll(), mm.position.y))
			return
		if _press_pos != Vector2.INF and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if _drag_rows(event):
				_hover = -1
				return
		_hover = _row_at(mm.position)
		queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP \
				or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_set_list_scroll(_scroll + (2 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -2))
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_pos = mb.position
			_drag_accum = 0.0
			if _list_bar_hit().has_point(mb.position):
				_bar_drag = "list"
				_bar_grab_dy = _bar_grab_offset(_list_track(),
						float(_max_rows()) / float(maxi(1, _episodes.size())),
						float(_scroll) / float(maxi(1, _list_max_scroll())), mb.position.y)
				_press_pos = Vector2.INF
			return
		# —— 抬起：拖动收尾，或者真的是一次点击
		var dragged := _bar_drag == "list"
		_bar_drag = ""
		var press := _press_pos
		_press_pos = Vector2.INF
		if dragged or press == Vector2.INF or UiDrag.drag_moved(press, mb.position):
			queue_redraw()
			return
		if _back_rect().has_point(press):
			sfx.play("click")
			_back_to_title()
			return
		var hit := _row_at(press)
		if hit >= 0:
			sfx.play("click")
			_open_detail(hit)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _detail_input(event: InputEvent) -> void:
	## 正文面板：正文滚动（滚轮 / 拖滚动条 / 按住正文拖 / ↑↓ PgUp PgDn）+ 收下 / 关闭。
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _bar_drag == "body":
			_set_body_scroll(_bar_scroll_at(_body_track(),
					float(_body_rows()) / float(maxi(1, _body_lines.size())),
					_body_max_scroll(), mm.position.y))
			return
		if _press_pos != Vector2.INF and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 \
				and _detail_rect().has_point(_press_pos):
			if _drag_rows(event):
				return
		queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP \
				or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_set_body_scroll(_body_scroll
						+ (2 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -2))
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_pos = mb.position
			_drag_accum = 0.0
			if _body_overflow() and _body_bar_hit().has_point(mb.position):
				_bar_drag = "body"
				_bar_grab_dy = _bar_grab_offset(_body_track(),
						float(_body_rows()) / float(maxi(1, _body_lines.size())),
						float(_body_scroll) / float(maxi(1, _body_max_scroll())), mb.position.y)
				_press_pos = Vector2.INF
			return
		var dragged := _bar_drag == "body"
		_bar_drag = ""
		var press := _press_pos
		_press_pos = Vector2.INF
		if dragged or press == Vector2.INF or UiDrag.drag_moved(press, mb.position):
			queue_redraw()
			return
		# R682：面板上没有按钮了 —— 点**任意位置**（面板内 / 面板外）都是收尾动作。
		# 拖正文 / 拖滚动条在上面已被 `_bar_drag` 与 `UiDrag.drag_moved()` 挡掉，
		# 所以「滑动阅读」不会被误判成一次点击。
		sfx.play("click")
		_close_detail()
		return
	if event is InputEventKey and event.pressed:
		var step := 0
		match event.keycode:
			KEY_UP: step = -1
			KEY_DOWN: step = 1
			KEY_PAGEUP: step = -_body_rows()
			KEY_PAGEDOWN: step = _body_rows()
		if step != 0:
			_set_body_scroll(_body_scroll + step)
			get_viewport().set_input_as_handled()


func _drag_rows(event: InputEvent) -> bool:
	## 「按住内容拖」的公共尾段：像素位移按行高折成整行，余量留着下一次（不丢手感）。
	var d := UiDrag.scroll_delta(event, 0.0)
	if d == 0.0:
		return false
	_drag_accum += d
	var rows := int(_drag_accum / BODY_LINE_H)
	if rows != 0:
		_drag_accum -= float(rows) * BODY_LINE_H
		if _sel >= 0:
			_set_body_scroll(_body_scroll + rows)
		else:
			_set_list_scroll(_scroll + rows)
	return true


func _set_list_scroll(v: int) -> void:
	var nv := clampi(v, 0, _list_max_scroll())
	if nv != _scroll:
		_scroll = nv
	queue_redraw()


func _set_body_scroll(v: int) -> void:
	var nv := clampi(v, 0, _body_max_scroll())
	if nv != _body_scroll:
		_body_scroll = nv
	queue_redraw()


func _open_detail(idx: int) -> void:
	if idx < 0 or idx >= _episodes.size():
		return
	_sel = idx
	_hover = -1
	_body_scroll = 0
	_body_w_cached = -1.0   # 强制下一帧按当前宽度重新换行
	_body_lines = []
	queue_redraw()


func _close_detail() -> void:
	## R682：**关掉就是收下**。面板上已经没有「收下这一段」按钮，玩家读完点任意位置关闭，
	## 这一次点击同时充当领取动作 —— 否则奖励永远发不下去（R346 的坑不能踩回去）。
	##   * ready（条件已达成、还没领）→ 关掉 + 发奖励 + 播解锁动画
	##   * locked / read             → 只是关掉
	## ⚠️ 先记 idx 再清 `_sel`：`_claim()` 失败弹的是**列表页**的 toast，不该留在面板里。
	## ⚠️ 幂等：`_sel < 0` 直接返回；`_claim()` 里自己清 `_sel`，不会再绕回来。
	var idx := _sel
	if idx < 0:
		return
	_sel = -1
	queue_redraw()
	if idx >= _episodes.size():
		return
	var eid := str((_episodes[idx] as Dictionary).get("id", ""))
	if _repo.episode_state(eid) == StoryRepo.STATE_READY:
		_claim(idx)


func _claim(idx: int) -> void:
	var ep: Dictionary = _episodes[idx]
	var eid := str(ep.get("id", ""))
	var res := ProfileData.claim_episode(_repo, eid)
	if not bool(res.get("ok", false)):
		_set_toast(str(res.get("reason", GameI18n.ui("shell", "STORY_CLAIM_UNAVAILABLE", "现在还不能解锁"))))
		sfx.play("lose")
		return
	sfx.play("win")
	_sel = -1
	queue_redraw()
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
	# R671：只有**真的溢出**才需要呼吸重绘（箭头不动就不醒目）；20fps 足够，
	# 逐帧重绘纯属白烧电量（安卓上更明显）。
	# R683：正文面板底部那行「点击任意位置关闭」现在也呼吸 —— 短正文（不溢出）的面板
	# 同样要跟着重绘，否则一段三行的正文打开后提示是死的。判据因此放宽到 `_sel >= 0`。
	if _list_max_scroll() > 0 or _sel >= 0:
		_breath_acc += delta
		if _breath_acc >= 0.05:
			_breath_acc = 0.0
			queue_redraw()


func _back_to_title() -> void:
	## R590：从百科进来的 → 退回百科（玩家刚从那页来，丢回标题等于让他重走一趟）。
	## 去向由 `UiRoute` 记（`SceneFx.goto` 不带参数），`take_back()` 取一次就清空，
	## 否则下次从别处进故事页会莫名退回百科。
	var back := UiRoute.take_back()
	SceneFx.goto(back if back != "" else "res://scenes/title.tscn")


func _back_label() -> String:
	## 返回按钮文案跟着**实际去向**走（R590）：从百科进来就写「返回百科」。
	## ⚠️ 只改文案，不改行为 —— 去向一律由 `_back_to_title()` 里的 UiRoute 决定。
	return GameI18n.ui("shell", "STORY_BACK_CODEX", "← 返回百科") if UiRoute.has_back() else GameI18n.ui("shell", "STORY_BACK_TITLE", "← 返回标题")


# ------------------------------------------------------------ 三态图标

func _state_color(st: String) -> Color:
	## 三态配色唯一口：左沿色条 / 顶部图例 / 列表图标 / 正文面板标题前全读它。
	## 想改「可查看是金、已读是绿」只改这里一处。
	if st == StoryRepo.STATE_READY:
		return UiTheme.PAGE_INK     # 金：有东西可看，等你点开
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
	UiTheme.draw_page(self, UiTheme.bleed_rect(self))   # R519：铺满窗口
	draw_string(_font_bold, Vector2(0, 62), GameI18n.ui("shell", "STORY_TITLE", "故 事"), HORIZONTAL_ALIGNMENT_CENTER,
			size.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
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
	UiTheme.draw_action(self, back, false, false, hov_back)
	draw_string(_font_bold, back.position + Vector2(0, 22), _back_label(),
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	if _episodes.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 40),
				GameI18n.ui("shell", "STORY_EMPTY", "还没有任何剧情段（stories.json 是空的）。"),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)
		return
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _episodes.size():
			break
		_draw_row(idx, _episodes[idx])
	if _episodes.size() > _max_rows():
		# R671：右侧滚动条 + 上下双箭头。**先让玩家知道下面还有**，才谈得上往下看 ——
		# 旧版只有底注那行 12px 小字，列表看起来像已经到底了。
		var track := _list_track()
		_draw_bar(track, float(_max_rows()) / float(_episodes.size()),
				float(_scroll) / float(maxi(1, _list_max_scroll())))
		ScrollHint.draw(self, track.get_center().x, track.position.y - 4.0,
				track.end.y + 4.0, _scroll > 0, _scroll < _list_max_scroll(),
				ScrollHint.breath())
		# R630：底注原来画在 `size.y - 12`（720 → 基线 708），而 `draw_page()`
		# 的纸面内框只到 `size.y - 16`（704）—— 这一行是**整个坐在框外**、还被框线
		# 横切过去（用户口径「有一些文本超出框」）。九宫格边框本身还有 ~12~14 的厚度，
		# 光收进 -16 仍会压在边框上，所以收到 -36（字底落在内框内侧，留 5 左右）。
		draw_string(_font, Vector2(0, size.y - 36),
				GameI18n.ui("shell", "STORY_RANGE", "第 %d–%d 段 / 共 %d 段")
				% [_scroll + 1, mini(_scroll + _max_rows(), _episodes.size()), _episodes.size()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				UiTheme.PAGE_MUTED)
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
	var bg := UiTheme.PAGE_PAPER
	if not locked:
		bg = UiTheme.ADVENTURE_INPUT
	if hov:
		bg = bg.lightened(0.08)
	draw_rect(r, bg, true)
	draw_rect(r, UiTheme.ADVENTURE_BRASS, false, 1.6)
	# 左沿状态色条（与右侧图标同源；压暗一档免得抢标题）
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			_state_color(st).darkened(0.34), true)
	# 章节小标
	var chap := str(ep.get("chapter", "?"))
	draw_string(_font, r.position + Vector2(20, 26), chap,
			HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
	# 标题（锁着就是 ？？？）
	var title := _repo.episode_label(ep)
	var tcol := Color("6f7684") if locked else UiTheme.PAGE_INK
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
				HORIZONTAL_ALIGNMENT_RIGHT, 372, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)


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
	draw_rect(UiTheme.bleed_rect(self), Color(0, 0, 0, 0.58), true)
	UiTheme.draw_panel_bg(self, r)
	var ep: Dictionary = _episodes[_sel]
	var eid := str(ep.get("id", ""))
	var st := _repo.episode_state(eid)
	var x0 := r.position.x + 28.0
	var x1 := r.end.x - 28.0
	var w := x1 - x0
	# 标题前也放同一个小图标（列表里认什么、打开还是什么，不用再读文字判断）
	_draw_state_icon(Vector2(x0 + 11.0, r.position.y + 30.0), st, 0.95)
	draw_string(_font_bold, Vector2(x0 + 34.0, r.position.y + 38.0), _repo.episode_label(ep),
			HORIZONTAL_ALIGNMENT_LEFT, w - 94.0, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	draw_line(Vector2(x0, r.position.y + 54.0), Vector2(x1, r.position.y + 54.0),
			Color("3d424e"), 1.0)
	# 正文
	var y := r.position.y + 82.0
	if st == StoryRepo.STATE_LOCKED:
		draw_string(_font_bold, Vector2(x0, y), GameI18n.ui("shell", "STORY_DETAIL_LOCKED", "这一段还没有解锁"),
				HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)
		y += 28.0
		for line: String in TextWrap.wrap_plain(_font, _repo.requirement_text(eid),
				w, UiTheme.FS_LABEL):
			draw_string(_font, Vector2(x0, y), line, HORIZONTAL_ALIGNMENT_LEFT, w,
					UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
			y += 22.0
	else:
		# R671：正文改成可滚 —— 旧版超出可视区就画一个「…」了事，
		# 后面的文字**根本没有落笔**，玩家永远读不到（比没有滚动条更糟）。
		_draw_body(eid)
	# 奖励预览（这一段的 grants）
	var g := _repo.episode_grants(eid)
	var cards: Array = g.get("cards", [])
	var relics: Array = g.get("relics", [])
	var gy := r.end.y - 92.0
	draw_line(Vector2(x0, gy - 16.0), Vector2(x1, gy - 16.0), Color("3d424e"), 1.0)
	var gtxt := GameI18n.ui("shell", "STORY_DETAIL_NO_REWARD", "看完这一段没有额外奖励。")
	if not cards.is_empty() or not relics.is_empty():
		gtxt = GameI18n.ui("shell", "STORY_DETAIL_REWARDS", "看完解锁：卡牌 %d 张 · 道具 %d 件（加入奖励池）") % [cards.size(), relics.size()]
	draw_string(_font, Vector2(x0, gy), gtxt, HORIZONTAL_ALIGNMENT_LEFT, w,
			UiTheme.FS_LABEL, Color("b9ae8a"))
	# R682：**这里没有按钮了**。原来「收下这一段」和右上角 X 一起撤掉，只留一行压暗的小字。
	# ⚠️ 这是 R353「界面不写操作教学」的一处**显式破例**：那条规矩的前提是界面上有可见
	#    控件去表达可交互性；两个按钮都撤之后，正文面板确实需要一个「怎么出去」的提示。
	# R683：**呼吸**。用户口径「点击任意位置关闭有明暗闪烁吗」—— 原来是一格写死的 0.88，
	# 一动不动，压在满屏正文下面很难被注意到。这里接 `ScrollHint.breath()`（滚动箭头用的
	# 同一套节律，2.6 rad/s ≈ 2.4s 一呼一吸），只有下面这个透明度在动，颜色令牌不换。
	# 0.68~0.92：谷底仍读得清（纯黑底都没有，下面是米色纸面），峰顶不超过原来那格 0.88 太多。
	var bk := (ScrollHint.breath() - 0.72) / 0.28
	draw_string(_font, Vector2(r.position.x, r.end.y - 30.0),
			GameI18n.ui("shell", "STORY_DETAIL_CLICK_ANYWHERE", "点击任意位置关闭"),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_LABEL,
			Color(UiTheme.PAGE_MUTED, 0.68 + 0.24 * bk))


func _draw_body(eid: String) -> void:
	## 正文按行滚动绘制 + 滚动条 + 上下双箭头（R671）。
	## 行号→y 的唯一换算：`_body_top() + (i - _body_scroll) * BODY_LINE_H`。
	var x0 := _detail_rect().position.x + 28.0
	var tw := _body_text_w()
	if tw != _body_w_cached:
		# 宽度变了（刚开面板 / 改过窗口）→ 重新换行；行数一变，滚动量必须跟着收，
		# 否则上一段留在底部的滚动量会让新段一打开就是中段。
		_body_w_cached = tw
		_body_lines = _wrapped_body(eid, tw)
		_body_scroll = clampi(_body_scroll, 0, _body_max_scroll())
	var top := _body_top()
	var rows := _body_rows()
	for i in range(_body_scroll, mini(_body_scroll + rows, _body_lines.size())):
		draw_string(_font, Vector2(x0, top + float(i - _body_scroll) * BODY_LINE_H),
				_body_lines[i], HORIZONTAL_ALIGNMENT_LEFT, tw, UiTheme.FS_BODY,
				UiTheme.PAGE_INK)
	if not _body_overflow():
		return
	var track := _body_track()
	_draw_bar(track, float(rows) / float(_body_lines.size()),
			float(_body_scroll) / float(maxi(1, _body_max_scroll())))
	ScrollHint.draw(self, track.get_center().x, top - 16.0, _body_bottom() + 2.0,
			_body_scroll > 0, _body_scroll < _body_max_scroll(), ScrollHint.breath())


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
			"sub": GameI18n.ui("shell", "STORY_REVEAL_CARD_META", "%s · %s · %d 费") % [CardData.RARITY_NAMES[rar],
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
			"sub": GameI18n.ui("shell", "STORY_REVEAL_RELIC_META", "道具 · %s") % r.tier_label(),
			"col": r.tier_color(),
		})
	_reveal_t = 0.0
	if _reveal.is_empty():
		_set_toast(GameI18n.ui("shell", "STORY_REVEAL_NO_REWARD", "已解锁（这一段没有额外奖励）"))
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
	draw_rect(UiTheme.bleed_rect(self), Color(0, 0, 0, 0.76), true)
	UiTheme.draw_panel_bg(self, r)
	draw_string(_font_bold, Vector2(r.position.x, r.position.y + 44), GameI18n.ui("shell", "STORY_REVEAL_TITLE", "解 锁"),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	draw_string(_font, Vector2(r.position.x, r.position.y + 70),
			GameI18n.ui("shell", "STORY_REVEAL_SUBTITLE", "以下内容已加入奖励池"),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	for i in n:
		var a := clampf((_reveal_t - i * REVEAL_INTERVAL) / REVEAL_FADE, 0.0, 1.0)
		if a <= 0.0:
			continue
		var item: Dictionary = _reveal[i]
		var col: Color = item.get("col", UiTheme.PAGE_INK)
		var y := r.position.y + 92.0 + i * REVEAL_ROW_H + (1.0 - a) * 16.0
		var row := Rect2(r.position.x + 36.0, y, r.size.x - 72.0, REVEAL_ROW_H - 14.0)
		draw_rect(row, Color(UiTheme.PAGE_PAPER, a), true)
		draw_rect(row, Color(col.r, col.g, col.b, 0.88 * a), false, 1.6)
		draw_rect(Rect2(row.position.x, row.position.y, 5.0, row.size.y),
				Color(col.r, col.g, col.b, a), true)
		draw_string(_font_bold, row.position + Vector2(22, 32),
				GameI18n.source(str(item.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT,
				row.size.x - 44, UiTheme.FS_SUBHEAD, Color(UiTheme.PAGE_INK, a))
		draw_string(_font, row.position + Vector2(22, 58),
				GameI18n.source(str(item.get("sub", ""))), HORIZONTAL_ALIGNMENT_LEFT,
				row.size.x - 44, UiTheme.FS_CAPTION, Color(UiTheme.PAGE_MUTED, a))
	if _reveal_finished():
		# R353：「继续」画成按钮 —— 可交互性靠 UI 表达，不写「点击任意处继续」。
		var btn := Rect2(r.position.x + r.size.x / 2.0 - 70.0, r.end.y - 34.0, 140.0, 28.0)
		UiTheme.draw_secondary_btn(self, btn, GameI18n.ui("shell", "STORY_REVEAL_CONTINUE", "继续"), false, false, true)
