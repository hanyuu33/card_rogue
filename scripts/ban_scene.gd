extends Control
## 禁卡表（R346）—— 开局前（角色选择页「禁卡表」）把不想要的卡从**奖励池**里永久摘掉。
##
## 规则（R352 用户口径，覆盖 R346 的扁平口径）：
##   「每获得一张卡，新增一个 ban 位（公用卡则是每个职业一个 ban 位），玩家可以在
##    ban 卡界面选择同等稀有度的卡，将其禁用，使其不会出现在奖励池。」
##   → 禁卡表**按职业记账**：一页一个职业，三个职业各自的名额与禁用互不相干。
##   → 额度按稀有度分档，算法唯一口 = `ProfileData.ban_quota_for(repo, 职业)`：
##       · 解锁一张**职业卡** → 该职业 +1 个该档名额；
##       · 解锁一张**公用卡**（class 为空）→ **三个职业各** +1 个该档名额
##         （它在三个职业的奖励池里都会出现，所以要 ban 三次）。
##   → 没有任何卡被剧情解锁时额度是 0，一行都禁不了 —— 这是**正确表现**，
##     不是 bug（界面会写明「暂时没有禁卡名额」）。
##
## ⚠️ **局内只认开局快照**（`RunState.run_bans`）：在这里改禁用**不影响**正在进行的这一局，
##    下一局开局时才生效（用户口径：「当前正在进行的战斗只遵照开始前设置的禁用」）。
##
## 禁卡是**账号级**选择（存 `ProfileData.banned_by_class`），可以随时取消。
## 禁掉的卡不会消失于这个列表（否则点一下就没了、再也点不回来）——
## 列表口径 = `CardRepo.obtainable_cards()`（奖励池的**去禁卡版**）。
##
## 出图参数：`-- --screenshot`（可加 `--demo`：在测试档案里解锁几张卡，看满额度态）
##
## R851（安卓拖动）：列表原来只认 `MOUSE_BUTTON_WHEEL_*`，触屏没有滚轮 → 下半截永远看不到；
##   而且点行在 `event.pressed` 就执行 → 手指一滑的**第一帧**就把卡给禁了。
##   现在与故事页同一套：手势口 `UiDrag.scroll_delta`（鼠标拖 / 触屏拖同一手感）、
##   细滚动条 + 上下双箭头（画与拖同源）、点击一律「按下记意图、抬起且没拖才执行」。

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_H := 40.0
const ROW_W := 980.0
const LIST_Y := 196.0
const UiDrag = preload("res://scripts/ui_drag.gd")
const ScrollHint = preload("res://scripts/ui_scroll_hint.gd")
const BAR_W := 8.0             ## 滚动条视觉宽
const BAR_HIT_W := 20.0        ## 拖动命中区宽（只画不给命中 = 手指点不到）

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _repo: CardRepo = null
var _cards: Array = []
var _hover := -1
var _scroll := 0
## R352：当前正在看的职业（禁卡表按职业分页）。
var _cls := ""
var _toast := ""
var _toast_t := 0.0
var _last_mp := Vector2.INF
## R851 拖动：正在拖哪条滚动条（"" / "list"）+ 按下点相对滑块顶的偏移。
var _bar_drag := ""
var _bar_grab_dy := 0.0
## R851 按下位置（抬起才执行）：触屏第一下就是 pressed，按下即切禁会把滑动误判成点禁卡。
var _press_pos := Vector2.INF
## R851 拖动余量（像素）：按 ROW_H 折成整行，余量留到下一次（慢拖也不卡住）。
var _drag_accum := 0.0
var _breath_acc := 0.0


func _ready() -> void:
	UiTheme.attach_stage(self)   # R519：宽屏下内容居中，背景溢出铺满两侧
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	var args := OS.get_cmdline_user_args()
	if "--demo" in args:
		ProfileData.set_test_mode()
		_demo_unlock()
	_repo = CardRepo.load_json()
	ProfileData.ensure_loaded()
	_cls = PlayerClass.ids()[0]
	# 出图用：`-- --cls rogue` 直接切到指定职业页签（验收三职业记账，R352）。
	var _ci := args.find("--cls")
	if _ci >= 0 and _ci + 1 < args.size() and PlayerClass.ids().has(str(args[_ci + 1])):
		_cls = str(args[_ci + 1])
	_refresh()
	# 出图用：`-- --banfirst` 先禁掉第一张点得动的卡（看在册禁用行的样子）。
	if "--banfirst" in args:
		for _bc: CardData in _cards:
			if ProfileData.can_ban_for(_bc.id, _repo, _cls):
				_toggle(_bc)
				break
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_ban.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": GameI18n.ui("shared", "BAN_MENU_CONTINUE", "继续"),
		"sub": GameI18n.ui("shared", "BAN_MENU_SUBTITLE", "禁卡表"),
	})


func _demo_unlock() -> void:
	## 出图用（只写测试档案，退出即丢）：**每个职业每档各 3 张** + 两张公用剧情卡。
	## R352 改口径：以前是「每档整体 3 张」，谁 id 小谁被解锁 → 三张图全是暗影的卡，
	## 另外两个页签名额是 0，验收「公用卡给三个职业各 +1」的效果根本看不到。
	var repo := CardRepo.load_json()
	var count := {}
	for c: CardData in repo.obtainable_cards():
		if c.card_class == "":
			continue            # 公用卡单独处理（要显式解锁剧情卡）
		var key := "%s|%d" % [c.card_class, c.rarity]
		if int(count.get(key, 0)) >= 3:
			continue
		ProfileData.unlock_card(c.id)
		count[key] = int(count.get(key, 0)) + 1
	ProfileData.unlock_card(9182)   # 摇篮曲：公用史诗
	ProfileData.unlock_card(9183)   # 森林的朋友们：公用稀有


func _menu_items() -> Array:
	return [
		{"text": func(): return GameI18n.ui("shared", "BAN_SOUND_ON", "音效：开") if sfx.enabled else GameI18n.ui("shared", "BAN_SOUND_OFF", "音效：关"),
			"fn": _toggle_sound, "keep_open": true},
		{"text": func(): return GameI18n.ui("shared", "BAN_CLEAR_CLASS", "清空「%s」的禁用") % _cls, "fn": _clear_all},
		{"text": GameI18n.ui("shared", "BAN_BACK_TO_CLASS_PICK", "返回角色选择"), "fn": _back},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _clear_all() -> void:
	ProfileData.clear_bans(_cls)
	sfx.play("click")
	_set_toast(GameI18n.ui("shared", "BAN_CLASS_CLEARED", "已清空「%s」的禁用") % _cls)
	queue_redraw()


func _refresh() -> void:
	# 只列**这个职业拿得到**的卡：公用卡（class 为空）+ 该职业专属卡。
	_cards = []
	for c: CardData in _repo.obtainable_cards():
		if c.card_class != "" and c.card_class != _cls:
			continue
		_cards.append(c)
	# 按「稀有度 → id」排，同档挨在一起（普通 → 稀有 → 史诗），扫一眼就知道各档有多少可禁。
	_cards.sort_custom(func(a: CardData, b: CardData):
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.id < b.id)
	_scroll = 0
	_press_pos = Vector2.INF
	_bar_drag = ""
	_drag_accum = 0.0
	queue_redraw()


# ------------------------------------------------------------ 几何

func _row_rect(i: int) -> Rect2:
	return Rect2((size.x - ROW_W) / 2.0, LIST_Y + (i - _scroll) * ROW_H,
			ROW_W, ROW_H - 6.0)


func _back_rect() -> Rect2:
	return Rect2(14, 14, 150, 34)


func _tab_rect(i: int) -> Rect2:
	## R352：三个职业的页签（禁卡表按职业分页）。
	var n := PlayerClass.ids().size()
	var w := 168.0
	var gap := 10.0
	var total := w * n + gap * (n - 1)
	var x0 := (size.x - total) / 2.0
	return Rect2(x0 + i * (w + gap), 110.0, w, 36.0)


func _max_rows() -> int:
	return maxi(1, int((size.y - LIST_Y - 30.0) / ROW_H))


func _max_scroll() -> int:
	return maxi(0, _cards.size() - _max_rows())


func _list_track() -> Rect2:
	## 竖排在列表右沿外侧的空白带（1280 宽时右沿 1130，右侧还剩 150）。
	## 窄屏放不下就贴回窗口右边缘 —— 别让滚动条跑到屏幕外。
	var right := (size.x + ROW_W) * 0.5
	var x := minf(right + 14.0, size.x - BAR_W - 10.0)
	var top := LIST_Y
	var bottom := LIST_Y + _max_rows() * ROW_H - 10.0
	return Rect2(x, top, BAR_W, bottom - top)


func _list_bar_hit() -> Rect2:
	## 命中区比视觉条宽：8px 的条手指根本点不准。
	var t := _list_track()
	return Rect2(t.position.x - (BAR_HIT_W - BAR_W) * 0.5, t.position.y - 4.0,
			BAR_HIT_W, t.size.y + 8.0)


func _bar_thumb_rect(track: Rect2, ratio: float, t: float) -> Rect2:
	## 滑块矩形 —— **绘制与拖动共用**，分开算一次就是「看得见摸不到」。
	## 最小 22px：内容再长，滑块也不能细成一条线（手指点不到、眼睛看不见）。
	var th := clampf(track.size.y * clampf(ratio, 0.04, 1.0), 22.0, track.size.y)
	var y := track.position.y + (track.size.y - th) * clampf(t, 0.0, 1.0)
	return Rect2(track.position.x, y, track.size.x, th)


func _bar_grab_offset(track: Rect2, ratio: float, t: float, my: float) -> float:
	## 按下点相对滑块顶的偏移；点在轨道空白处 = 抓滑块中心（滑块直接跟过去）。
	var th := _bar_thumb_rect(track, ratio, t)
	if my < th.position.y or my > th.end.y:
		return th.size.y * 0.5
	return my - th.position.y


func _bar_scroll_at(track: Rect2, ratio: float, max_scroll: int, my: float) -> int:
	## 指针 y → 滚动量（抓取式：滑块顶始终跟着手指，拖多久都不会越拖越偏）。
	var th := _bar_thumb_rect(track, ratio, 0.0)
	var travel := maxf(track.size.y - th.size.y, 1.0)
	var t := clampf((my - _bar_grab_dy - track.position.y) / travel, 0.0, 1.0)
	return int(round(t * float(max_scroll)))


func _draw_bar(track: Rect2, ratio: float, t: float) -> void:
	## 细滚动条（轨道 + 滑块），配色沿用 BRASS 系；滑块压暗一档才认得出是可拖的。
	## ⚠️ 只在真的溢出时调用：装得下却挂根条 = 骗玩家「下面还有」。
	var lit := track.grow(7.0).has_point(get_local_mouse_position())
	draw_rect(track, Color(0.30, 0.26, 0.18, 0.22), true)
	draw_rect(track, Color(UiTheme.ADVENTURE_BRASS, 0.70), false, 0.8)
	var thumb := _bar_thumb_rect(track, ratio, t)
	var fill := UiTheme.ADVENTURE_BRASS.darkened(0.16 if lit else 0.26)
	draw_rect(thumb, fill, true)
	draw_rect(thumb, Color(UiTheme.ADVENTURE_BRASS_LIT, 0.92), false, 0.8)


func _set_scroll(v: int) -> void:
	var nv := clampi(v, 0, _max_scroll())
	if nv != _scroll:
		_scroll = nv
	queue_redraw()


func _row_at(pos: Vector2) -> int:
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _cards.size():
			break
		if _row_rect(idx).has_point(pos):
			return idx
	return -1


# ------------------------------------------------------------ 输入

func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and _menu.handle_esc(event):
		return


func _gui_input(event: InputEvent) -> void:
	# R851：滚轮 / 按住内容拖 / 拖滚动条三种翻法（触屏没有滚轮）。
	# 点击一律「按下只记意图、抬起且没拖才执行」—— 触屏滑动的第一帧就是 pressed。
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _bar_drag == "list":
			_set_scroll(_bar_scroll_at(_list_track(),
					float(_max_rows()) / float(maxi(1, _cards.size())),
					_max_scroll(), mm.position.y))
			return
		if _press_pos != Vector2.INF and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if _drag_rows(mm):
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
				var step := 4 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -4
				_set_scroll(_scroll + step)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_pos = mb.position
			_drag_accum = 0.0
			if _max_scroll() > 0 and _list_bar_hit().has_point(mb.position):
				_bar_drag = "list"
				_bar_grab_dy = _bar_grab_offset(_list_track(),
						float(_max_rows()) / float(maxi(1, _cards.size())),
						float(_scroll) / float(maxi(1, _max_scroll())), mb.position.y)
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
			_back()
			return
		# R352：职业页签
		for ti in PlayerClass.ids().size():
			if _tab_rect(ti).has_point(press):
				var ids := PlayerClass.ids()
				if _cls != ids[ti]:
					_cls = ids[ti]
					sfx.play("click")
					_refresh()
				return
		var hit := _row_at(press)
		if hit >= 0:
			_toggle(_cards[hit])
			return
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _drag_rows(mm: InputEventMouseMotion) -> bool:
	## 按住内容拖：像素位移按 ROW_H 折成整行，余量留到下一次（不丢手感）。
	## ⚠️ 单位必须是 ROW_H(40) 而不是正文行距 26，否则手指走 40px 被算成 1.5 行，
	##    安卓上「一碰就飞」（故事页 R735 踩过同一个坑）。
	var d := UiDrag.scroll_delta(mm, 0.0)
	if d == 0.0:
		return false
	_drag_accum += d
	var rows := int(_drag_accum / ROW_H)
	if rows != 0:
		_drag_accum -= float(rows) * ROW_H
		_set_scroll(_scroll + rows)
	return true


func _toggle(c: CardData) -> void:
	## 点一下切禁 / 取消禁。**先看原来是什么状态**再调 toggle（toggle 的返回值是
	## 「操作之后是不是已禁」，但「本来已禁 → 取消成功」也返回 false，两者要分清）。
	var had: bool = ProfileData.is_banned_for(c.id, _cls)
	if had:
		ProfileData.toggle_ban_for(c.id, _repo, _cls)
		sfx.play("click")
		_set_toast(GameI18n.ui("shared", "BAN_CARD_UNBANNED", "已取消：%s（仅「%s」）") % [c.card_name, _cls])
	else:
		if ProfileData.toggle_ban_for(c.id, _repo, _cls):
			sfx.play("attack")
			_set_toast(GameI18n.ui("shared", "BAN_CARD_BANNED", "已禁：%s（「%s」的奖励池不再出现，下一局生效）") % [c.card_name, _cls])
		else:
			sfx.play("lose")
			_set_toast(GameI18n.ui("shared", "BAN_NO_QUOTA", "「%s」这一档没有剩余名额（先通过剧情解锁更多卡牌）")
					% CardData.RARITY_NAMES[clampi(c.rarity, 0, 6)])
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
	# R851：只有真的溢出才需要呼吸重绘（箭头/滑块提示）；20fps 足够。
	if _max_scroll() > 0:
		_breath_acc += delta
		if _breath_acc >= 0.05:
			_breath_acc = 0.0
			queue_redraw()


func _back() -> void:
	SceneFx.goto("res://scenes/class_pick.tscn")


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	UiTheme.draw_page(self, UiTheme.bleed_rect(self))   # R519：铺满窗口
	draw_string(_font_bold, Vector2(0, 62), GameI18n.ui("shared", "BAN_TITLE", "禁 卡 表"), HORIZONTAL_ALIGNMENT_CENTER,
			size.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	draw_string(_font, Vector2(0, 92),
			GameI18n.ui("shared", "BAN_EXPLANATION", "禁卡表按职业分别记账：解锁一张职业卡 → 该职业 +1 名额；解锁一张公用卡 → 三个职业各 +1"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	# R352：三个职业页签
	var ids := PlayerClass.ids()
	for ti in ids.size():
		var tr := _tab_rect(ti)
		var cur := ids[ti] == _cls
		var hov := tr.has_point(get_local_mouse_position())
		var bg := UiTheme.PAGE_PAPER if cur else (UiTheme.PAGE_PAPER if hov else UiTheme.PAGE_PAPER)
		draw_rect(tr, bg, true)
		draw_rect(tr, UiTheme.PAGE_INK if cur else UiTheme.ADVENTURE_BRASS, false, 2.0 if cur else 1.4)
		var tot := ProfileData.ban_total_quota_for(_repo, ids[ti])
		var use := 0
		var br := ProfileData.banned_by_rarity_for(_repo, ids[ti])
		for rr in [0, 1, 2]:
			use += int(br.get(rr, 0))
		draw_string(_font_bold, tr.position + Vector2(0, 24),
				"%s  %d / %d" % [ids[ti], use, tot],
				HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, UiTheme.FS_LABEL,
				UiTheme.PAGE_INK if cur else Color("9aa0ad"))
	var quota := ProfileData.ban_total_quota_for(_repo, _cls)
	var summary := ProfileData.ban_summary_for(_repo, _cls)
	draw_string(_font_bold, Vector2(0, 172), summary,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY,
			UiTheme.PAGE_INK if quota > 0 else Color("8a8f9c"))
	if quota == 0:
		draw_string(_font, Vector2(0, 190),
				GameI18n.ui("shared", "BAN_NO_QUOTA_EXPLANATION", "没有任何这个职业能用的禁卡名额 —— 剧情里解锁卡牌后才有（故事界面看完剧情才会有）"),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION, Color("9aa0ad"))
	# 返回
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	UiTheme.draw_action(self, back, false, false, hov_back)
	draw_string(_font_bold, back.position + Vector2(0, 22), GameI18n.ui("shared", "BAN_BACK_TO_CLASS_PICK_ARROW", "← 返回角色选择"),
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	if _cards.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 40), GameI18n.ui("shared", "BAN_REWARD_POOL_EMPTY", "奖励池是空的。"),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)
		return
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _cards.size():
			break
		_draw_row(idx, _cards[idx])
	if _cards.size() > _max_rows():
		# R851：右侧细滚动条 + 上下双箭头。先让玩家知道下面还有，才谈得上往下看。
		var track := _list_track()
		_draw_bar(track, float(_max_rows()) / float(_cards.size()),
				float(_scroll) / float(maxi(1, _max_scroll())))
		ScrollHint.draw(self, track.get_center().x, track.position.y - 4.0,
				track.end.y + 4.0, _scroll > 0, _scroll < _max_scroll(),
				ScrollHint.breath())
		# R630：底注原来画在 size.y - 12，纸面九宫格内框只到 size.y - 16、边框还有 ~12 厚
		# → 整行被框线横切（与故事页 / 记录页同款）。收到 -36，落在内框内侧。
		# ⚠️ 这个数要和 story_scene.gd 的底注保持一致，改一处就要对齐另一处。
		draw_string(_font, Vector2(0, size.y - 36),
				GameI18n.ui("shared", "BAN_LIST_RANGE", "第 %d–%d 张 / 共 %d 张")
				% [_scroll + 1, mini(_scroll + _max_rows(), _cards.size()), _cards.size()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				UiTheme.PAGE_MUTED)
	if _toast != "":
		var tw := minf(size.x - 80.0, 760.0)
		var tr := Rect2((size.x - tw) / 2.0, size.y - 60.0, tw, 32.0)
		draw_rect(tr, Color(0.08, 0.09, 0.12, 0.92), true)
		draw_rect(tr, Color("c8951c"), false, 1.6)
		draw_string(_font_bold, tr.position + Vector2(0, 22), _toast,
				HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, UiTheme.FS_LABEL, Color("f2d99a"))


func _draw_row(idx: int, c: CardData) -> void:
	var r := _row_rect(idx)
	var banned: bool = ProfileData.is_banned_for(c.id, _cls)
	var hov := idx == _hover
	var bg := UiTheme.PAGE_PAPER
	if banned:
		bg = UiTheme.ADVENTURE_INPUT
	elif hov:
		bg = UiTheme.PAGE_PAPER
	draw_rect(r, bg, true)
	draw_rect(r, UiTheme.ADVENTURE_BRASS, false, 1.4)
	# 稀有度色条
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			CardData.RARITY_COLORS[clampi(c.rarity, 0, 6)], true)
	draw_string(_font, r.position + Vector2(18, 24),
			CardData.RARITY_NAMES[clampi(c.rarity, 0, 6)],
			HORIZONTAL_ALIGNMENT_LEFT, 60, UiTheme.FS_CAPTION,
			CardData.RARITY_COLORS[clampi(c.rarity, 0, 6)].lightened(0.45))
	draw_string(_font_bold, r.position + Vector2(84, 24), c.card_name,
			HORIZONTAL_ALIGNMENT_LEFT, 420, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	draw_string(_font, r.position + Vector2(520, 24), c.kind,
			HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_CAPTION, Color("9aa0ad"))
	draw_string(_font, r.position + Vector2(640, 24), GameI18n.ui("shared", "BAN_CARD_COST", "费用 %d") % c.cost,
			HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_CAPTION, Color("8fb4d8"))
	var tag := GameI18n.ui("shared", "BAN_TAG_AVAILABLE", "禁")
	var tcol := Color("b9ae8a")
	if banned:
		tag = GameI18n.ui("shared", "BAN_TAG_BANNED", "已禁")
		tcol = Color("ff8fa8")
	else:
		var quota := ProfileData.ban_quota_for(_repo, _cls)
		var used := ProfileData.banned_by_rarity_for(_repo, _cls)
		if int(used.get(c.rarity, 0)) >= int(quota.get(c.rarity, 0)):
			tag = GameI18n.ui("shared", "BAN_TAG_NO_QUOTA", "无名额")
			tcol = Color("6f7684")
	draw_string(_font_bold, r.position + Vector2(r.size.x - 120, 24), tag,
			HORIZONTAL_ALIGNMENT_RIGHT, 100, UiTheme.FS_BODY, tcol)
