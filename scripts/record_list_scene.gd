extends Control
## 对战记录（R215）—— 每局一行：开始时间 / 角色 / 结果 / 难度 / 用时。
## R241：**点一行可以看详情** —— 种子 / 最终生命与最大生命 / 金币 / 层数 / 胜场 /
## 最终道具 / 最终卡组（含附魔）。数据来自 `RunRecord.finish()` 存下的快照；
## 老记录没有快照 → 详情里只有上面那几项，并注明「旧记录没有详情」。
##
## 取代原「录像回放」页（R46 的完整回放机制已删）：只留**最终结果**，
## 通关 / 失败 / 中途放弃 / **中断**（关掉游戏没打完）都会有一行，
## 写入与中断判定见 `RunRecord`。文件：`user://run_records.json`。
##
## R715（用户报「安卓版历史记录中卡组显示不全，不能拖动翻页」）：
##   ① 详情里的卡组列原来只认 `MOUSE_BUTTON_WHEEL_*`，而且那段判断排在「左键关闭」
##      之后 —— 那里对任何 `pressed` 的 MouseButton 都 `return`，滚轮一辈子走不到；
##   ② 列表页同理只有滚轮，且「按下即开详情」让触摸拖动根本起不来。
##   现在两条轴都走 `UiDrag`（R405 唯一口，滚轮 / 触屏 / 鼠标按住拖同一套），
##   列表改成「抬起且没拖才算点击」，并在两端补了三角按钮给拖不动的设备。

const UiTheme = preload("res://scripts/ui_theme.gd")
const UiDrag = preload("res://scripts/ui_drag.gd")   # R715：滚轮 / 触屏拖动 的唯一口（R405）

const ROW_H := 56.0
const ROW_W := 980.0
const LIST_Y := 132.0
## R673：列表底部留白。原来只留 24 —— 1280x720 下算出 10 行，最后一行占到 y=684，
## 正压在页脚纸边和「第 N-M 条」那行上（用户口径「字压住框」）。留 48 后是 9 行，
## 最后一行收到 628，「第 N-M 条」（基线 684）上面还空 44。
const LIST_BOTTOM_PAD := 48.0
## R715：卡组列行高。绘制、拖动换算、可见行数上限**共用这一个常量**
## （原来 `row_h = 21.0` 写在 `_draw_detail()` 里，输入侧拿不到）。
const DECK_ROW_H := 21.0
## R715：道具列行高（原来 22.0 写死在绘制循环里）。
const RELIC_ROW_H := 22.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _rows: Array = []            # 新在前：[{record}]——直接就是记录字典
var _hover := -1
var _scroll := 0                  # 首行下标（滚轮）
var _clear_armed := false         # 「清空」二次确认
var _sel := -1                    # R241：已打开详情的记录下标（-1 = 列表）
var _deck_scroll := 0             # R241：详情里卡组列的滚动偏移
var _deck_drag_acc := 0.0         # R715：卡组列拖动累积像素（满一行才翻一行）
var _list_drag_acc := 0.0         # R715：列表拖动累积像素
var _press := {}                  # R715：列表按下记账 {pos, moved} —— 抬起且没拖才算点击
var _cache_deck: Array = []       # R715：详情打开时算一次（原来每帧解析 cards.json）
var _cache_relics: Array = []     # R715：同上（relics.json）
var _relic_scroll := 0            # R715：道具列的滚动偏移（原来塞不下就写「…还有 N 件」）
var _relic_drag_acc := 0.0        # R715：道具列拖动累积像素
var _drag_col := ""               # R715：「relic / deck」，按下那一刻锁定，别拖到一半串到另一列
var _last_mp := Vector2.INF


func _ready() -> void:
	UiTheme.attach_stage(self)   # R519：宽屏下内容居中，背景溢出铺满两侧
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	_refresh()
	# 演示参数（R241）：--detail [N] 打开第 N 行（默认 0）的详情 —— 出图核验用。
	var _da := OS.get_cmdline_user_args()
	var _di := _da.find("--detail")
	if _di >= 0 and not _rows.is_empty():
		_open_detail(int(_da[_di + 1]) if _di + 1 < _da.size() else 0)
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_records.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": GameI18n.ui("shell", "RECORD_MENU_CONTINUE", "继续"),
		"sub": GameI18n.ui("shell", "RECORD_MENU_SUBTITLE", "对战记录"),
	})


func _menu_items() -> Array:
	return [
		{"text": func(): return GameI18n.ui("shell", "RECORD_SOUND_ON", "音效：开") if sfx.enabled else GameI18n.ui("shell", "RECORD_SOUND_OFF", "音效：关"),
			"fn": _toggle_sound, "keep_open": true},
		{"text": GameI18n.ui("shell", "RECORD_MENU_BACK_TITLE", "返回标题"), "fn": _back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _unhandled_input(event: InputEvent) -> void:
	# R241：详情打开时 Esc 先关详情（别直接弹 Esc 菜单）。
	if _sel >= 0 and event is InputEventKey and event.pressed \
			and event.keycode == KEY_ESCAPE:
		_close_detail()
		get_viewport().set_input_as_handled()
		return
	if _menu != null and _menu.handle_esc(event):
		return


func _refresh() -> void:
	var all := RunRecord.list_records()
	_rows = []
	for i in range(all.size() - 1, -1, -1):     # 新在前
		_rows.append(all[i])
	_scroll = 0
	_clear_armed = false
	_press = {}
	_list_drag_acc = 0.0
	_cache_deck = []
	_cache_relics = []
	queue_redraw()


func _process(_delta: float) -> void:
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		queue_redraw()


# ------------------------------------------------------------ 布局

func _row_rect(i: int) -> Rect2:
	return Rect2((size.x - ROW_W) / 2.0, LIST_Y + (i - _scroll) * ROW_H,
			ROW_W, ROW_H - 8.0)


func _back_rect() -> Rect2:
	return Rect2(14, 14, 110, 34)


func _clear_rect() -> Rect2:
	## 左下角（右上角被「道具 / 牌库」两个查看器占着，别压上去）。
	return Rect2(14.0, size.y - 54.0, 124.0, 34.0)


func _max_rows() -> int:
	return maxi(1, int((size.y - LIST_Y - LIST_BOTTOM_PAD) / ROW_H))


func _row_at(pos: Vector2) -> int:
	var n := _max_rows()
	for i in n:
		var idx := _scroll + i
		if idx >= _rows.size():
			break
		if _row_rect(idx).has_point(pos):
			return idx
	return -1


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	# R241：详情面板打开时，输入全部交给面板自己处理（列表不响应）。
	if _sel >= 0:
		_detail_input(event)
		return
	_list_input(event)


func _detail_input(event: InputEvent) -> void:
	## R715：卡组列的翻页。旧版把滚轮判断写在「左键关闭」那段**之后**，而那段对任何
	## `pressed` 的 MouseButton 都直接 `return` —— 滚轮根本走不到；安卓又没有滚轮。
	## 现在统一走 `UiDrag`（R405 唯一口）：滚轮 / 触屏拖 / 鼠标按住拖，同一份位移。
	var d := UiDrag.scroll_delta(event, DECK_ROW_H * 3.0)
	if d != 0.0:
		# R715：两列各有各的轴 —— 手指在哪一列就滚哪一列；拖动中沿用按下时锁定的那一列
		# （否则手指横向漂一点就换轴，另一列的累积器没攒满，手感像「拖着拖着不动了」）。
		var col := _drag_col
		if col == "":
			col = "relic" if _event_x(event) < _detail_split_x() else "deck"
		if col == "relic":
			_scroll_relic(d)
		else:
			_scroll_deck(d)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if not mb.pressed:
			_drag_col = ""          # 松手 → 解除列锁定
			return
		var ra := _relic_arrow_rects()
		if ra[0].has_point(mb.position) and _relic_scroll > 0:
			sfx.play("click")
			_scroll_relic(-RELIC_ROW_H * float(maxi(1, _relic_max_rows() - 1)))
			return
		if ra[1].has_point(mb.position) and _relic_scroll < _relic_max_scroll():
			sfx.play("click")
			_scroll_relic(RELIC_ROW_H * float(maxi(1, _relic_max_rows() - 1)))
			return
		_drag_col = "relic" if mb.position.x < _detail_split_x() else "deck"
		var ar := _deck_arrow_rects()
		if ar[0].has_point(mb.position) and _deck_scroll > 0:
			sfx.play("click")
			_scroll_deck(-DECK_ROW_H * float(maxi(1, _deck_max_rows() - 1)))
			return
		if ar[1].has_point(mb.position) and _deck_scroll < _deck_max_scroll():
			sfx.play("click")
			_scroll_deck(DECK_ROW_H * float(maxi(1, _deck_max_rows() - 1)))
			return
		var outside := not _detail_rect().has_point(mb.position)
		if _detail_close_rect().has_point(mb.position) or outside:
			sfx.play("click")
			_close_detail()


func _list_input(event: InputEvent) -> void:
	## R715：列表翻页同样走 `UiDrag` —— 安卓没有滚轮，旧版记录一多只看得到前 9 条。
	## 另外原来「按下就开详情」，手指一沾就走，列表压根拖不起来 → 改成**抬起**才算点击。
	var d := UiDrag.scroll_delta(event, ROW_H * 3.0)
	if d != 0.0:
		_list_drag_acc += d
		var step := int(_list_drag_acc / ROW_H)
		if step != 0:
			_list_drag_acc -= step * ROW_H
			_scroll = clampi(_scroll + step, 0, _list_max_scroll())
			queue_redraw()
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _press.is_empty() and UiDrag.drag_moved(_press["pos"] as Vector2, mm.position):
			_press["moved"] = true
			return      # 拖动中不做 hover 命中：行高亮跟着手指乱跳很晃眼
		_hover = _row_at(mm.position)
		queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb2 := event as InputEventMouseButton
		if mb2.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb2.pressed:
			var ar := _list_arrow_rects()
			if _rows.size() > _max_rows():
				var page := maxi(1, _max_rows() - 1)
				if ar[0].has_point(mb2.position):
					if _scroll > 0:
						sfx.play("click")
						_scroll = maxi(0, _scroll - page)
						queue_redraw()
					return
				if ar[1].has_point(mb2.position):
					if _scroll < _list_max_scroll():
						sfx.play("click")
						_scroll = mini(_list_max_scroll(), _scroll + page)
						queue_redraw()
					return
			_press = {"pos": mb2.position, "moved": false}
			return
		var moved := _press.is_empty() or bool(_press.get("moved", true))
		_press = {}
		if not moved:
			_tap_list(mb2.position)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _tap_list(pos: Vector2) -> void:
	## R715：一次「按下 → 抬起且没拖动」落在哪。原来这段写在 `pressed` 分支里 ——
	## 触屏一按就开详情、一滑就跳过好几行。
	## 「清空」的二次确认也在这里修：原来进函数第一句就是 `_clear_armed = false`，
	## 第二次点同一颗按钮又被自己清掉，所以**永远确认不掉**。
	if _clear_rect().has_point(pos) and not _rows.is_empty():
		sfx.play("click")
		if not _clear_armed:
			_clear_armed = true
			queue_redraw()
			return
		_clear_armed = false
		RunRecord.clear_all()
		_refresh()
		sfx.play("attack")
		return
	_clear_armed = false          # 点在别处 → 取消「清空」待确认
	if _back_rect().has_point(pos):
		sfx.play("click")
		_back_to_title()
		return
	var hit_row := _row_at(pos)
	if hit_row >= 0:
		sfx.play("click")
		_open_detail(hit_row)     # R241：点一行看详情
		return
	queue_redraw()


func _list_max_scroll() -> int:
	return maxi(0, _rows.size() - _max_rows())


func _body_geo() -> Dictionary:
	## R715：详情面板两列正文的几何**唯一口** —— 卡组列与道具列的绘制起点、底部界限、
	## 可见行数都从这里取。两处各写一遍公式的话，改一次留白就会「翻到底还漏半行」。
	var r := _detail_rect()
	return {
		"bot": r.end.y - 42.0,
		"y0": r.position.y + 54.0 + 88.0 + 26.0 + 24.0,   # = body_y + 24
	}


func _detail_split_x() -> float:
	## 两列的分界（那条竖线）：x 比它小 = 左列道具，大 = 右列卡组。
	return _detail_rect().position.x + 456.0 - 14.0


func _event_x(event: InputEvent) -> float:
	## 取事件横坐标（滚轮 / 拖动都要按位置决定滚哪一列）。
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position.x
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position.x
	return _detail_split_x() + 1.0     # 没有位置信息 → 按右列（卡组）算


func _deck_max_rows() -> int:
	var geo := _body_geo()
	return maxi(1, int((float(geo["bot"]) - 18.0 - float(geo["y0"])) / DECK_ROW_H))


func _deck_max_scroll() -> int:
	return maxi(0, _cache_deck.size() - _deck_max_rows())


func _relic_max_rows() -> int:
	var geo := _body_geo()
	return maxi(1, int((float(geo["bot"]) - 18.0 - float(geo["y0"])) / RELIC_ROW_H))


func _relic_max_scroll() -> int:
	return maxi(0, _cache_relics.size() - _relic_max_rows())


func _scroll_relic(delta: float) -> void:
	## 与 `_scroll_deck()` 同一套：像素增量先攒，满一行才翻。
	_relic_drag_acc += delta
	var step := int(_relic_drag_acc / RELIC_ROW_H)
	if step == 0:
		return
	_relic_drag_acc -= step * RELIC_ROW_H
	_relic_scroll = clampi(_relic_scroll + step, 0, _relic_max_scroll())
	queue_redraw()


func _scroll_deck(delta: float) -> void:
	## 像素增量 → 整行。不足一行先攒在 `_deck_drag_acc` 里（手指连续拖不会「拖半天不动」），
	## 只在换算时扣掉整行的量 —— 被 clamp 在边界上也不会攒出「突然跳一下」。
	_deck_drag_acc += delta
	var step := int(_deck_drag_acc / DECK_ROW_H)
	if step == 0:
		return
	_deck_drag_acc -= step * DECK_ROW_H
	_deck_scroll = clampi(_deck_scroll + step, 0, _deck_max_scroll())
	queue_redraw()


func _deck_arrow_rects() -> Array:
	## 卡组列底部两枚小三角的命中区：[上, 下]。
	var r := _detail_rect()
	var x := r.end.x - 72.0 - 50.0
	var y := float(_body_geo()["bot"]) - 15.0
	return [Rect2(x, y, 20.0, 20.0), Rect2(x + 24.0, y, 20.0, 20.0)]


func _relic_arrow_rects() -> Array:
	## 道具列底部两枚小三角的命中区：[上, 下]。
	var x := _detail_split_x() - 50.0
	var y := float(_body_geo()["bot"]) - 15.0
	return [Rect2(x, y, 20.0, 20.0), Rect2(x + 24.0, y, 20.0, 20.0)]


func _list_arrow_rects() -> Array:
	## 列表底部范围行两侧的两枚小三角：[上, 下]。
	var cx := size.x / 2.0
	var y := size.y - 36.0 - 15.0
	return [Rect2(cx - 150.0, y, 20.0, 20.0), Rect2(cx + 130.0, y, 20.0, 20.0)]


func _draw_arrow(r: Rect2, up: bool, enabled: bool) -> void:
	## R405 口径：拖不动的设备也要能翻 —— 箭头是兜底；不写「拖动翻页」这类教学文字（R353）。
	var c := r.get_center()
	var col := UiTheme.PAGE_INK if enabled else Color(UiTheme.PAGE_MUTED, 0.4)
	var pts := PackedVector2Array()
	if up:
		pts = PackedVector2Array([c + Vector2(-6, 4), c + Vector2(6, 4), c + Vector2(0, -4)])
	else:
		pts = PackedVector2Array([c + Vector2(-6, -4), c + Vector2(6, -4), c + Vector2(0, 4)])
	draw_colored_polygon(pts, col)


func _back_to_title() -> void:
	SceneFx.goto("res://scenes/title.tscn")


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	UiTheme.draw_page(self, UiTheme.bleed_rect(self))   # R519：铺满窗口
	draw_string(_font_bold, Vector2(0, 62), GameI18n.ui("shell", "RECORD_TITLE", "对 战 记 录"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	var wins := 0
	for r: Dictionary in _rows:
		if str(r.get("result", "")) == "win":
			wins += 1
	draw_string(_font, Vector2(0, 94),
			GameI18n.ui("shell", "RECORD_SUMMARY", "共 %d 局 · 通关 %d 局（中断 / 中途放弃也会记在这里）") % [_rows.size(), wins],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	# 左上返回 / 右上清空
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	UiTheme.draw_action(self, back, false, false, hov_back)
	draw_string(_font_bold, back.position + Vector2(0, 22), GameI18n.ui("shell", "RECORD_BACK_TITLE", "← 返回标题"),
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	var cl := _clear_rect()
	var hov_cl := cl.has_point(get_local_mouse_position()) and not _rows.is_empty()
	draw_rect(cl, Color("8a3030") if _clear_armed else (Color("4a2c2c") if hov_cl
			else UiTheme.PAGE_PAPER), true)
	draw_rect(cl, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, cl.position + Vector2(0, 22),
			GameI18n.ui("shell", "RECORD_CLEAR_CONFIRM", "确认清空？") if _clear_armed else GameI18n.ui("shell", "RECORD_CLEAR", "清空记录"),
			HORIZONTAL_ALIGNMENT_CENTER, cl.size.x, UiTheme.FS_LABEL,
			Color("ffd8d8") if _clear_armed else UiTheme.PAGE_MUTED)
	if _rows.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 40),
				GameI18n.ui("shell", "RECORD_EMPTY", "还没有记录 —— 从标题「开始对战」打一局，结束后这里会有一行结果。"),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)
		return
	# R673：详情打开时**不画列表** —— 遮罩只有 0.55 黑压不住字，最后一行会从面板下沿
	# 漏出来，落在页脚纸边上（就是「字压住框」）。
	if _sel < 0:
		for i in _max_rows():
			var idx := _scroll + i
			if idx >= _rows.size():
				break
			_draw_row(idx, _rows[idx])
	if _sel >= 0 and _sel < _rows.size():
		_draw_detail()   # R241：详情盖在列表之上
	if _sel < 0 and _rows.size() > _max_rows():
		# R630：同故事页 / 禁卡页 —— -12 会被纸面九宫格的下边框横切，收到 -36。
		draw_string(_font, Vector2(0, size.y - 36),
				GameI18n.ui("shell", "RECORD_RANGE", "第 %d–%d 条 / 共 %d 条")
				% [_scroll + 1, mini(_scroll + _max_rows(), _rows.size()), _rows.size()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				UiTheme.PAGE_MUTED)
		# R715：记录多了在安卓上也得能翻 —— 范围行两侧各一枚三角（拖动是主路径，这是兜底）。
		var ar2 := _list_arrow_rects()
		_draw_arrow(ar2[0], true, _scroll > 0)
		_draw_arrow(ar2[1], false, _scroll < _list_max_scroll())


# ------------------------------------------------------------ 详情（R241）

func _detail_rect() -> Rect2:
	return Rect2((size.x - 980.0) / 2.0, 96.0, 980.0, size.y - 148.0)


func _detail_close_rect() -> Rect2:
	## R673：右上角是 34px 角花，原来 +10 贴在花上；退到 +40 / -86 的花内空白处。
	var r := _detail_rect()
	return Rect2(r.end.x - 86.0, r.position.y + 40.0, 36.0, 30.0)


func _open_detail(idx: int) -> void:
	if idx < 0 or idx >= _rows.size():
		return
	_sel = idx
	_deck_scroll = 0
	_deck_drag_acc = 0.0
	_relic_scroll = 0
	_relic_drag_acc = 0.0
	_drag_col = ""
	_list_drag_acc = 0.0
	_press = {}
	# R715：卡表 / 道具表在这里算一次 —— 原来 `_draw_detail()` 每帧都重新解析
	# cards.json（319 张卡）与 relics.json，安卓上一拖就卡、越拖越卡。
	_cache_deck = _deck_entries(_rows[idx])
	_cache_relics = _relic_entries(_rows[idx])
	_clear_armed = false
	_hover = -1
	queue_redraw()


func _close_detail() -> void:
	_sel = -1
	queue_redraw()


func _relic_entries(rec: Dictionary) -> Array:
	## 最终道具：[{name, col}]。拿不到定义的 id 跳过（同 RelicViewer 的口径）。
	var raw: Variant = rec.get("relics", [])
	if not (raw is Array):
		return []
	var repo := RelicRepo.load_json()
	# R367：已耗尽的道具**留在记录里**（钢盆碎了 / 绳子用掉）—— 名字加后缀并画灰。
	# 老记录没有 spent 字段 → 全视为生效。判定走 `RunRecord.is_spent_in()`（float 坑）。
	var out: Array = []
	for v: Variant in raw:
		var rel := repo.get_relic(int(v))
		if rel == null:
			continue
		var spent := RunRecord.is_spent_in(rec, int(v))
		# R343：名字另配一色（传奇金橙）—— `col` 仍是左侧圆点的徽章色。
		out.append({"name": (GameI18n.ui("shell", "RECORD_RELIC_SPENT", "%s（已耗尽）") % rel.relic_name) if spent else rel.relic_name,
				"col": Color("6a7078") if spent else rel.badge_color(),
				"ncol": Color("8d857a") if spent else rel.name_color(UiTheme.PAGE_INK)})
	return out


func _deck_entries(rec: Dictionary) -> Array:
	## 最终卡组：按「卡 id + 附魔 id」合并同名同附魔 → [{name, n, ench}]。
	## 顺序沿用卡组顺序（第一张出现的先后），便于和牌库对照。
	var raw: Variant = rec.get("deck", [])
	if not (raw is Array):
		return []
	var repo := CardRepo.load_json()
	var out: Array = []
	var pos := {}
	for v: Variant in raw:
		if not (v is Dictionary):
			continue
		var cid := int((v as Dictionary).get("id", 0))
		var eid := str((v as Dictionary).get("e", ""))
		var key := "%d|%s" % [cid, eid]
		if pos.has(key):
			var hit: Dictionary = out[int(pos[key])]
			hit["n"] = int(hit["n"]) + 1
			continue
		var card := repo.get_card(cid)
		if card == null:
			continue          # 老记录里的卡 id 在当前卡表里没了 → 跳过（不显示空白行）
		pos[key] = out.size()
		out.append({"name": card.card_name, "n": 1, "ench": eid})
	return out


func _draw_detail() -> void:
	## 详情面板：上面概览（含种子 / 生命 / 最大生命），下面左道具右卡组。
	## R673：面板九宫格四周各有 34px 角花 —— 内容原来从 +48 / +32 起算，结果标题左端被
	## 左上卷边切掉、字顶压在上边框花纹上，关闭钮和分隔线也都骑在角花上（用户口径
	## 「字压住框」）。这里统一把内容退到角花之内：左右 72、上 54、下 42。
	var r := _detail_rect()
	# 遮罩 + 面板
	draw_rect(UiTheme.bleed_rect(self), Color(0, 0, 0, 0.55), true)
	UiTheme.draw_panel_bg(self, r)
	var rec: Dictionary = _rows[_sel]
	var res := str(rec.get("result", ""))
	var geo := _body_geo()          # R715：与输入侧算上限时用同一个数
	var x0 := r.position.x + 72.0
	var x1 := r.end.x - 72.0
	var top := r.position.y + 54.0
	var bot := float(geo["bot"])
	# 标题：时间 + 结果
	draw_string(_font_bold, Vector2(x0, top),
			"%s · %s" % [RunRecord.fmt_time(str(rec.get("time", "?"))),
			RunRecord.result_label(res, int(rec.get("layer", -1)))],
			HORIZONTAL_ALIGNMENT_LEFT, 520, UiTheme.FS_HEADING,
			UiTheme.PAGE_INK)
	# 关闭
	var cr := _detail_close_rect()
	UiTheme.draw_close(self, cr, cr.has_point(get_local_mouse_position()))
	# 概览两行
	var seed_v := int(rec.get("seed", 0))
	draw_string(_font_bold, Vector2(x0, top + 26.0),
			GameI18n.ui("shell", "RECORD_SEED", "种子：%s") % ("—" if seed_v == 0 else RunState.seed_text_of(seed_v)),
			HORIZONTAL_ALIGNMENT_LEFT, 320, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	draw_string(_font, Vector2(x0 + 250.0, top + 26.0),
			GameI18n.ui("shell", "RECORD_CLASS_DIFFICULTY_TIME", "角色：%s · 难度 %d · 用时 %s")
			% [PlayerClass.legacy_id(str(rec.get("class", "?"))),
			int(rec.get("difficulty", 2)), RunRecord.fmt_secs(int(rec.get("secs", 0)))],
			HORIZONTAL_ALIGNMENT_LEFT, 640, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	var has_snap := rec.has("hp") or rec.has("deck") or rec.has("relics")
	if has_snap:
		var hp := int(rec.get("hp", 0))
		var mhp := int(rec.get("max_hp", 0))
		var hp_col := Color("e07a6a") if (res == "lose" or hp <= 0) else UiTheme.PAGE_GREEN
		draw_string(_font_bold, Vector2(x0, top + 50.0),
				GameI18n.ui("shell", "RECORD_HP", "生命 %d / %d") % [hp, mhp],
				HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_BODY, hp_col)
		draw_string(_font, Vector2(x0 + 250.0, top + 50.0),
				GameI18n.ui("shell", "RECORD_SNAPSHOT_STATS", "金币 %d · 层数 %d · 战斗胜场 %d（精英 %d）")
				% [int(rec.get("gold", 0)), int(rec.get("layer", 0)),
				int(rec.get("battles", 0)), int(rec.get("elites", 0))],
				HORIZONTAL_ALIGNMENT_LEFT, 640, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	# R367：每层打过的 Boss（老记录没有 `bosses` 字段 → 整行不画）
	var bosses: Variant = rec.get("bosses", [])
	if bosses is Array and not (bosses as Array).is_empty():
		var parts: Array[String] = []
		for b: Variant in bosses:
			if b is Dictionary:
				parts.append(GameI18n.ui("shell", "RECORD_BOSS_ITEM", "第 %d 层 · %s") % [int((b as Dictionary).get("layer", 0)),
						str((b as Dictionary).get("name", "?"))])
		draw_string(_font, Vector2(x0, top + 70.0),
				GameI18n.ui("shell", "RECORD_BOSS_LIST", "Boss：%s") % "　/　".join(parts),
				HORIZONTAL_ALIGNMENT_LEFT, 900, UiTheme.FS_LABEL, Color("e8b04a"))
	# 分隔线
	var sep_y := top + 88.0
	draw_line(Vector2(x0, sep_y), Vector2(x1, sep_y), Color("3d424e"), 1.0)
	var body_y := sep_y + 26.0
	if not has_snap:
		draw_string(_font, Vector2(r.position.x, body_y + 30.0),
				GameI18n.ui("shell", "RECORD_OLD_NO_SNAPSHOT", "这条记录是旧版本留下的，没有存最终道具 / 卡组（只记了结果与用时）。"),
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)
		return
	# ---- 左列：最终道具（滚轮 / 按住拖 / 底部三角，R715） ----
	var mid := r.position.x + 456.0
	draw_line(Vector2(mid - 14.0, body_y), Vector2(mid - 14.0, bot),
			Color("3d424e"), 1.0)
	var relics := _cache_relics        # R715：`_open_detail()` 算好的那份
	draw_string(_font_bold, Vector2(x0, body_y),
			GameI18n.ui("shell", "RECORD_FINAL_RELICS", "最终道具（%d）") % relics.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	var ly := float(geo["y0"])
	var max_rel := _relic_max_rows()
	var max_rel_scroll := _relic_max_scroll()
	if _relic_scroll > max_rel_scroll:
		_relic_scroll = max_rel_scroll     # 换记录 / 窗口变高 → 收回能看全的位置
	if relics.is_empty():
		draw_string(_font, Vector2(x0, ly + 14.0), GameI18n.ui("shell", "RECORD_NO_RELICS", "（这一局没有获得道具）"),
				HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	else:
		# R715：原来塞不下就写「…还有 N 件」—— 那 N 件永远看不到。改成和卡组列同一套滚动。
		for i in mini(max_rel, relics.size() - _relic_scroll):
			var e: Dictionary = relics[_relic_scroll + i]
			draw_circle(Vector2(x0 + 5.0, ly + 8.0), 4.0, e["col"])
			draw_string(_font, Vector2(x0 + 18.0, ly + 14.0), str(e["name"]),
					HORIZONTAL_ALIGNMENT_LEFT, 362, UiTheme.FS_LABEL,
					UiTheme.PAGE_INK)
			ly += RELIC_ROW_H
		if max_rel_scroll > 0:
			draw_string(_font, Vector2(x0, bot),
					GameI18n.ui("shell", "RECORD_RELIC_RANGE", "道具 第 %d–%d 件 / 共 %d 件")
					% [_relic_scroll + 1, mini(_relic_scroll + max_rel, relics.size()), relics.size()],
					HORIZONTAL_ALIGNMENT_LEFT, 330, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
			var ar3 := _relic_arrow_rects()
			_draw_arrow(ar3[0], true, _relic_scroll > 0)
			_draw_arrow(ar3[1], false, _relic_scroll < max_rel_scroll)
	# ---- 右列：最终卡组（滚轮 / 按住拖 / 底部三角，R715） ----
	var deck := _cache_deck            # R715：同上
	var total_cards := 0
	for e2: Dictionary in deck:
		total_cards += int(e2["n"])
	draw_string(_font_bold, Vector2(mid, body_y),
			GameI18n.ui("shell", "RECORD_FINAL_DECK", "最终卡组（%d 张 / %d 种）") % [total_cards, deck.size()],
			HORIZONTAL_ALIGNMENT_LEFT, 460, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	var dy := float(geo["y0"])        # = body_y + 24.0，与输入侧同源
	# R673：底部界线从 `r.end.y - 16` 收到 `bot`（下角花 34 + 8）—— 原来多出来的十几行
	# 会把卡名画到下边框的花纹上；同时给「卡组 第 N–M 行」留一行位置。
	var max_deck := _deck_max_rows()   # R715：与输入侧的 clamp 上限同一个口
	var max_scroll := maxi(0, deck.size() - max_deck)
	if _deck_scroll > max_scroll:
		_deck_scroll = max_scroll
	for i2 in mini(max_deck, deck.size() - _deck_scroll):
		var d: Dictionary = deck[_deck_scroll + i2]
		var line := "%s ×%d" % [str(d["name"]), int(d["n"])] if int(d["n"]) > 1 \
				else str(d["name"])
		draw_string(_font, Vector2(mid, dy + 14.0), line,
				HORIZONTAL_ALIGNMENT_LEFT, 320, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
		var eid := str(d["ench"])
		if eid != "":
			draw_string(_font, Vector2(mid + 300.0, dy + 14.0),
					GameI18n.ui("shell", "RECORD_ENCHANT", "附魔：%s") % CardData.enchant_name(eid),
					HORIZONTAL_ALIGNMENT_LEFT, 170, UiTheme.FS_CAPTION,
					CardData.enchant_color(eid))
		dy += DECK_ROW_H
	if max_scroll > 0:
		# R715：宽度从 460 收到 380 —— 右边要留出两枚翻页三角的位置，别让字骑上去。
		draw_string(_font, Vector2(mid, bot),
				GameI18n.ui("shell", "RECORD_DECK_RANGE", "卡组 第 %d–%d 行 / 共 %d 行")
				% [_deck_scroll + 1, mini(_deck_scroll + max_deck, deck.size()), deck.size()],
				HORIZONTAL_ALIGNMENT_LEFT, 380, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
		var ar := _deck_arrow_rects()
		_draw_arrow(ar[0], true, _deck_scroll > 0)
		_draw_arrow(ar[1], false, _deck_scroll < max_scroll)


func _draw_row(idx: int, rec: Dictionary) -> void:
	var r := _row_rect(idx)
	var hov := idx == _hover
	draw_rect(r, UiTheme.ADVENTURE_INPUT if hov else UiTheme.PAGE_PAPER, true)
	draw_rect(r, UiTheme.ADVENTURE_BRASS if hov else UiTheme.ADVENTURE_BRASS, false, 1.6)
	var res := str(rec.get("result", ""))
	# 结果色条（左沿）：一眼分辨通关 / 失败 / 中断
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			RunRecord.result_color(res), true)
	draw_string(_font_bold, r.position + Vector2(18, 22),
			RunRecord.fmt_time(str(rec.get("time", "?"))),
			HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	draw_string(_font_bold, r.position + Vector2(246, 22),
			GameI18n.ui("shell", "RECORD_ROW_CLASS", "角色：%s") % PlayerClass.legacy_id(str(rec.get("class", "?"))),
			HORIZONTAL_ALIGNMENT_LEFT, 190, UiTheme.FS_BODY, UiTheme.PAGE_GREEN)
	draw_string(_font_bold, r.position + Vector2(446, 22),
			RunRecord.result_label(res, int(rec.get("layer", -1))),
			HORIZONTAL_ALIGNMENT_LEFT, 140, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	draw_string(_font, r.position + Vector2(596, 22),
			GameI18n.ui("shell", "RECORD_ROW_DIFFICULTY_TIME", "难度 %d · 用时 %s") % [int(rec.get("difficulty", 2)),
			RunRecord.fmt_secs(int(rec.get("secs", 0)))],
			HORIZONTAL_ALIGNMENT_LEFT, 280, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	# R630：两行一起收（24/43 → 22/38）。行高 48（ROW_H 56 - 8）要塞 FS_BODY 16 + FS_CAPTION 12
	# 两行，第二行基线下探到 43 时字底已经贴住下框线（用户口径「可能压框」）。
	# 行距保持 16，底部留 7（原来 5），第一行顶部留 10。
	draw_string(_font, r.position + Vector2(18, 38),
			GameI18n.ui("shell", "RECORD_ROW_END_TIME", "结束于 %s") % RunRecord.fmt_time(str(rec.get("end", ""))),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
	# R261：种子码也列在列表行上（不用点进详情就能抄下来复现）
	var row_seed := int(rec.get("seed", 0))
	draw_string(_font, r.position + Vector2(430, 38),
			"种子：%s" % ("—" if row_seed == 0 else RunState.seed_text_of(row_seed)),
			HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_CAPTION, Color("b39a5e"))
