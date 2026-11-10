class_name AssembleOverlay
extends Control
## R559 组合 UI：使用「传授」等组合效果后弹出的全屏拖拽组合页。
##
## 三栏（左→右，比例定位、宽屏自适应）：
##   左栏：6 张待选卡（2×3），拖拽源 —— 已放进槽位的卡在这里**消失**（留淡空位），
##        拖回原位 / 任意左栏位置即可撤回
##   中栏：3 个空槽位（上中下：①属性值+卡图 ②上半效果 ③下半效果），槽内卡右上角有 ✕ 可一键撤回
##   右栏：结果预览 = 组合卡（带「组合」印记）+ 上/下效果框 + 确认按钮
##
## 交互：按住待选卡（或槽内卡）→ 拖到槽位 → 松手填入；拖动可在槽位间移动/互换；
##       点任意卡（待选 / 槽内 / 结果预览）→ 打开卡牌详情。三个槽位填满后「确认组合」可点。
## 组合逻辑全部交给引擎（engine.assemble_combo_*），本页只负责显示与拖拽。
##
## ⚠️ R559b 视觉重做（用户口径「文字和框体搭配非常差，美术素材基本没上」）：
##   第一版用 draw_rect 硬画纯色框 + 从概念图自切三张素材（assemble_seal / slot_card /
##   slot_effect），风格与游戏不符。重做后**全部接回游戏现有素材体系**：
##     · 空槽位 = `card_paper` 纸底 + `ACCENT_GOLD` 描边（与真卡同源纸底，天然协调）；
##     · 待选卡 / 结果卡 = `CardFace.draw_pick` 真卡；
##     · 上/下效果框 = `UiTheme.adventure_panel_style`（panel_journal_light 羊皮纸面板）；
##     · 按钮 = `UiTheme.draw_secondary_btn`（button_forest / button_paper 素材）；
##     · 「组合」印记 = `CardInfoBoxes.draw_glyph` 的 combine 自绘符号 + 金字，不贴图。
##
## ⚠️ R564（用户口径「放进去的卡拿不下来 / 左边还留着同一张 / 看不了详情」）：
##   ① 槽位可撤回：拖回左栏，或点槽内卡右上角的 ✕；
##   ② 已进槽的卡在左栏**不再画卡**，只留一个淡空位（位置不跳动，方便拖回）；
##   ③ 点任意卡打开 `CardDetailOverlay`（选卡页的卡面只留卡名，看不到效果文）。
##
## ⚠️ R571（用户口径「去掉取消组合按钮。使用了效果，必须组合。」）：
##   **唯一出口 = 「确认组合」**。传授卡打出去的时候代价已经付了（费用/出牌数），
##   中途放弃＝白扔一张卡还留着 pending，玩家只会当成卡死；所以这里不给退路。
##   不退路就必须保证**每条路都走得到确认**，两件事一起做：
##     ① 填槽前先问「这张卡能不能当这个槽」（`_slot_accepts` → AssembleRules.valid_upper/
##        valid_lower，与引擎/build 同源，不另写一份判据）；放不进就提示、不落槽；
##     ② 确认按钮的可用判据从「三槽填满」收紧成「填满 **且** build 得出产物」。
##   否则一张没有下半效果的卡塞进③，三槽看着是满的、产物却永远是 null → 真卡死。

signal confirmed()

const UiTheme = preload("res://scripts/ui_theme.gd")
const CardFace = preload("res://scripts/card_face.gd")
const UiAssets = preload("res://scripts/ui_assets.gd")
const AssembleRules = preload("res://scripts/assemble_rules.gd")
const CardInfoBoxes = preload("res://scripts/card_info_boxes.gd")
const CardDetailOverlay = preload("res://scripts/card_detail_overlay.gd")

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
const SLOT_CLOSE_R := 13.0              # 槽内卡右上角 ✕ 角标半径

var _font: Font
var _font_bold: Font
var _engine: Object = null
var _cards: Array = []
var _slot_attr := -1
var _slot_upper := -1
var _slot_lower := -1
var _drag_from := -1                      # 拖拽源：左栏待选卡下标
var _drag_slot := -1                      # 拖拽源：槽位（把已经放进去的卡再拿起来）
var _drag_pos := Vector2.ZERO
var _press := {}                          # {pos, moved}
var _tip := ""                            # R562：一句提示（右键/ESC 都不退页，R571 起连取消按钮也没了）
var _tip_until := 0
var _detail: CardDetailOverlay = null     # R564：卡牌详情浮层


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
	# R564：详情浮层作为子节点（z 叠加 → 永远压在本页之上）
	_detail = CardDetailOverlay.new()
	_detail.name = "CardDetail"
	add_child(_detail)


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
	_drag_slot = -1
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
	_drag_slot = -1
	_tip = ""
	_tip_until = 0
	if _detail != null:
		_detail.close()


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


func _left_zone() -> Rect2:
	## 「拖回左栏 = 撤回」的判定区（比卡片区域宽一圈，好拖）
	return Rect2(0.0, TITLE_H, size.x * (LEFT_X + LEFT_W) + size.x * 0.02,
			size.y - TITLE_H)


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


func _slot_close_rect(sr: Rect2) -> Rect2:
	## 槽内卡右上角的 ✕ 角标（探出卡框，别遮住卡面）：
	## 点它 = 把这张卡撤回左栏，不必再拖一次。
	var c := Vector2(sr.end.x - 4.0, sr.position.y + 4.0)
	return Rect2(c.x - SLOT_CLOSE_R, c.y - SLOT_CLOSE_R, SLOT_CLOSE_R * 2.0, SLOT_CLOSE_R * 2.0)


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
	# R570b：96 → 112。羊皮纸九宫格的上下花纹各占 16px，96 高时**纸面只有 64px**，
	# 而正文区是从 y+46 开始的（标题占掉上面一段）→ 实际可用不到 34px，
	# 夜蚀那种三行长句必然把最后一行压到框线上（出图实测：纸面 465~529，第三行墨迹顶到 529）。
	# 加高 16 并把两框间距 12 → 8，总高不变（仍是 2×112+8 = 232）。
	# R571：原来这下面还有一颗「取消组合」按钮，删掉后两框底边离「确认组合」约 83px，更宽松。
	var h := 112.0
	var sr := _seal_rect()
	var y := sr.end.y + 22.0 + i * (h + 8.0)
	return Rect2(cx - w / 2.0, y, w, h)


func _confirm_rect() -> Rect2:
	## R571：原来这里上下叠着「取消组合」+「确认组合」两颗；取消删掉后确认留在底部居中，
	## 高度不变（48 > 44，才走 adventure_button_style 素材胶囊，不走纯色 chip）。
	var cx := size.x * RIGHT_CX
	return Rect2(cx - 110.0, size.y - 64.0, 220.0, BUTTON_H)


func _all_filled() -> bool:
	return _slot_attr >= 0 and _slot_upper >= 0 and _slot_lower >= 0


func _preview_card() -> CardData:
	## R571：产物能不能真的 build 出来 —— 确认按钮的可用判据就是它。
	## 去掉「取消组合」之后，「填满但 build 失败」＝没有出口的死局，必须提前判掉。
	if not _all_filled() or _engine == null:
		return null
	return _engine.assemble_combo_preview() as CardData


func _slot_accepts(slot: int, idx: int) -> bool:
	## R571：这张卡能不能当这个槽。判据与引擎 `assemble_combo_set_slot` / build 判废**同源**。
	## ①属性：任何卡都行（它就是产物本体）；②上半：要合法扳机；③下半：要能不带扳机地兑现。
	if idx < 0 or idx >= _cards.size():
		return false
	if slot == 0:
		return true
	var c: CardData = _cards[idx]
	if slot == 1:
		return AssembleRules.valid_upper(c.upper_effect)
	return AssembleRules.valid_lower(c.lower_effect)


func _slot_reject_tip(slot: int, idx: int) -> String:
	## 放不进时说的话：**告诉玩家换哪个槽**，别只丢一句「不行」。
	var c: CardData = _cards[idx] if idx >= 0 and idx < _cards.size() else null
	var name := c.card_name if c != null else "这张卡"
	if slot == 1:
		return "「%s」没有可用的上半钩子 —— 试试拖进③下半" % name
	return "「%s」没有可用的下半效果 —— 试试拖进②上半" % name


func _slot_index(slot: int) -> int:
	match slot:
		0: return _slot_attr
		1: return _slot_upper
		2: return _slot_lower
	return -1


func _slot_of_index(idx: int) -> int:
	## 这张待选卡现在在哪个槽里（-1 = 不在任何槽）。R564：同一张卡只能占一个槽。
	if idx < 0:
		return -1
	if idx == _slot_attr:
		return 0
	if idx == _slot_upper:
		return 1
	if idx == _slot_lower:
		return 2
	return -1


func _slot_at(pos: Vector2) -> int:
	for slot in 3:
		if _slot_rect(slot).has_point(pos):
			return slot
	return -1


func _drag_index() -> int:
	## 当前拖着的卡在 `_cards` 里的下标（源可能是左栏，也可能是槽位）。
	if _drag_slot >= 0:
		return _slot_index(_drag_slot)
	return _drag_from


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
	draw_string(_font, Vector2(size.x * LEFT_X, TITLE_H + 26.0 + 18.0),
			"拖进中栏 · 拖回可撤回 · 点卡看详情",
			HORIZONTAL_ALIGNMENT_LEFT, size.x * LEFT_W, UiTheme.FS_CAPTION, UiTheme.INK_ON_DARK)
	var dragging := _drag_from >= 0 or _drag_slot >= 0
	for k in _cards.size():
		var r := _card_rect(k)
		if k == _drag_index():
			continue   # 被拖的卡在手指下方单独画
		# R564：已经放进槽位的卡，左栏这里**不再画卡**，只留一个淡空位（位置固定不跳动）
		if _slot_of_index(k) >= 0:
			_draw_left_gap(r)
			continue
		CardFace.draw_pick(self, _cards[k], r, _font, _font_bold, false)
	# 拖动中：把左栏整块圈一下，表示「松手就是撤回」
	if dragging and _left_zone().has_point(_drag_pos) and _drag_slot >= 0:
		draw_rect(_left_zone().grow(-4.0), Color(0.42, 0.72, 0.46, 0.85), false, 2.0)
	# 中栏：3 个空槽位
	# ⚠️ R562：`HORIZONTAL_ALIGNMENT_CENTER` 的第二个参数是**矩形左边界**，不是中心点。
	# 原来这里传 `size.x * MID_CX`（中心）+ 宽 0.2w → 文字整体右移半格，标题压在右栏边上。
	draw_string(_font_bold, Vector2(size.x * MID_CX - size.x * 0.1, TITLE_H + 26.0), "拖入槽位",
			HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.2, UiTheme.FS_LABEL, UiTheme.ACCENT_LIT)
	for slot in 3:
		var sr := _slot_rect(slot)
		var idx := -1 if slot == _drag_slot else _slot_index(slot)
		_draw_slot(sr, slot, idx)
		# R562：拖动中把「松手会落进去的那个槽」圈出来 —— 之前完全没有落点反馈。
		if dragging and sr.has_point(_drag_pos):
			draw_rect(sr.grow(2.0), UiTheme.ACCENT_LIT, false, 3.0)
	# 右栏：结果预览
	_draw_preview()
	# 拖拽中的卡（画在最上层）
	var di := _drag_index()
	if dragging and di >= 0 and di < _cards.size():
		var dr := Rect2(_drag_pos - Vector2(_slot_w() * 0.4, _slot_w() * 0.4 * CARD_ASPECT),
				Vector2(_slot_w() * 0.8, _slot_w() * 0.8 * CARD_ASPECT))
		CardFace.draw_pick(self, _cards[di], dr, _font, _font_bold, false)


func _draw_left_gap(r: Rect2) -> void:
	## R564：已放进槽位的卡，在左栏原位留一个淡空位 ——
	## 不画卡（用户口径「放进去左边就该没有这张」），但格子位置固定，
	## 拖回这里 / 点 ✕ 都能把卡收回来。
	var gold := Color(UiTheme.ACCENT_GOLD.r, UiTheme.ACCENT_GOLD.g,
			UiTheme.ACCENT_GOLD.b, 0.42)
	draw_rect(r, Color(UiTheme.ACCENT_GOLD.r, UiTheme.ACCENT_GOLD.g,
			UiTheme.ACCENT_GOLD.b, 0.06), true)
	draw_rect(r, gold, false, 1.0)
	draw_string(_font, Vector2(r.position.x, r.get_center().y + 4.0), "已放入",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_CAPTION,
			Color(UiTheme.ACCENT_GOLD.r, UiTheme.ACCENT_GOLD.g, UiTheme.ACCENT_GOLD.b, 0.75))


func _draw_slot(sr: Rect2, slot: int, idx: int) -> void:
	## 槽位：空态 = card_paper 纸底 + 金边 + 序号徽章（不写任何效果文本）；填态 = 真卡 + ✕ 角标。
	## R559c：效果文字只出现在右侧文本框；中栏槽位（①属性 ②上半 ③下半）填了就是一张卡。
	if idx >= 0:
		CardFace.draw_pick(self, _cards[idx], sr, _font, _font_bold, false)
		if slot != _drag_slot:
			_draw_slot_close(sr)
		return
	_draw_slot_paper(sr)
	_draw_slot_index(sr, slot)


func _draw_slot_close(sr: Rect2) -> void:
	## R564：槽内卡右上角的 ✕ —— 一键把卡撤回左栏（比拖一次省事，尤其手机）。
	var cr := _slot_close_rect(sr)
	var c := cr.get_center()
	draw_circle(c, SLOT_CLOSE_R, Color(0.10, 0.08, 0.06, 0.92))
	draw_circle(c, SLOT_CLOSE_R, UiTheme.ACCENT_GOLD, false, 1.5)
	var d := SLOT_CLOSE_R * 0.42
	draw_line(c + Vector2(-d, -d), c + Vector2(d, d), UiTheme.ACCENT_LIT, 1.8)
	draw_line(c + Vector2(d, -d), c + Vector2(-d, d), UiTheme.ACCENT_LIT, 1.8)


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
	var result: CardData = _preview_card()
	if result == null:
		# 还没拖满（或填满了但 build 不出来 —— R571 起填槽已经拦掉这种情况）：
		# 空预览卡框 + 提示。判据与确认按钮同一个口，避免「按钮亮了、卡面空着」。
		_draw_slot_paper(pr)
		draw_string(_font, Vector2(pr.position.x, pr.position.y + pr.size.y * 0.46), "拖满 3 个槽位",
				HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
		draw_string(_font, Vector2(pr.position.x, pr.position.y + pr.size.y * 0.46 + 20.0), "后显示组合卡",
				HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
	else:
		CardFace.draw_pick(self, result, pr, _font, _font_bold, false)
	# 产物印记说明条（结果卡下方）：combine 自绘符号 + 金字，指的就是卡面费用正下方那枚
	var sr := _seal_rect()
	draw_rect(sr, Color(0.12, 0.10, 0.06, 0.95))
	draw_rect(sr, UiTheme.ACCENT_GOLD, false, 1.5)
	CardInfoBoxes.draw_glyph(self, Vector2(sr.position.x + 18.0, sr.get_center().y), 10.0, "combine", UiTheme.ACCENT_LIT)
	draw_string(_font_bold, Vector2(sr.position.x + 34.0, sr.get_center().y + UiTheme.FS_CAPTION * 0.35),
			"组合产物 · 卡面金印为记", HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 40.0,
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
				# R567：下半**永远只写效果**，一个扳机字都不带（用户口径「下半不应该是完整效果，
				# 需要裁掉上半部分 —— 扳机是在上半的，不应该也分发到下半」）。
				# 上半槽空着 / 跨时机也一样不补 —— 补了就会重新变成整句，而且产物卡面写 A 时机、
				# 实际按 B 时机结算。`note`（黑暗领主「在本回合结束时」）是描述前缀，不是扳机。
				txt = AssembleRules.body_text(lo.lower_effect)
		if txt != "":
			# R562：左右内边距对称（原来左 36 / 右 12），别让文字贴死在包角上。
			# R569：底部留白 10 → 6 —— 火元素那种 45 字的长效果在 9px 下要 3 行（39px），
			# 原来的 36px 差 3px 就被截成「对随…」；缩字号已经能把字塞进框，
			# 不该再因为差这几像素把半句话吃掉。
			# R570b：正文收进**纸面**内。纸面 = y+16 .. y+96（九宫格花纹各 16px），
			# 所以正文从 y+44 起、高 52 → 底边正好落在纸面下沿，不再压到框线。
			var body := Rect2(er.position.x + 40.0, er.position.y + 44.0,
					er.size.x - 80.0, er.size.y - 60.0)
			_draw_wrapped(body, txt, UiTheme.FS_CAPTION, UiTheme.INK_800)
	if _tip != "":
		# R562：底部一句提示（右键/ESC/撤回/落点为空时的说明），自带暗底 + 金边。
		# R564：位置改到**顶栏右侧空白区**（见下方坐标注释），原来放在底部按钮上方，
		# 正好压在战斗的「我方生命」条上，看着像把血条盖掉了。
		var fs := UiTheme.FS_CAPTION
		var tw: float = _font.get_string_size(_tip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# 落在**顶栏右侧的空白区**：顶栏下方是三栏标题行（y≈TITLE_H+26），
		# 提示条压在那儿会把「拖入槽位」盖住。
		var bx: float = size.x - 26.0 - tw - 12.0
		var ty := TITLE_H * 0.5 + fs * 0.35
		var br := Rect2(bx, TITLE_H * 0.5 - fs * 0.75, tw + 24.0, fs + 11.0)
		draw_rect(br, Color(0.08, 0.07, 0.05, 0.94))
		draw_rect(br, UiTheme.ACCENT_GOLD, false, 1.0)
		draw_string(_font, Vector2(bx + 12.0, ty), _tip, HORIZONTAL_ALIGNMENT_LEFT, tw,
				fs, UiTheme.ACCENT_LIT)
	# 确认按钮（button_forest 素材）—— R571：这里是组合页的**唯一出口**，没有取消。
	# 可用判据不是「三槽填满」，而是「填满且产物真的 build 得出来」（见 `_preview_card`）。
	var ok := _confirm_rect()
	var can := _preview_card() != null
	UiTheme.draw_secondary_btn(self, ok, "确认组合", false, not can, true)


func _draw_wrapped(rect: Rect2, text: String, fs: int, col: Color) -> void:
	## R569：**超框缩字号**（用户口径「文字应该增加自适应大小，超框需要缩小」）。
	## 原来固定 `FS_CAPTION` + 行距 `fs+3` 硬塞 4 行 —— 犀牛「受到伤害减少 1 点，
	## 但至少仍要受到 1 点。回合结束时」正好折成 3 行，最后一行基线顶出框底。
	## 现在交给 `CardFace.fit_text_lines` 逐级降字号，仍放不下才截断补「…」。
	var fit := CardFace.fit_text_lines(_font, text, rect.size.x, rect.size.y, fs, 8)
	var lines: Array = fit["lines"]
	var lh: float = float(fit["line_h"])
	var fsz: int = int(fit["fs"])
	var asc: float = float(_font.get_ascent(fsz))
	var desc: float = float(_font.get_descent(fsz))
	# 能画几行要按**真实墨迹**算：首行基线在 `rect.y + asc`，最后一行底在「基线 + desc」。
	# 只按 `rect.size.y / lh` 取整会在字体的 ascent 偏大时把最后一行压到框线上（出图实测）。
	var cap: int = maxi(1, int(floor((rect.size.y - asc - desc) / lh)) + 1)
	var n: int = mini(lines.size(), cap)
	for li in n:
		var t: String = str(lines[li])
		if li == n - 1 and lines.size() > n:
			t = CardFace._ellipsize(_font, t + "…", rect.size.x, fsz)
		draw_string(_font, Vector2(rect.position.x, rect.position.y + asc + lh * li), t,
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, fsz, col)


# ── 输入 ─────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if _cards.is_empty():
		return
	# R564：详情页打开时，本页一概不处理（所有点击都属于「关掉详情」）
	if _detail != null and _detail.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = {"pos": mb.position, "moved": false}
				_begin_drag(mb.position)
				queue_redraw()
			else:
				var moved: bool = _press.get("moved", true)
				_press = {}
				if _drag_slot >= 0 or _drag_from >= 0:
					if moved:
						_drop_at(mb.position)
					else:
						_tap(mb.position)
				elif not moved:
					_tap(mb.position)
				_drag_from = -1
				_drag_slot = -1
				queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# R562：⛔ 原来这里直接发取消信号 —— 界面当场隐藏，而这张传授卡
			# 已经打出去了，组合机会白丢；更要命的是在 `_gui_input` 里把自己 hide 掉，
			# 鼠标的 over 状态留在了一个已隐藏的控件上，之后所有点击都落空（表现为卡死）。
			# R571：连「取消组合」也删了 —— 右键只提示「必须完成」，不留任何放弃口。
			_show_tip("组合一旦开始就必须完成 —— 把 3 个槽位拖满，再点「确认组合」")
			accept_event()
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_from >= 0 or _drag_slot >= 0:
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
			_begin_drag(st.position)
			queue_redraw()
		else:
			var moved2: bool = _press.get("moved", true)
			_press = {}
			if _drag_slot >= 0 or _drag_from >= 0:
				if moved2:
					_drop_at(st.position)
				else:
					_tap(st.position)
			elif not moved2:
				_tap(st.position)
			_drag_from = -1
			_drag_slot = -1
			queue_redraw()
		accept_event()
		return
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _drag_from >= 0 or _drag_slot >= 0:
			if (sd.position - (_press.get("pos", sd.position) as Vector2)).length() > 6.0:
				_press["moved"] = true
			_drag_pos = sd.position
			queue_redraw()
			accept_event()
			return


func _unhandled_key_input(event: InputEvent) -> void:
	if _cards.is_empty() or not visible:
		return
	if _detail != null and _detail.visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_ESCAPE:
			# R571：ESC 同样是「只提示不退出」—— 组合页没有放弃口。
			_show_tip("组合一旦开始就必须完成 —— 把 3 个槽位拖满，再点「确认组合」")
		get_viewport().set_input_as_handled()


func _begin_drag(pos: Vector2) -> void:
	## R564：拖拽源有两处 —— 左栏待选卡、以及**已经放进槽位的卡**（从左栏空位或槽内都能再拿起来）。
	_drag_from = _card_at(pos)
	_drag_slot = -1
	_drag_pos = pos
	if _drag_from >= 0:
		var s := _slot_of_index(_drag_from)
		if s >= 0:
			# 点在「已放入」的空位上 → 等于把槽里那张卡拿起来
			_drag_slot = s
			_drag_from = -1
	if _drag_from < 0 and _drag_slot < 0:
		var s2 := _slot_at(pos)
		# ✕ 角标区域不算拖拽（留给点按撤回）
		if s2 >= 0 and _slot_index(s2) >= 0 \
				and not _slot_close_rect(_slot_rect(s2)).has_point(pos):
			_drag_slot = s2


func _card_at(pos: Vector2) -> int:
	for k in _cards.size():
		if _card_rect(k).has_point(pos):
			return k
	return -1


func _drop_at(pos: Vector2) -> void:
	## 松手：落在槽位 → 填入 / 移动 / 互换；从槽位拖回左栏 → 撤回。
	var target := _slot_at(pos)
	if _drag_slot >= 0:
		if target == _drag_slot:
			return
		if target >= 0:
			# 槽位之间移动 / 互换（目标空 = 移动，目标有卡 = 互换）
			var a := _slot_index(_drag_slot)
			var b := _slot_index(target)
			_set_slot(_drag_slot, -1)
			_set_slot(target, -1)
			_set_slot(_drag_slot, b)
			_set_slot(target, a)
			if b >= 0:
				_show_tip("两个槽位的卡已互换")
		elif _left_zone().has_point(pos):
			_set_slot(_drag_slot, -1)
			_show_tip("已撤回，卡回到左栏待选")
		else:
			_show_tip("拖回左栏可以撤回这张卡")
		queue_redraw()
		return
	# 从左栏拖出
	if target >= 0:
		fill_slot(target, _drag_from)
		return
	if _left_zone().has_point(pos):
		return   # 拖来拖去还在左栏 = 没动
	# R562：落在槽位外面 → 说一句，别让玩家以为「拖了但没反应」。
	_show_tip("拖到中栏三个槽位里才能放：①属性 ②上半 ③下半")


func fill_slot(slot: int, idx: int) -> void:
	## 填槽唯一口（拖拽落点 / 演示预填共用）。
	## R564：idx < 0 = 清空该槽；同一张卡不会同时占两个槽（填进新槽会自动清掉旧槽）。
	## R571：idx >= 0 时先过 `_slot_accepts` —— 放不进这个槽就别落，提示玩家换槽。
	## 召回（idx < 0）永远放行，否则连撤回都会被拦住。
	if idx >= 0 and not _slot_accepts(slot, idx):
		_show_tip(_slot_reject_tip(slot, idx))
		return
	if idx >= 0:
		for s in 3:
			if s != slot and _slot_index(s) == idx:
				_set_slot(s, -1)
	_set_slot(slot, idx)
	queue_redraw()


func _set_slot(slot: int, idx: int) -> void:
	## 只改数据 + 同步引擎（不重绘）—— fill_slot / 撤回 / 互换都走这里。
	var key := "attr"
	match slot:
		0:
			_slot_attr = idx
			key = "attr"
		1:
			_slot_upper = idx
			key = "upper"
		2:
			_slot_lower = idx
			key = "lower"
	if _engine != null:
		_engine.assemble_combo_set_slot(key, idx)


func _tap(pos: Vector2) -> void:
	## 点按（未拖动）：✕ 撤回 → 确认 → 槽内卡详情 → 待选卡详情 → 结果预览详情。
	## R571：取消分支整段删除（按钮和 `cancelled` 信号一起没了）。
	for s in 3:
		if _slot_index(s) >= 0 and _slot_close_rect(_slot_rect(s)).has_point(pos):
			_set_slot(s, -1)
			_show_tip("已撤回，卡回到左栏待选")
			queue_redraw()
			return
	if _confirm_rect().has_point(pos):
		# R571：按得下的确认必须真的能成 —— 判据与按钮绘制同一口（`_preview_card`），
		# 否则会出现「按钮是亮的、按下去什么都没发生」的观感。
		if _preview_card() != null:
			confirmed.emit()
		return
	var s2 := _slot_at(pos)
	if s2 >= 0 and _slot_index(s2) >= 0:
		_open_detail_index(_slot_index(s2), "")
		return
	var k := _card_at(pos)
	if k >= 0:
		_open_detail_index(k, "已放入槽位" if _slot_of_index(k) >= 0 else "")
		return
	# 结果预览卡（填满三槽且 build 得出产物后才有真卡可看）
	if _preview_rect().has_point(pos):
		var res: CardData = _preview_card()
		if res != null:
			_open_detail_card(res, "组合结果预览 —— 按「确认组合」后才会真正生成")


func _open_detail_index(idx: int, note: String) -> void:
	if idx < 0 or idx >= _cards.size() or _detail == null:
		return
	_open_detail_card(_cards[idx], note)


func _open_detail_card(card: CardData, note: String) -> void:
	if card == null or _detail == null:
		return
	_detail.open(card, note)
	queue_redraw()
