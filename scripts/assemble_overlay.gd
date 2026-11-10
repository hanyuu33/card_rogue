class_name AssembleOverlay
extends Control
## R559 拼装 UI：使用「传授」等拼装效果后弹出的全屏拖拽拼装页。
##
## 三栏（左→右，比例定位、宽屏自适应）：
##   左栏：6 张待选卡（2×3），拖拽源
##   中栏：3 个【一样】的空槽位（上中下：①属性值+卡图 ②上半效果 ③下半效果）
##   右栏：结果预览 = 组合卡（带「组合」印记）+ 上/下效果框 + 确认/取消按钮
##
## 交互：按住待选卡 → 拖到槽位 → 松手填入；三个槽位填满后「确认组合」可点。
## 组合逻辑全部交给引擎（engine.assemble_combo_*），本页只负责显示与拖拽。

signal confirmed()
signal cancelled()

const UiTheme = preload("res://scripts/ui_theme.gd")
const CardFace = preload("res://scripts/card_face.gd")
const UiAssets = preload("res://scripts/ui_assets.gd")
const AssembleRules = preload("res://scripts/assemble_rules.gd")

const DIM_ALPHA := 0.74                 # 暗罩不透明度（深蓝夜色，战场隐约可见）
const LEFT_X := 0.035                   # 左栏起点（比例）
const LEFT_W := 0.235                   # 左栏宽（比例）
const MID_CX := 0.420                   # 中栏中心（比例）
const RIGHT_CX := 0.745                 # 右栏中心（比例）
const CARD_ASPECT := 76.0 / 63.0        # 卡面高/宽
const SLOT_ASPECT := 528.0 / 440.0      # 槽位高/宽
const SLOT_W := 0.125                   # 槽位宽（相对 size.x）
const TITLE_H := 56.0

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


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(engine_ref: Object, cards: Array) -> void:
	_engine = engine_ref
	_cards = cards.duplicate()
	_slot_attr = -1
	_slot_upper = -1
	_slot_lower = -1
	_drag_from = -1
	_press = {}
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


# ── 布局（比例定位，宽屏自适应）───────────────────────────────

func _slot_w() -> float:
	return size.x * SLOT_W


func _slot_h() -> float:
	return _slot_w() * SLOT_ASPECT


func _card_rect(k: int) -> Rect2:
	var gap := size.x * 0.018
	var cw := (size.x * LEFT_W - gap) / 2.0
	var ch := cw * CARD_ASPECT
	var col := k % 2
	var row := int(k / 2)
	var x := size.x * LEFT_X + col * (cw + gap)
	var y := TITLE_H + 20.0 + row * (ch + gap)
	return Rect2(x, y, cw, ch)


func _slot_center(slot: int) -> Vector2:
	# 三个槽位在中栏垂直均布（顶部给标题留白）
	var cx := size.x * MID_CX
	var sh := _slot_h()
	var gap := sh * 0.30
	var total := sh * 3.0 + gap * 2.0
	var top := (size.y - total) * 0.52
	var cy := top + sh * 0.5 + slot * (sh + gap)
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
	return Rect2(cx - cw / 2.0, TITLE_H + 26.0, cw, ch)


func _effect_rect(i: int) -> Rect2:
	var cx := size.x * RIGHT_CX
	var w := _slot_w() * 1.35
	var h := 42.0
	var pr := _preview_rect()
	var y := pr.end.y + 34.0 + i * (h + 12.0)
	return Rect2(cx - w / 2.0, y, w, h)


func _confirm_rect() -> Rect2:
	var cx := size.x * RIGHT_CX
	return Rect2(cx - 110.0, size.y - 86.0, 220.0, 52.0)


func _cancel_rect() -> Rect2:
	var cx := size.x * RIGHT_CX
	return Rect2(cx - 110.0, size.y - 150.0, 220.0, 44.0)


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
	# 深蓝夜色暗罩
	draw_rect(Rect2(0, 0, w, h), Color(0.06, 0.07, 0.11, DIM_ALPHA))
	# 顶栏
	draw_rect(Rect2(0, 0, w, TITLE_H), Color(0.08, 0.09, 0.13, 0.92))
	draw_rect(Rect2(0, TITLE_H - 2.0, w, 2.0), Color("c8951c"))
	draw_string(_font_bold, Vector2(0, TITLE_H / 2.0 + UiTheme.FS_SUBHEAD * 0.35),
			"拼装 · 拖 3 张卡到槽位", HORIZONTAL_ALIGNMENT_CENTER, w,
			UiTheme.FS_SUBHEAD, Color("f2c14e"))
	# 左栏：待选卡
	draw_string(_font, Vector2(size.x * LEFT_X, TITLE_H + 14.0), "待选卡（拖到槽位）",
			HORIZONTAL_ALIGNMENT_LEFT, size.x * LEFT_W, UiTheme.FS_LABEL, Color("c9c2d4"))
	for k in _cards.size():
		var r := _card_rect(k)
		if k == _drag_from:
			continue   # 被拖的卡在手指下方单独画
		var card: CardData = _cards[k]
		var used := k == _slot_attr or k == _slot_upper or k == _slot_lower
		CardFace.draw_pick(self, card, r, _font, _font_bold, used)
		if used:
			draw_rect(r.grow(3.0), Color("f2c14e"), false, 2.0)
	# 中栏：3 个一样空槽位
	draw_string(_font, Vector2(size.x * MID_CX, TITLE_H + 14.0), "拖入槽位",
			HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.2, UiTheme.FS_LABEL, Color("c9c2d4"))
	var slot_labels := ["① 属性值 + 卡图", "② 上半效果", "③ 下半效果"]
	var slot_tex := UiAssets.get_tex("assemble_slot_card")
	for slot in 3:
		var sr := _slot_rect(slot)
		var idx := _slot_index(slot)
		if slot_tex != null:
			draw_texture_rect(slot_tex, sr, false)
		else:
			draw_rect(sr, Color(0.91, 0.89, 0.85, 0.9))
			draw_rect(sr, Color("c8951c"), false, 2.0)
		# 槽位标签（槽位上方）
		draw_string(_font_bold, Vector2(sr.position.x + sr.size.x / 2.0, sr.position.y - 6.0),
				slot_labels[slot], HORIZONTAL_ALIGNMENT_CENTER, sr.size.x,
				UiTheme.FS_CAPTION, Color("f2c14e"))
		# 已填：显示内容
		if idx >= 0:
			_draw_slot_content(sr, slot, _cards[idx])
		else:
			_draw_slot_hint(sr, slot)
	# 右栏：结果预览
	_draw_preview()
	# 拖拽中的卡（画在最上层）
	if _drag_from >= 0 and _drag_from < _cards.size():
		var dr := Rect2(_drag_pos - Vector2(_slot_w() * 0.4, _slot_w() * 0.4 * CARD_ASPECT),
				Vector2(_slot_w() * 0.8, _slot_w() * 0.8 * CARD_ASPECT))
		CardFace.draw_pick(self, _cards[_drag_from], dr, _font, _font_bold, false)


func _draw_slot_content(sr: Rect2, slot: int, card: CardData) -> void:
	if slot == 0:
		# ①属性值+卡图：直接画完整卡面（卡图 + 姓名牌 + 数值徽章）
		CardFace.draw_pick(self, card, sr, _font, _font_bold, false)
	else:
		# ②③效果：写效果文字
		var text := ""
		if slot == 1 and not card.upper_effect.is_empty():
			text = AssembleRules.fragment_text(card.upper_effect)
		elif slot == 2 and not card.lower_effect.is_empty():
			text = AssembleRules.fragment_text(card.lower_effect)
		_draw_wrapped(sr.grow(-10.0), text, UiTheme.FS_CAPTION, Color("1a1c22"))


func _draw_slot_hint(sr: Rect2, slot: int) -> void:
	var hint := "拖到这里"
	match slot:
		0: hint = "拖入卡 → 属性值 + 卡图"
		1: hint = "拖入卡 → 上半效果"
		2: hint = "拖入卡 → 下半效果"
	draw_string(_font, Vector2(sr.position.x + sr.size.x / 2.0, sr.position.y + sr.size.y / 2.0),
			hint, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 10.0, UiTheme.FS_CAPTION, Color("9a8f80"))


func _draw_preview() -> void:
	var cx := size.x * RIGHT_CX
	draw_string(_font, Vector2(cx, TITLE_H + 16.0), "结果预览",
			HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.2, UiTheme.FS_LABEL, Color("c9c2d4"))
	var pr := _preview_rect()
	if not _all_filled():
		# 未填满：空预览卡框 + 提示
		draw_rect(pr, Color(0.91, 0.89, 0.85, 0.6))
		draw_rect(pr, Color("c8951c"), false, 2.0)
		draw_string(_font, Vector2(cx, pr.position.y + pr.size.y / 2.0),
				"拖满 3 个槽位后\n这里显示组合卡", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x,
				UiTheme.FS_LABEL, Color("6b6b6b"))
	else:
		var result: CardData = _engine.assemble_combo_preview() if _engine != null else null
		if result != null:
			CardFace.draw_pick(self, result, pr, _font, _font_bold, false)
			# 组合印记（右上角）
			var seal := UiAssets.get_tex("assemble_seal")
			if seal != null:
				var ss := pr.size.x * 0.30
				draw_texture_rect(seal, Rect2(pr.end.x - ss - 2.0, pr.position.y + 2.0, ss, ss), false)
	# 上/下效果框
	var eff_tex := UiAssets.get_tex("assemble_slot_effect")
	for i in 2:
		var er := _effect_rect(i)
		if eff_tex != null:
			draw_texture_rect(eff_tex, er, false)
		else:
			draw_rect(er, Color(0.91, 0.89, 0.85, 0.9))
			draw_rect(er, Color("c8951c"), false, 2.0)
		var txt := ""
		if _all_filled():
			var up: CardData = _cards[_slot_upper]
			var lo: CardData = _cards[_slot_lower]
			if i == 0 and not up.upper_effect.is_empty():
				txt = AssembleRules.fragment_text(up.upper_effect)
			elif i == 1 and not lo.lower_effect.is_empty():
				txt = AssembleRules.fragment_text(lo.lower_effect)
		var tag := "上半效果" if i == 0 else "下半效果"
		if txt == "":
			txt = tag + "（待选）"
		_draw_wrapped(er.grow(-8.0), tag + "：" + txt, UiTheme.FS_CAPTION, Color("1a1c22"))
	# 取消 / 确认按钮
	var cr := _cancel_rect()
	draw_rect(cr, Color(0.32, 0.28, 0.30, 0.95))
	draw_rect(cr, Color("b8b4aa"), false, 1.5)
	draw_string(_font_bold, Vector2(cr.position.x, cr.position.y + cr.size.y / 2.0 + UiTheme.FS_LABEL * 0.35),
			"取消拼装", HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, UiTheme.FS_LABEL, Color("e8e0d0"))
	var ok := _confirm_rect()
	var can := _all_filled()
	draw_rect(ok, Color(0.24, 0.44, 0.30, 0.98) if can else Color(0.24, 0.23, 0.28, 0.9))
	draw_rect(ok, Color("7fc98a") if can else Color("6b6b6b"), false, 2.0)
	draw_string(_font_bold, Vector2(ok.position.x, ok.position.y + ok.size.y / 2.0 + UiTheme.FS_LABEL * 0.35),
			"确认组合", HORIZONTAL_ALIGNMENT_CENTER, ok.size.x, UiTheme.FS_LABEL,
			Color.WHITE if can else Color("8d879a"))


func _draw_wrapped(rect: Rect2, text: String, fs: int, col: Color) -> void:
	var lines := CardFace.wrap_text(_font, text, rect.size.x, fs)
	var y := rect.position.y + 8.0
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
			cancelled.emit()
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
			cancelled.emit()
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
			if _engine != null:
				match slot:
					0:
						_slot_attr = _drag_from
						_engine.assemble_combo_set_slot("attr", _drag_from)
					1:
						_slot_upper = _drag_from
						_engine.assemble_combo_set_slot("upper", _drag_from)
					2:
						_slot_lower = _drag_from
						_engine.assemble_combo_set_slot("lower", _drag_from)
				queue_redraw()
			return


func _tap(pos: Vector2) -> void:
	if _confirm_rect().has_point(pos):
		if _all_filled():
			confirmed.emit()
		return
	if _cancel_rect().has_point(pos):
		cancelled.emit()
		return
