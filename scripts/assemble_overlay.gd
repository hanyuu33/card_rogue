class_name AssembleOverlay
extends Control
## R559 组合 UI：使用「传授」等组合效果后弹出的全屏拖拽组合页。
##
## 三栏（左→右，比例定位、宽屏自适应）：
##   左栏：6 张待选卡（2×3），拖拽源
##   中栏：3 个【一样】的空槽位（上中下：①属性值+卡图 ②上半效果 ③下半效果）
##   右栏：结果预览 = 组合卡（带「组合」印记）+ 上/下效果框 + 确认/取消按钮
##
## 交互：按住待选卡 → 拖到槽位 → 松手填入；三个槽位填满后「确认组合」可点。
## 组合逻辑全部交给引擎（engine.assemble_combo_*），本页只负责显示与拖拽。
##
## ⚠️ R559b 视觉重做（用户口径「文字和框体搭配非常差，美术素材基本没上」）：
##   第一版用 draw_rect 硬画纯色框 + 从概念图自切三张素材（assemble_seal / slot_card /
##   slot_effect），风格与游戏不符。重做后**全部接回游戏现有素材体系**：
##     · 空槽位 = `card_paper` 纸底 + `ACCENT_GOLD` 描边（与真卡同源纸底，天然协调）；
##     · 待选卡 / 结果卡 = `CardFace.draw_pick` 真卡；
##     · 上/下效果框 = `UiTheme.draw_info_card`（羊皮纸面板 + 黄铜细线）；
##     · 按钮 = `UiTheme.draw_secondary_btn`（button_forest / button_paper 素材）；
##     · 「组合」印记 = `CardInfoBoxes.draw_glyph` 的 combine 自绘符号 + 金字，不贴图。

signal confirmed()
signal cancelled()

const UiTheme = preload("res://scripts/ui_theme.gd")
const CardFace = preload("res://scripts/card_face.gd")
const UiAssets = preload("res://scripts/ui_assets.gd")
const AssembleRules = preload("res://scripts/assemble_rules.gd")
const CardInfoBoxes = preload("res://scripts/card_info_boxes.gd")

const DIM_ALPHA := 0.85                 # 暗罩不透明度（深蓝夜色，战场隐约可见）
const TITLE_H := 56.0                   # 顶栏高
const LEFT_X := 0.030                   # 左栏起点（比例）
const LEFT_W := 0.235                   # 左栏宽（比例）
const MID_CX := 0.440                   # 中栏中心（比例）
const RIGHT_CX := 0.725                 # 右栏中心（比例）
const CARD_ASPECT := 76.0 / 63.0        # 卡面高/宽
const SLOT_W := 0.120                   # 槽位 / 结果卡宽（相对 size.x）
const SLOT_GAP := 24.0                  # 槽位竖直间距
const BUTTON_H := 48.0                  # 按钮高（>44 才走 adventure_button_style 素材胶囊，不走纯色 chip）

var _font: Font
var _font_bold: Font
var _engine: Object = null
var _cards: Array = []
var _slot_attr := -1
var _slot_upper := -1
var _slot_lower := -1
var _drag_from := -1
var _drag_pos := Vector2.ZERO
var _press := {}                          # {pos, moved}
var _tip := ""                            # R562：底部一句提示（右键/ESC 不再直接取消）
var _tip_until := 0


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# ⚠️ R562：battle.tscn 里的 hp_strip 等节点排在 overlay **之后**（本节点是 _ready 里
	# add_child 的，但不是最后一个），不抬 z 的话它们会画在本页之上 —— 实测底部提示行
	# 被「我方生命」条整段盖掉。全屏模态页必须压在所有战斗 UI 之上。
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	# ⚠️ anchors 首帧可能未立即生效（实测 size 停在 (0,0)）→ 手动对齐父节点尺寸；
	# 窗口缩放 / 安卓切前台时靠 resized + viewport.size_changed 重新对齐。
	resized.connect(_sync_size)
	get_viewport().size_changed.connect(_sync_size)


func _sync_size() -> void:
	var p := get_parent()
	if p is Control:
		var ps: Vector2 = (p as Control).size
		if ps != size:
			size = ps
			queue_redraw()


func open(engine_ref: Object, cards: Array) -> void:
	_engine = engine_ref
	_cards = cards.duplicate()
	_slot_attr = -1
	_slot_upper = -1
	_slot_lower = -1
	_drag_from = -1
	_press = {}
	_tip = ""
	_tip_until = 0
	_sync_size()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	_cards = []
	_engine = null
	_slot_attr = -1
	_slot_upper = -1
	_slot_lower = -1
	_drag_from = -1
	_tip = ""
	_tip_until = 0


func _show_tip(text: String, ms := 4000) -> void:
	## R562：只提示、不动作 —— 误触右键不该把这次组合机会直接丢掉。
	_tip = text
	_tip_until = Time.get_ticks_msec() + ms
	queue_redraw()


func _process(_d: float) -> void:
	if _tip != "" and Time.get_ticks_msec() > _tip_until:
		_tip = ""
		queue_redraw()


# ── 布局（比例定位，宽屏自适应）───────────────────────────────

func _slot_w() -> float:
	return size.x * SLOT_W


func _slot_h() -> float:
	return _slot_w() * CARD_ASPECT


func _card_rect(k: int) -> Rect2:
	## ⚠️ R561：卡片上下各有数值徽章**故意探出卡框**（费用圆心压左上角、力/生在卡下沿），
	## 行距必须 ≥ 两倍徽章半径，否则上一排的生命徽章会和下一排的费用徽章叠在一起。
	## 同时顶部要给「待选卡 / 拖到中栏槽位…」两行说明留位，卡片不能再从 TITLE_H+40 开始压上去。
	var gap := size.x * 0.026
	var top := TITLE_H + 54.0
	var avail := size.y - top - 12.0
	var ch: float = (avail - gap * 2.0) / 3.0
	var cw: float = ch / CARD_ASPECT
	var max_w: float = (size.x * LEFT_W - gap) / 2.0
	if cw > max_w:
		cw = max_w
		ch = cw * CARD_ASPECT
	var total_w: float = cw * 2.0 + gap
	var x0: float = size.x * LEFT_X + (size.x * LEFT_W - total_w) * 0.5
	var col := k % 2
	var row := int(k / 2)
	return Rect2(x0 + col * (cw + gap), top + row * (ch + gap), cw, ch)


func _slot_center(slot: int) -> Vector2:
	# 三个槽位在中栏垂直均布（顶部给标题留白）
	var cx := size.x * MID_CX
	var sh := _slot_h()
	var total := sh * 3.0 + SLOT_GAP * 2.0
	var top := TITLE_H + (size.y - TITLE_H - total) * 0.5
	var cy := top + sh * 0.5 + slot * (sh + SLOT_GAP)
	return Vector2(cx, cy)


func _slot_rect(slot: int) -> Rect2:
	var c := _slot_center(slot)
	var sw := _slot_w()
	var sh := _slot_h()
	return Rect2(c.x - sw / 2.0, c.y - sh / 2.0, sw, sh)


func _preview_rect() -> Rect2:
	var cx := size.x * RIGHT_CX
	var cw := _slot_w()
	var ch := cw * CARD_ASPECT
	return Rect2(cx - cw / 2.0, TITLE_H + 40.0, cw, ch)


func _seal_rect() -> Rect2:
	# 「组合 · 生成它」印记：结果卡正下方一条小徽章。
	var pr := _preview_rect()
	return Rect2(pr.position.x, pr.end.y + 10.0, pr.size.x, 28.0)


func _effect_rect(i: int) -> Rect2:
	var cx := size.x * RIGHT_CX
	var w := _slot_w() * 1.45
	var h := 96.0
	var sr := _seal_rect()
	var y := sr.end.y + 22.0 + i * (h + 12.0)
	return Rect2(cx - w / 2.0, y, w, h)


func _confirm_rect() -> Rect2:
	var cx := size.x * RIGHT_CX
	return Rect2(cx - 110.0, size.y - 64.0, 220.0, BUTTON_H)


func _cancel_rect() -> Rect2:
	var cx := size.x * RIGHT_CX
	return Rect2(cx - 110.0, size.y - 64.0 - BUTTON_H - 10.0, 220.0, BUTTON_H)


func _all_filled() -> bool:
	return _slot_attr >= 0 and _slot_upper >= 0 and _slot_lower >= 0


func _slot_index(slot: int) -> int:
	match slot:
		0: return _slot_attr
		1: return _slot_upper
		2: return _slot_lower
	return -1


# ── 绘制 ─────────────────────────────────────────────────────

func _draw() -> void:
	if _cards.is_empty():
		return
	var w := size.x
	var h := size.y
	# 深蓝夜色暗罩（对齐 pick_overlay 的暗罩基调）
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.04, 0.09, DIM_ALPHA))
	# 顶栏：暗底 + 金色底边线
	draw_rect(Rect2(0, 0, w, TITLE_H), Color(0.10, 0.09, 0.14, 0.92))
	draw_rect(Rect2(0, TITLE_H - 2.0, w, 2.0), UiTheme.ACCENT_GOLD)
	draw_string(_font_bold, Vector2(0, TITLE_H / 2.0 + UiTheme.FS_SUBHEAD * 0.35),
			"组合", HORIZONTAL_ALIGNMENT_CENTER, w,
			UiTheme.FS_SUBHEAD, UiTheme.ACCENT_LIT)
	# 左栏：待选卡（真卡）
	draw_string(_font_bold, Vector2(size.x * LEFT_X, TITLE_H + 26.0), "待选卡",
			HORIZONTAL_ALIGNMENT_LEFT, size.x * LEFT_W, UiTheme.FS_LABEL, UiTheme.ACCENT_LIT)
	draw_string(_font, Vector2(size.x * LEFT_X, TITLE_H + 26.0 + 18.0), "拖到中栏槽位 · ①属性 ②上半 ③下半",
			HORIZONTAL_ALIGNMENT_LEFT, size.x * LEFT_W, UiTheme.FS_CAPTION, UiTheme.INK_ON_DARK)
	for k in _cards.size():
		var r := _card_rect(k)
		if k == _drag_from:
			continue   # 被拖的卡在手指下方单独画
		var card: CardData = _cards[k]
		var used := k == _slot_attr or k == _slot_upper or k == _slot_lower
		CardFace.draw_pick(self, card, r, _font, _font_bold, used)
	# 中栏：3 个一样空槽位
	# ⚠️ R562：`HORIZONTAL_ALIGNMENT_CENTER` 的第二个参数是**矩形左边界**，不是中心点。
	# 原来这里传 `size.x * MID_CX`（中心）+ 宽 0.2w → 文字整体右移半格，标题压在右栏边上。
	draw_string(_font_bold, Vector2(size.x * MID_CX - size.x * 0.1, TITLE_H + 26.0), "拖入槽位",
			HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.2, UiTheme.FS_LABEL, UiTheme.ACCENT_LIT)
	for slot in 3:
		var sr := _slot_rect(slot)
		var idx := _slot_index(slot)
		_draw_slot(sr, slot, idx)
		# R562：拖动中把「松手会落进去的那个槽」圈出来 —— 之前完全没有落点反馈。
		if _drag_from >= 0 and sr.has_point(_drag_pos):
			draw_rect(sr.grow(2.0), UiTheme.ACCENT_LIT, false, 3.0)
	# 右栏：结果预览
	_draw_preview()
	# 拖拽中的卡（画在最上层）
	if _drag_from >= 0 and _drag_from < _cards.size():
		var dr := Rect2(_drag_pos - Vector2(_slot_w() * 0.4, _slot_w() * 0.4 * CARD_ASPECT),
				Vector2(_slot_w() * 0.8, _slot_w() * 0.8 * CARD_ASPECT))
		CardFace.draw_pick(self, _cards[_drag_from], dr, _font, _font_bold, false)


func _draw_slot(sr: Rect2, slot: int, idx: int) -> void:
	## 槽位：空态 = card_paper 纸底 + 金边 + 序号徽章（不写任何效果文本）；填态 = 真卡。
	## R559c：效果文字只出现在右侧文本框；中栏槽位（①属性 ②上半 ③下半）填了就是一张卡。
	if idx >= 0:
		CardFace.draw_pick(self, _cards[idx], sr, _font, _font_bold, false)
		return
	_draw_slot_paper(sr)
	_draw_slot_index(sr, slot)


func _draw_slot_index(sr: Rect2, slot: int) -> void:
	## 空槽位左上角序号徽章（①②③）：金圈 + 数字，标识「①属性 ②上半 ③下半」。
	var marks := ["①", "②", "③"]
	var c := sr.position + Vector2(18.0, 18.0)
	draw_circle(c, 11.0, Color(0.12, 0.10, 0.06, 0.92))
	draw_circle(c, 11.0, UiTheme.ACCENT_GOLD, false, 1.5)
	draw_string(_font_bold, Vector2(c.x - 11.0, c.y + UiTheme.FS_CAPTION * 0.35),
			marks[slot], HORIZONTAL_ALIGNMENT_CENTER, 22.0, UiTheme.FS_CAPTION, UiTheme.ACCENT_LIT)


func _draw_slot_paper(sr: Rect2) -> void:
	## 空槽位底：card_paper 纸底 + 金色描边（弱化一档，与真卡区分但同源）。
	var paper: Texture2D = UiAssets.card_paper()
	if paper != null:
		draw_texture_rect(UiAssets.filtered(paper, ceili(maxf(sr.size.x, sr.size.y) * 1.5)), sr, false)
	else:
		draw_rect(sr, UiTheme.PAPER)
	draw_rect(sr, Color(UiTheme.ACCENT_GOLD.r, UiTheme.ACCENT_GOLD.g, UiTheme.ACCENT_GOLD.b, 0.75),
			false, 2.0)


func _draw_preview() -> void:
	var cx := size.x * RIGHT_CX
	draw_string(_font_bold, Vector2(cx - size.x * 0.1, TITLE_H + 26.0), "结果预览",
			HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.2, UiTheme.FS_LABEL, UiTheme.ACCENT_LIT)
	var pr := _preview_rect()
	if not _all_filled():
		# 未填满：空预览卡框 + 提示
		_draw_slot_paper(pr)
		draw_string(_font, Vector2(pr.position.x, pr.position.y + pr.size.y * 0.46), "拖满 3 个槽位",
				HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
		draw_string(_font, Vector2(pr.position.x, pr.position.y + pr.size.y * 0.46 + 20.0), "后显示组合卡",
				HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
	else:
		var result: CardData = _engine.assemble_combo_preview() if _engine != null else null
		if result != null:
			CardFace.draw_pick(self, result, pr, _font, _font_bold, false)
	# 「组合 · 生成它」印记（结果卡下方）：combine 自绘符号 + 金字
	var sr := _seal_rect()
	draw_rect(sr, Color(0.12, 0.10, 0.06, 0.95))
	draw_rect(sr, UiTheme.ACCENT_GOLD, false, 1.5)
	CardInfoBoxes.draw_glyph(self, Vector2(sr.position.x + 18.0, sr.get_center().y), 10.0, "combine", UiTheme.ACCENT_LIT)
	draw_string(_font_bold, Vector2(sr.position.x + 34.0, sr.get_center().y + UiTheme.FS_CAPTION * 0.35),
			"组合 · 生成它", HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 40.0,
			UiTheme.FS_CAPTION, UiTheme.ACCENT_LIT)
	# 上/下效果框（游戏羊皮纸面板素材 + 黄铜包角；未拖入对应卡时不写效果文本）
	var tags := ["上半效果", "下半效果"]
	for i in 2:
		var er := _effect_rect(i)
		# R559c：用 adventure 面板素材（panel_journal_light 九宫格）而非纯色圆角矩形。
		draw_style_box(UiTheme.adventure_panel_style(12.0), er)
		draw_string(_font_bold, Vector2(er.position.x, er.position.y + 32.0),
				tags[i], HORIZONTAL_ALIGNMENT_CENTER, er.size.x,
				UiTheme.FS_CAPTION, UiTheme.ACCENT_GOLD)
		# R562：两个框**各自独立** —— 拖进上半就立刻显示上半效果，不必等下半也填好。
		# （原来套了一层 `_all_filled()`，玩家拖上半时框里空空，以为没吃进去。）
		var txt := ""
		if i == 0 and _slot_upper >= 0:
			var up: CardData = _cards[_slot_upper]
			if not up.upper_effect.is_empty():
				txt = AssembleRules.fragment_text(up.upper_effect)
		elif i == 1 and _slot_lower >= 0:
			var lo: CardData = _cards[_slot_lower]
			if not lo.lower_effect.is_empty():
				txt = AssembleRules.fragment_text(lo.lower_effect)
		if txt != "":
			# R562：左右内边距对称（原来左 36 / 右 12），别让文字贴死在包角上。
			var body := Rect2(er.position.x + 40.0, er.position.y + 50.0,
					er.size.x - 80.0, er.size.y - 60.0)
			_draw_wrapped(body, txt, UiTheme.FS_CAPTION, UiTheme.INK_800)
	if _tip != "":
		# R562：取消按钮上方的提示行（右键/ESC/落点为空时的说明）——
		# 自带暗底 + 金边围一条，压在血条/战场上也能一眼看见。
		var fs := UiTheme.FS_CAPTION
		var tw: float = _font.get_string_size(_tip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# 提示条跟「取消组合」按钮同一栏居中（按整屏居中的话会甩到左栏槽位上）
		var bx: float = _cancel_rect().get_center().x - (tw + 24.0) * 0.5
		var ty := _cancel_rect().position.y - 20.0
		var br := Rect2(bx, ty - fs, tw + 24.0, fs + 12.0)
		draw_rect(br, Color(0.08, 0.07, 0.05, 0.94))
		draw_rect(br, UiTheme.ACCENT_GOLD, false, 1.0)
		draw_string(_font, Vector2(bx + 12.0, ty), _tip, HORIZONTAL_ALIGNMENT_LEFT, tw,
				fs, UiTheme.ACCENT_LIT)
	# 取消 / 确认按钮（button_paper / button_forest 素材）
	var cr := _cancel_rect()
	UiTheme.draw_secondary_btn(self, cr, "取消组合", false, false, false)
	var ok := _confirm_rect()
	var can := _all_filled()
	UiTheme.draw_secondary_btn(self, ok, "确认组合", false, not can, true)


func _draw_wrapped(rect: Rect2, text: String, fs: int, col: Color) -> void:
	var lines := CardFace.wrap_text(_font, text, rect.size.x, fs)
	var y := rect.position.y + 4.0
	for li in mini(lines.size(), 4):
		draw_string(_font, Vector2(rect.position.x, y + fs * 0.8), lines[li],
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, fs, col)
		y += fs + 3.0


# ── 输入 ─────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if _cards.is_empty():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = {"pos": mb.position, "moved": false}
				_drag_from = _card_at(mb.position)
				_drag_pos = mb.position
				queue_redraw()
			else:
				var moved: bool = _press.get("moved", true)
				_press = {}
				if _drag_from >= 0:
					_drop_at(mb.position)
				elif not moved:
					_tap(mb.position)
				_drag_from = -1
				queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# R562：⛔ 原来这里直接发取消信号 —— 界面当场隐藏，而这张传授卡
			# 已经打出去了，组合机会白丢；更要命的是在 `_gui_input` 里把自己 hide 掉，
			# 鼠标的 over 状态留在了一个已隐藏的控件上，之后所有点击都落空（表现为卡死）。
			# 现在右键只提示，真正的放弃必须点下方「取消组合」按钮。
			_show_tip("要放弃这次组合，请点下方「取消组合」")
			accept_event()
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_from >= 0:
			if (mm.position - (_press.get("pos", mm.position) as Vector2)).length() > 6.0:
				_press["moved"] = true
			_drag_pos = mm.position
			queue_redraw()
			accept_event()
			return
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_press = {"pos": st.position, "moved": false}
			_drag_from = _card_at(st.position)
			_drag_pos = st.position
			queue_redraw()
		else:
			var moved2: bool = _press.get("moved", true)
			_press = {}
			if _drag_from >= 0:
				_drop_at(st.position)
			elif not moved2:
				_tap(st.position)
			_drag_from = -1
			queue_redraw()
		accept_event()
		return
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _drag_from >= 0:
			if (sd.position - (_press.get("pos", sd.position) as Vector2)).length() > 6.0:
				_press["moved"] = true
			_drag_pos = sd.position
			queue_redraw()
			accept_event()
			return


func _unhandled_key_input(event: InputEvent) -> void:
	if _cards.is_empty() or not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_ESCAPE:
			_show_tip("要放弃这次组合，请点下方「取消组合」")
		get_viewport().set_input_as_handled()


func _card_at(pos: Vector2) -> int:
	for k in _cards.size():
		if _card_rect(k).has_point(pos):
			return k
	return -1


func _drop_at(pos: Vector2) -> void:
	## 松手：落在哪个槽位就填哪个（overlay 自己记 + 引擎同步，供预览结算用）。
	for slot in 3:
		if _slot_rect(slot).has_point(pos):
			fill_slot(slot, _drag_from)
			return
	# R562：落在槽位外面 → 说一句，别让玩家以为「拖了但没反应」。
	_show_tip("拖到中栏三个槽位里才能放：①属性 ②上半 ③下半")


func fill_slot(slot: int, idx: int) -> void:
	## 填槽唯一口：overlay 自己记 + 引擎同步（拖拽落点 / 演示预填共用）。
	match slot:
		0:
			_slot_attr = idx
			if _engine != null:
				_engine.assemble_combo_set_slot("attr", idx)
		1:
			_slot_upper = idx
			if _engine != null:
				_engine.assemble_combo_set_slot("upper", idx)
		2:
			_slot_lower = idx
			if _engine != null:
				_engine.assemble_combo_set_slot("lower", idx)
	queue_redraw()


func _tap(pos: Vector2) -> void:
	if _confirm_rect().has_point(pos):
		if _all_filled():
			confirmed.emit()
		return
	if _cancel_rect().has_point(pos):
		cancelled.emit()
		return
