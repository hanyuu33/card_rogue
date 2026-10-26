class_name PickOverlay
extends Control
## 战斗内全屏选卡页（R189）—— 替换乌鸦 / 鲸鱼 / 无尽黑暗 / 取牌（复活术·暗影步·返修）/
## 预判取牌 / 拒绝命运 / 专注 / 英雄代价 这 8 套各自的小面板。
##
## 用户口径：不要框、卡片要能看清 → 整屏半透明罩（隐约看得见战场）、每行 5 张放大卡、
## 垂直滚动；「返回」只是**收起看战场**（pending 与选中都保留，战斗画面顶部有
## 「继续选择」浮条可以回来），「确认」才是唯一结算口。
##
## 调用方（battle_scene）给一份 cfg：
##   { kind, title, note, cards: Array[CardData], counts: Array（同名合并张数，可空）,
##     max_sel: int, confirm_label: String, cancel_label: String（"" = 无放弃按钮） }
## 确认时发 `confirmed(selected)`（**网格下标**数组，业务下标由调用方自己映射）。

signal confirmed(selected: Array)
signal cancelled()
signal collapsed_changed(collapsed: bool)

const UiTheme = preload("res://scripts/ui_theme.gd")

const COLS := 5                 # 每行 5 张（用户口径）
const GAP := 30.0               # 卡间距（用户口径：别排太紧凑）
const TOP_H := 64.0             # 顶栏高
const BOT_H := 76.0             # 底栏高
const DESC_H := 88.0            # 描述条高（R191：点选/悬停的卡在这里看描述）
const SIDE := 96.0              # 网格区左右边距
const GRID_TOP := 24.0          # 网格区与顶栏的额外间距
const DRAG_SLOP := 10.0         # 超过算拖动（滚动），否则算点按
const WHEEL_STEP := 52.0

var _font: Font
var _font_bold: Font
var _cfg: Dictionary = {}
var _cards: Array = []
var _counts: Array = []
var _selected: Array[int] = []
var _scroll := 0.0
var _press := {}                # {pos, scroll, moved} 左键/触屏按下状态
var _hover_idx := -1           # R191：悬停卡下标（无悬停时描述条显示最后选中的）
var _clip: Control              # 裁剪容器（clip_contents：滚出视区的半行不画）
var _grid: PickGrid             # 网格节点（_draw 画全部卡；position.y = -_scroll）


class PickGrid extends Control:
	## 网格绘制节点：内容高度可能超过视区，父容器 clip_contents 负责裁剪。
	var overlay: PickOverlay

	func _draw() -> void:
		if overlay != null:
			overlay.draw_cards(self)


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_clip = Control.new()
	_clip.clip_contents = true    # Godot 画布无裁剪 → 用 clip_contents 容器裁子节点
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_grid = PickGrid.new()
	_grid.overlay = self
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 命中判定全在 PickOverlay 手动做
	_clip.add_child(_grid)
	# R395：尺寸晚到（首帧 anchors / 安卓切前台 / 分辨率变化）也要重排 ——
	# 否则面板还开着、网格却按旧尺寸裁，卡会整片看不见。
	resized.connect(func():
		if visible:
			_layout()
			_grid.queue_redraw()
			queue_redraw())


# ── 对外接口 ─────────────────────────────────────────────────

func open(cfg: Dictionary) -> void:
	_cfg = cfg
	_cards = cfg.get("cards", [])
	_counts = cfg.get("counts", [])
	_selected = []
	_scroll = 0.0
	_hover_idx = -1   # R294：新一轮选卡 → 悬停下标清零（否则描述条停在上局的卡上）
	visible = true
	_layout()
	_grid.queue_redraw()
	queue_redraw()
	collapsed_changed.emit(false)


func close() -> void:
	visible = false
	_cfg = {}
	_cards = []
	_selected = []
	_hover_idx = -1   # R294：关掉就清，别带到下一次 open


func collapse() -> void:
	## 返回 = 收起看战场；pending 与选中都保留，`reopen()` 回来继续选。
	## R301：**纯浏览**没有「待办」可言 —— 收起再点「继续选择」回来毫无意义，
	## 所以浏览模式下「返回」= 直接关窗（走 `cancelled` 让调用方收尾）。
	if is_view():
		cancelled.emit()
		return
	visible = false
	collapsed_changed.emit(true)


func reopen() -> void:
	visible = true
	_layout()
	_grid.queue_redraw()
	queue_redraw()
	collapsed_changed.emit(false)


func is_picking() -> bool:
	## 有 cfg 在管（不管当前是展开还是收起）—— battle_scene 据此画「继续选择」浮条。
	return not _cfg.is_empty()


func is_view() -> bool:
	## R301：**纯浏览**模式（弃牌区翻阅）—— 没有「选中 / 确认结算」，点卡只是看描述。
	## 与选卡模式的差别（全部只在本文件内判）：
	##   · 点卡**不选中**（不画金框、不改「已选」计数），只把描述条切到那张；
	##   · 「确认」= 关闭（不 emit `confirmed`，那会把网格下标丢给业务层）；
	##   · 「返回」/ Esc / 右键 = **直接关窗**，不像选卡那样收起去看战场
	##     （浏览没有待办，收起后再点「继续选择」回来是没有意义的）。
	return bool(_cfg.get("view_only", false))


func kind() -> String:
	return _cfg.get("kind", "")


func selected_count() -> int:
	return _selected.size()


func opts() -> Array:
	## 当前 cfg 的业务下标表（与 cards 平行；确认时 battle_scene 用它做映射）。
	return _cfg.get("opts", [])


func cfg_short() -> String:
	## 场景短名（收起态浮条用）。
	return _cfg.get("short", _cfg.get("title", ""))


func update_cfg(cfg: Dictionary) -> void:
	## 累计型场景确认一张后由 battle_scene 重建 cfg 并刷新（候选与标题剩余数都变了）。
	_cfg = cfg
	refresh()


func refresh() -> void:
	## 累计型场景（鲸鱼 / 命运 / 取牌 / 专注）确认一张后：候选变了，重载 cfg 里的卡表。
	_cards = _cfg.get("cards", [])
	_counts = _cfg.get("counts", [])
	_selected = []
	_hover_idx = -1   # R294：候选表换了，旧下标指向的是另一张卡
	_clamp_scroll()
	_grid.queue_redraw()
	queue_redraw()


# ── 布局 ─────────────────────────────────────────────────────

func _layout() -> void:
	# R395（用户报「选卡页弹出来，有返回按钮和提示，但看不到任何待选卡」）：
	# 旧代码只兜底 `size.x < 10`。**高度**没结算时（首帧 anchors 还没生效 / 从小窗切回）
	# `h - TOP_H - GRID_TOP - BOT_H - DESC_H - 14` 会算成 0 甚至负数 → 网格被裁成 0 高：
	# 顶栏（画在 clip 之外）照常可见，卡却一张都看不见，正是这个现象。
	if size.x < 10.0 or size.y < 10.0:
		# 首帧 anchors 还没结算（或 headless 探针直调 open）→ 按视口尺寸兜底
		size = get_viewport_rect().size
	if size.x < 10.0 or size.y < 10.0:
		size = Vector2(1280, 720)      # 视口也拿不到（极早期）→ 退回设计分辨率
	var w := size.x
	var h := size.y
	_clip.position = Vector2(SIDE, TOP_H + GRID_TOP)
	_clip.size = Vector2(maxf(1.0, w - SIDE * 2.0),
			maxf(1.0, h - TOP_H - GRID_TOP - BOT_H - DESC_H - 14.0))
	_grid.position = Vector2(0, -_scroll)
	_grid.size = Vector2(_clip.size.x, _content_h())


func _card_size() -> Vector2:
	var cw := (size.x - SIDE * 2.0 - GAP * (COLS - 1)) / float(COLS)
	# 卡面宽高比恒定 63:76（battle_scene CARD_W:CARD_H）
	return Vector2(cw, cw * 76.0 / 63.0)


func _content_h() -> float:
	var rows := maxi(1, int(ceil(float(maxi(_cards.size(), 1)) / float(COLS))))
	var cs := _card_size()
	return rows * (cs.y + GAP) - GAP


func _card_rect(k: int) -> Rect2:
	## 第 k 张卡在 **grid 本地坐标系**里的矩形。
	var cs := _card_size()
	return Rect2((k % COLS) * (cs.x + GAP), int(k / COLS) * (cs.y + GAP), cs.x, cs.y)


func _max_scroll() -> float:
	return maxf(0.0, _content_h() - _clip.size.y)


func _clamp_scroll() -> void:
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	_grid.position = Vector2(0, -_scroll)


func _back_rect() -> Rect2:
	return Rect2(16, 12, 104, 40)


func _confirm_rect() -> Rect2:
	var has_cancel: bool = _cfg.get("cancel_label", "") != ""
	if has_cancel:
		return Rect2(size.x / 2.0 + 16.0, size.y - BOT_H + 18.0, 220, 40)
	return Rect2(size.x / 2.0 - 110.0, size.y - BOT_H + 18.0, 220, 40)


func _cancel_rect() -> Rect2:
	return Rect2(size.x / 2.0 - 236.0, size.y - BOT_H + 18.0, 220, 40)


func _can_confirm() -> bool:
	# R301：浏览模式的「关闭」按钮永远可点（没有选中数量这回事）。
	if is_view():
		return true
	# R200：支持区间多选（min_sel..max_sel；min 默认 = max → 旧行为「恰好 N 张」）。
	var mx := int(_cfg.get("max_sel", 1))
	var mn := int(_cfg.get("min_sel", mx))
	return _selected.size() >= mn and _selected.size() <= mx


static func _center_y(rect: Rect2, fs: int) -> float:
	## draw_string 的 pos.y 是**基线**：按字号近似垂直居中。
	return rect.position.y + rect.size.y / 2.0 + fs * 0.35


# ── 绘制 ─────────────────────────────────────────────────────

func _draw() -> void:
	if _cfg.is_empty():
		return
	var w := size.x
	var h := size.y
	# 半透明罩：不是不透明框，战场隐约可见（用户口径「透明背景」）
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.04, 0.09, 0.62))
	# 顶栏
	draw_rect(Rect2(0, 0, w, TOP_H), Color(0.10, 0.09, 0.14, 0.92))
	draw_rect(Rect2(0, TOP_H - 2.0, w, 2.0), UiTheme.INK_500)
	var br := _back_rect()
	draw_rect(br, Color(0.18, 0.16, 0.24, 0.95))
	draw_rect(br, UiTheme.INK_300, false, 1.5)
	var back_icon := UiAssets.get_tex("icon_back")
	if back_icon != null:
		var ir := CardFace.fit_rect(back_icon.get_size(), Rect2(br.position + Vector2(10, 8),
				Vector2(24, 24)))
		draw_texture_rect(back_icon, ir, false)
	else:
		# 缺图回退：程序画「←」
		draw_string(_font_bold, br.position + Vector2(10, 27), "←",
				HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_LABEL, Color("f5ead2"))
	draw_string(_font_bold, br.position + Vector2(42, 27), "返回",
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_LABEL, Color("f5ead2"))
	# 标题（顶栏居中）
	var title_fs := UiTheme.FS_SUBHEAD
	draw_string(_font_bold, Vector2(0, TOP_H / 2.0 + title_fs * 0.35),
			String(_cfg.get("title", "")), HORIZONTAL_ALIGNMENT_CENTER, w,
			title_fs, Color("f2ead8"))
	# 顶栏右侧：选卡模式 = 已选计数；浏览模式 = 共几张
	var max_sel := int(_cfg.get("max_sel", 1))
	if is_view():
		draw_string(_font_bold, Vector2(w - 240.0, TOP_H / 2.0 + UiTheme.FS_LABEL * 0.35),
				"共 %d 张" % _cards.size(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_LABEL, Color("c9c2d4"))
	else:
		draw_string(_font_bold, Vector2(w - 240.0, TOP_H / 2.0 + UiTheme.FS_LABEL * 0.35),
				"已选 %d / %d" % [_selected.size(), max_sel],
				HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_LABEL,
				Color("ffd27d") if _can_confirm() else Color("9a94a8"))
	# 描述条（R191）：卡面只留卡名 → 点选/悬停的卡在这里读描述
	var desc_idx := _hover_idx
	if desc_idx < 0 and not _selected.is_empty():
		desc_idx = _selected[-1]
	if desc_idx >= 0 and desc_idx < _cards.size():
		var dc: CardData = _cards[desc_idx]
		var dr := Rect2(SIDE, h - BOT_H - DESC_H - 6.0, w - SIDE * 2.0, DESC_H)
		draw_rect(dr, Color(0.08, 0.07, 0.12, 0.88))
		draw_rect(dr, Color("ffd27d"), false, 1.2)
		draw_string(_font_bold, dr.position + Vector2(14, 26), dc.card_name,
				HORIZONTAL_ALIGNMENT_LEFT, 170.0, UiTheme.FS_BODY, Color("ffd27d"))
		var meta := "%s · %d 费 · %s" % [dc.kind, dc.cost, dc.rarity_name()]
		draw_string(_font, dr.position + Vector2(14, 48), meta,
				HORIZONTAL_ALIGNMENT_LEFT, 170.0, UiTheme.FS_CAPTION, Color("9a94a8"))
		var eff := CardText.naturalize(dc.effect_text)
		var lines := CardFace.wrap_text(_font, eff, dr.size.x - 210.0, UiTheme.FS_BODY)
		for li in mini(lines.size(), 3):
			draw_string(_font, dr.position + Vector2(196, 24 + li * 20), lines[li],
					HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 210.0, UiTheme.FS_BODY, Color("e8e2d4"))
	# 底栏
	draw_rect(Rect2(0, h - BOT_H, w, BOT_H), Color(0.10, 0.09, 0.14, 0.92))
	draw_rect(Rect2(0, h - BOT_H, w, 2.0), UiTheme.INK_500)
	var note := String(_cfg.get("note", ""))
	if note != "":
		# note 画在**底栏内**左侧（画在底栏上方会被滚动网格的子节点盖住）
		draw_string(_font, Vector2(24, h - BOT_H + 18.0 + UiTheme.FS_CAPTION * 0.35 + 8.0),
				note, HORIZONTAL_ALIGNMENT_LEFT, size.x / 2.0 - 270.0,
				UiTheme.FS_CAPTION, Color("c9c2d4"))
	if _cfg.get("cancel_label", "") != "":
		var cr := _cancel_rect()
		draw_rect(cr, Color(0.32, 0.28, 0.30, 0.95))
		draw_rect(cr, UiTheme.INK_300, false, 1.5)
		draw_string(_font_bold, Vector2(cr.position.x, _center_y(cr, UiTheme.FS_LABEL)),
				String(_cfg["cancel_label"]), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x,
				UiTheme.FS_LABEL, Color("e8e0d0"))
	var ok := _confirm_rect()
	var can := _can_confirm()
	draw_rect(ok, Color(0.24, 0.44, 0.30, 0.98) if can else Color(0.24, 0.23, 0.28, 0.9))
	draw_rect(ok, Color("7fc98a") if can else UiTheme.INK_500, false, 2.0)
	var label := String(_cfg.get("confirm_label", "确认"))
	if max_sel > 1 and not is_view():
		label += "（%d/%d）" % [_selected.size(), max_sel]
	draw_string(_font_bold, Vector2(ok.position.x, _center_y(ok, UiTheme.FS_LABEL)),
			label, HORIZONTAL_ALIGNMENT_CENTER, ok.size.x,
			UiTheme.FS_LABEL, Color.WHITE if can else Color("8d879a"))
	# 滚动提示：内容超一屏时，网格区右侧画一条细轨 + 滑块
	if _max_scroll() > 1.0:
		var track := Rect2(w - SIDE + 14.0, TOP_H + GRID_TOP, 6.0, _clip.size.y)
		draw_rect(track, Color(1, 1, 1, 0.10))
		var thumb_h := maxf(28.0, track.size.y * _clip.size.y / _content_h())
		var ty := track.position.y + (track.size.y - thumb_h) * (_scroll / _max_scroll())
		draw_rect(Rect2(track.position.x, ty, track.size.x, thumb_h), Color(1, 1, 1, 0.35))


func draw_cards(g: Control) -> void:
	## 网格节点 PickGrid._draw 的回调（画全部候选卡；滚出视区的部分由 _clip 裁掉）。
	for k in _cards.size():
		var r := _card_rect(k)
		var c: CardData = _cards[k]
		var picked := _selected.has(k)
		if picked:
			g.draw_rect(r.grow(6.0), Color("ffd27d"), false, 3.0)
		CardFace.draw_pick(g, c, r, _font, _font_bold, picked)   # R191：只留卡名
		if k < _counts.size() and int(_counts[k]) > 1:
			# 同名合并张数角标（专注的卡组合并视图沿用「×N」口径）
			var badge := Rect2(r.position + Vector2(r.size.x - 30, -8), Vector2(34, 22))
			g.draw_rect(badge, Color(0.12, 0.11, 0.16, 0.95))
			g.draw_rect(badge, UiTheme.INK_300, false, 1.0)
			g.draw_string(_font_bold, Vector2(badge.position.x, badge.position.y + 15),
					"×%d" % int(_counts[k]), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x,
					UiTheme.FS_CAPTION, Color("ffd27d"))


# ── 输入 ─────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if _cfg.is_empty():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll -= WHEEL_STEP
			_clamp_scroll()
			_grid.queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll += WHEEL_STEP
			_clamp_scroll()
			_grid.queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = {"pos": mb.position, "scroll": _scroll, "moved": false}
			else:
				var moved: bool = _press.get("moved", true)
				_press = {}
				if not moved:
					_tap(mb.position)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# 右键 = 返回（与 R186「长按=右键」衔接：触屏长按收起选卡页看战场）
			collapse()
			accept_event()
			return
	elif event is InputEventMouseMotion:
		if _press.is_empty():
			# R191：无按压的纯移动 = 悬停跟踪（描述条用）；变化才重绘
			var hm := event as InputEventMouseMotion
			var hidx := _card_at(hm.position)
			if hidx != _hover_idx:
				_hover_idx = hidx
				queue_redraw()
			return
		if not _press.is_empty():
			var mm := event as InputEventMouseMotion
			var dy: float = mm.position.y - (_press["pos"] as Vector2).y
			if absf(dy) > DRAG_SLOP:
				_press["moved"] = true
			if _press.get("moved", false):
				_scroll = (_press["scroll"] as float) - dy
				_clamp_scroll()
				_grid.queue_redraw()
			accept_event()
			return
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_press = {"pos": st.position, "scroll": _scroll, "moved": false}
		else:
			var moved2: bool = _press.get("moved", true)
			_press = {}
			if not moved2:
				_tap(st.position)
		accept_event()
		return
	elif event is InputEventScreenDrag:
		if not _press.is_empty():
			var sd := event as InputEventScreenDrag
			var dy2: float = sd.position.y - (_press["pos"] as Vector2).y
			if absf(dy2) > DRAG_SLOP:
				_press["moved"] = true
			if _press.get("moved", false):
				_scroll = (_press["scroll"] as float) - dy2
				_clamp_scroll()
				_grid.queue_redraw()
			accept_event()
			return


func _unhandled_key_input(event: InputEvent) -> void:
	## overlay 展开时吃掉快捷键（不能选到一半按 E 结束回合）；Esc = 返回（收起看战场）。
	if _cfg.is_empty() or not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_ESCAPE:
			collapse()
		get_viewport().set_input_as_handled()


func _tap(pos: Vector2) -> void:
	## 点按（未拖动）：按钮 → 卡。
	if _back_rect().has_point(pos):
		collapse()
		return
	if _confirm_rect().has_point(pos):
		if is_view():
			# 浏览模式「关闭」：不 emit confirmed —— `[]` 会被调用方当成「没选」直接返回，
			# 窗就关不掉了。统一走 cancelled 让调用方收尾。
			cancelled.emit()
			return
		if _can_confirm():
			var sel := _selected.duplicate()
			confirmed.emit(sel)
		return
	if _cfg.get("cancel_label", "") != "" and _cancel_rect().has_point(pos):
		cancelled.emit()
		return
	var k := _card_at(pos)
	if k >= 0:
		# R294：**点中的卡 = 描述条要显示的那张**。触屏没有 motion 事件，
		# 光靠悬停跟踪的话点了卡描述条也不动；选满时 `_toggle` 会忽略，
		# 但「点一下看看这张」仍然应该成立。
		_hover_idx = k
		if not is_view():
			_toggle(k)   # R301：浏览模式点卡只换描述条，不选中


func _card_at(pos: Vector2) -> int:
	## 屏幕坐标 → 网格卡下标（-1 = 没点中）。命中判定唯一口（_tap / 悬停共用）。
	if not Rect2(_clip.position, _clip.size).has_point(pos):
		return -1
	var local := pos - _clip.position - _grid.position
	if local.x < 0 or local.x > _clip.size.x:
		return -1
	for k in _cards.size():
		if _card_rect(k).has_point(local):
			return k
	return -1


func _toggle(k: int) -> void:
	var max_sel := int(_cfg.get("max_sel", 1))
	if _selected.has(k):
		_selected.erase(k)
	elif max_sel <= 1:
		_selected = [k]
	elif _selected.size() < max_sel:
		_selected.append(k)
	else:
		return   # 选满了：忽略（计数区已有视觉提示）
	_grid.queue_redraw()
	queue_redraw()
