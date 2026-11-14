class_name CardDetailOverlay
extends Control
## R564 共用**卡牌详情页** —— 一块全屏浮层：左边大卡，右边文字。
##
## 为什么要有它：选卡/组合这类页面为了塞下多张卡，卡面走的是 `CardFace.draw_pick()`
## （**只保留卡名**，规则见 R191）。玩家在这种页面里看不到效果文，只能凭记忆认卡。
## 这里给一个「点开看清」的出口，内容与 `DeckViewer._draw_detail()` 同一口径
## （种类/职业/稀有度/费用 → 数值 → 本局永久成长 → 效果文全文）。
##
## 调用方：`AssembleOverlay`（待选卡 / 槽内卡 / 结果预览卡）、`PickOverlay`（选卡页与弃牌区浏览）。
##
## 关法：点任意处 / 右键 / ESC —— **只关这一层**，不会连带关掉底下那页。
## ⚠️ 关闭一律走 `close.call_deferred()`：在派发这次输入的同一个回调里把自己 hide 掉，
##    鼠标 over 会悬在一个已隐藏控件上，之后点击全落空（R562 踩过的坑）。

const UiTheme = preload("res://scripts/ui_theme.gd")
const CardFace = preload("res://scripts/card_face.gd")
const CardText = preload("res://scripts/card_text.gd")

var _font: Font
var _font_bold: Font
var _card: CardData = null
var _note := ""            # 调用方给的补充说明（如「组合结果预览，尚未生成」）
var _closing := false


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 父级组合页自己就是 z_index=100；这里再叠一层 → 详情永远压在组合页之上。
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	resized.connect(_sync_size)
	get_viewport().size_changed.connect(_sync_size)


func _sync_size() -> void:
	## anchors 首帧可能没结算（与 AssembleOverlay 同款坑）→ 手动对齐父级尺寸。
	var p := get_parent()
	if p is Control:
		var ps: Vector2 = (p as Control).size
		if ps != size:
			size = ps
			queue_redraw()


func open(card: CardData, note := "") -> void:
	if card == null:
		return
	_card = card
	_note = note
	_closing = false
	_sync_size()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func close() -> void:
	_card = null
	_note = ""
	_closing = false
	visible = false


func is_open() -> bool:
	return visible and _card != null


# ── 布局 ─────────────────────────────────────────────────────

func _layout() -> Dictionary:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		w = 1280.0
		h = 720.0
	var pw: float = minf(w * 0.82, 1040.0)
	# 卡先定尺寸、面板高度跟着卡走 —— 效果文只有一两行的卡，不该在大面板里空出半屏。
	var chh: float = minf(minf(h * 0.72, 520.0), h * 0.86 - 56.0)
	var cw: float = chh * 63.0 / 76.0
	var max_cw: float = pw * 0.34
	if cw > max_cw:
		cw = max_cw
		chh = cw * 76.0 / 63.0
	var ph: float = chh + 56.0
	var panel := Rect2((w - pw) * 0.5, (h - ph) * 0.5, pw, ph)
	# 左边距 34：卡的费用徽章圆心在卡框左上角、半径约 14，留 26 会被面板角饰压住。
	var card := Rect2(panel.position.x + 34.0,
			panel.position.y + (ph - chh) * 0.5, cw, chh)
	var tx: float = card.end.x + 32.0
	var text := Rect2(tx, panel.position.y + 40.0,
			panel.end.x - 26.0 - tx, ph - 82.0)
	return {"panel": panel, "card": card, "text": text}


# ── 绘制 ─────────────────────────────────────────────────────

func _draw() -> void:
	if _card == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.07, 0.90))
	var L := _layout()
	draw_style_box(UiTheme.adventure_panel_style(14.0), L["panel"])
	# 左：大卡（完整卡面：种类行、数值、效果文都在，与手牌同一套排版）
	CardFace.draw(self, _card, L["card"], _card.health, false, false,
			_font, _font_bold)
	# 右：文字区
	var t: Rect2 = L["text"]
	var x := t.position.x
	var w := t.size.x
	var y := t.position.y + 6.0
	# R602：这里每一行都是「单行 draw_string + 固定行距」，超宽时只会被裁掉尾巴
	# （卡名尤其明显）。一律先问 `fit_font_size` 要一个放得下的字号，再画。
	var name_fs := UiTheme.fit_font_size(_font_bold, _card.card_name, w, 40.0,
			UiTheme.FS_TITLE, 16)
	draw_string(_font_bold, Vector2(x, y), _card.card_name,
			HORIZONTAL_ALIGNMENT_LEFT, w, name_fs, UiTheme.INK_900)
	y += 34.0
	var fee_txt := GameI18n.ui("map", "CARD_DETAIL_X_COST", "X 费") if _card.x_cost else GameI18n.ui("map", "CARD_DETAIL_COST", "%d 费") % _card.cost
	var meta_txt := GameI18n.ui("map", "CARD_DETAIL_META_TEMPLATE", "%s · %s · %s · %s") % [_card.kind, _card.card_class,
			_card.rarity_name(), fee_txt]
	draw_string(_font, Vector2(x, y), meta_txt,
			HORIZONTAL_ALIGNMENT_LEFT, w,
			UiTheme.fit_font_size(_font, meta_txt, w, 30.0, UiTheme.FS_LABEL, 10),
			UiTheme.INK_600)
	y += 30.0
	# 数值行：技能卡 `stats_line()` 只说「直接使用」→ 把伤害写出来，否则看不出成长
	var st := CardFace.stats_line(_card)
	if _card.kind == "技能" and _card.value > 0:
		st = GameI18n.ui("map", "CARD_DETAIL_SKILL_DAMAGE", "造成 %d 点伤害") % _card.value
	if st != "":
		draw_string(_font, Vector2(x, y), st,
				HORIZONTAL_ALIGNMENT_LEFT, w,
				UiTheme.fit_font_size(_font, st, w, 34.0, UiTheme.FS_LABEL, 10),
				UiTheme.INK_800)
		y += 34.0
	# 本局永久成长（有成长才占位）
	var gt := CardFace.growth_text(_card)
	if gt != "":
		draw_rect(Rect2(x, y - 18.0, w, 50.0), Color(0.14, 0.42, 0.22, 0.12), true)
		draw_rect(Rect2(x, y - 18.0, 3.0, 50.0), Color(0.13, 0.42, 0.24), true)
		var gt_line := GameI18n.ui("map", "CARD_DETAIL_GROWTH", "本局永久成长　%s") % gt
		draw_string(_font_bold, Vector2(x + 12.0, y + 4.0), gt_line,
				HORIZONTAL_ALIGNMENT_LEFT, w - 20.0,
				UiTheme.fit_font_size(_font_bold, gt_line, w - 20.0, 22.0,
						UiTheme.FS_LABEL, 10), Color(0.13, 0.42, 0.24))
		draw_string(_font, Vector2(x + 12.0, y + 26.0),
				GameI18n.ui("map", "CARD_DETAIL_GROWTH_NOTE", "跨战斗保留 · 随存档走 · 新开一局才清空"),
				HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, UiTheme.FS_CAPTION, UiTheme.INK_500)
		y += 56.0
	else:
		y += 6.0
	# 效果文全文（不截断到 3 行 —— 这个页面就是来看全文的）
	# R602：仍然「能全文就全文」，但先按可用高度**折行 + 缩字号**（16→10），
	# 长了就降字号而不是把后半句直接砍掉。
	# R702：成长卡的正文要写**当前**伤害（猎杀 22 → 30），与上面数值行同一口径。
	var eff := CardText.naturalize_card(_card)
	if eff != "":
		var avail_h := t.end.y - y
		# R631：缩字号下限 10 → 9，并按「末行墨迹底」判（与卡面同一套口径）。
		var fit := CardFace.fit_text_lines(_font, eff, w, avail_h, UiTheme.FS_BODY, 9, 99, true)
		var fs := int(fit["fs"])
		var line_h := float(fit["line_h"]) + 2.0
		var lines: Array = fit["lines"]
		for li in lines.size():
			# R631：以前是 `maxi(1, int(avail_h / line_h))` —— **强制至少画一行**，
			# 可用高度不够时那一行就压到面板下边框上（用户口径「描述超过了格子」）。
			# 现在逐行确认字脚还在框内，放不下就停。
			if y + fs + 4.0 > t.end.y:
				break
			# width 传 -1：`draw_string` 的 width 会把超出部分裁掉，贴边的字会凭空消失。
			draw_string(_font, Vector2(x, y + fs * 0.9), lines[li],
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.INK_800)
			y += line_h
	# 调用方补充说明
	if _note != "":
		y = maxf(y, t.end.y - 30.0)
		draw_string(_font, Vector2(x, y + 12.0), _note,
				HORIZONTAL_ALIGNMENT_LEFT, w,
				UiTheme.fit_font_size(_font, _note, w, 24.0, UiTheme.FS_CAPTION, 9),
				UiTheme.INK_600)
	# 底部：关闭提示（面板下沿内侧居右）
	var pr: Rect2 = L["panel"]
	# 右边界内缩 56：面板九宫格右下角饰占 34，右对齐到 -26 会把「ESC 关闭」压在角饰上。
	# R630：基线原来取 `pr.end.y - 14`，而九宫格边框本身约 12px 厚 —— FS_CAPTION 的
	# 字底（基线 +3~4）正好落在框线上，整行被横切（用户口径「文本压框」）。收到 -22。
	draw_string(_font, Vector2(pr.position.x, pr.end.y - 22.0),
			GameI18n.ui("map", "CARD_DETAIL_CLOSE_HINT", "点任意处 / 右键 / ESC 关闭"), HORIZONTAL_ALIGNMENT_RIGHT,
			pr.size.x - 56.0, UiTheme.FS_CAPTION, UiTheme.INK_500)


# ── 输入 ─────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if _card == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT
				or mb.button_index == MOUSE_BUTTON_RIGHT):
			_close_soft()
			accept_event()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_close_soft()
			accept_event()
		return


func _unhandled_key_input(event: InputEvent) -> void:
	if _card == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_ESCAPE:
			_close_soft()
		get_viewport().set_input_as_handled()


func _close_soft() -> void:
	## ⚠️ 帧末再 hide：在派发这次输入的同一回调里隐藏自己，会让鼠标 over 悬空（R562）。
	if _closing:
		return
	_closing = true
	close.call_deferred()
