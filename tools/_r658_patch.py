# -*- coding: utf-8 -*-
"""R658：把「可发动」从右上角槽位队列里摘出来，改成卡框上沿正中的动态邀请图标。"""
import io, sys

P = 'scripts/battle_scene.gd'

def C(s):
    return s.encode('utf-8').replace(b'\n', b'\r\n')

b = open(P, 'rb').read()
orig = b

def rep(old, new, tag):
    global b
    o, n = C(old), C(new)
    c = b.count(o)
    assert c == 1, '[%s] 锚点命中 %d 次' % (tag, c)
    b = b.replace(o, n)

# ---------- (A) 常量 ----------
rep(
"""const COL_READY := Color(0.50, 0.90, 1.0)      ## R165「可行动」就绪光环（亮青，区别于黄绿「可发动」）""",
"""const COL_READY := Color(0.50, 0.90, 1.0)      ## R165「可行动」就绪光环（亮青，区别于黄绿「可发动」）
## R658：「可发动」邀请图标从卡框上沿正中「长大到卡心」的过渡时长（选中那一下的弹入）
const ACT_CALLOUT_POP_MS := 240""",
"const")

# ---------- (B) 成员变量 ----------
rep(
"""# 动画状态（tkinter 版做不到的部分）：
var _slides := {}               # Placement -> {from,to: 像素中心, start, dur[, pts]} 上场/移动""",
"""# R658：「可发动」邀请图标选中后「放大到卡心」的弹入起点（记这次选中的格子与时刻）
var _act_sel_cell := Vector2i(-1, -1)
var _act_sel_ms := 0

# 动画状态（tkinter 版做不到的部分）：
var _slides := {}               # Placement -> {from,to: 像素中心, start, dur[, pts]} 上场/移动""",
"vars")

# ---------- (C) _state_slots：注释 + 删掉 activate ----------
rep(
"""	## 顺序 = 紧急度：不能行动的三种（冰封 / 眩晕 / 沉睡）→ 倒计时 → 可操作提示 → 临时嘲讽。""",
"""	## 顺序 = 紧急度：不能行动的三种（冰封 / 眩晕 / 沉睡）→ 倒计时 → 临时嘲讽。
	## ⚠️ R658（店长口径）：「可发动」**不进这条队列**。槽位回答的是「它身上有什么」，
	##    可发动回答的是「你现在能按它」—— 一个是状态、一个是邀请，混进同一条轮播
	##    要等 1.8 秒才轮到，等于没提示。它改由 `_draw_activate_callout()` 单独画在
	##    卡框上沿正中，并且是**动态**的：选中后放大到卡心。""",
"slots-doc")

rep(
"""	if p.fuse_left > 0:
		out.append({"glyph": "fuse", "label": "铸造", "count": p.fuse_left})
	if p.owner == GameEngine.SIDE_SELF and engine.can_activate(cell, GameEngine.SIDE_SELF):
		out.append({"glyph": "activate", "label": "可发动"})
	if engine.unit_has_taunt(p) and not p.card.has_affix("嘲讽"):""",
"""	if p.fuse_left > 0:
		out.append({"glyph": "fuse", "label": "铸造", "count": p.fuse_left})
	if engine.unit_has_taunt(p) and not p.card.has_affix("嘲讽"):""",
"slots-activate")

# ---------- (D) _draw_board_unit 注释 + 调用 ----------
rep(
"""	# R142：**可以主动发动**的我方单位（熊 8004「回春」）—— 原来的提示只有
	# 「选中它之后状态栏写一句」，没选中就等于看不见。这里加一层**常驻**的
	# 亮黄绿脉动环 + 四向指向卡面的内箭头（R656 起文字徽标取缔，图标进卡面圆槽）。
	# ⚠️ 判据走引擎的 `can_activate`（与「再点一次」/ 按 F 完全同源），不在这里重判 traits；
	#    **只标我方**：敌人也可能能发动，但玩家点不动它，标成「按 F」是误导。
	if p.owner == GameEngine.SIDE_SELF and engine.can_activate(cell, GameEngine.SIDE_SELF):
		_draw_activatable_aura(center, w, h)""",
"""	# R142：**可以主动发动**的我方单位（熊 8004「回春」）—— 原来的提示只有
	# 「选中它之后状态栏写一句」，没选中就等于看不见。这里加一层**常驻**的
	# 亮黄绿脉动环 + 四向指向卡面的内箭头（R656 起文字徽标取缔）。
	# R658（店长口径）：图标**不跟状态标志挤一个槽位**，也不做静态 —— 单独走
	# `_draw_activate_callout()`：卡框上沿正中会呼吸，选中后放大到卡心。
	# ⚠️ 判据走引擎的 `can_activate`（与「再点一次」/ 按 F 完全同源），不在这里重判 traits；
	#    **只标我方**：敌人也可能能发动，但玩家点不动它，标成「按 F」是误导。
	if p.owner == GameEngine.SIDE_SELF and engine.can_activate(cell, GameEngine.SIDE_SELF):
		_draw_activatable_aura(center, w, h)
		_draw_activate_callout(center, w, h, selected, cell)""",
"unit-call")

# ---------- (E) _draw_activatable_aura 注释 ----------
rep(
"""	## R656：文字徽标取缔（「可发动 F」改成「键帽 + 上箭头」图标进卡面圆槽，真键位走悬停说明）。""",
"""	## R656：文字徽标取缔（「可发动 F」→「键帽 + 上箭头」图标）。
	## R658：那个图标**不再进卡面圆槽**（槽位是「状态」，这是「邀请」），改由
	##       `_draw_activate_callout()` 画在卡框上沿正中 + 选中放大到卡心。这里只管环与箭头。""",
"aura-doc")

# ---------- (F) 新函数：插在 _draw_activate_aura 之后、_draw_ready_aura 之前 ----------
rep(
"""func _draw_ready_aura(center: Vector2, w: float, h: float) -> void:""",
"""func _draw_activate_callout(center: Vector2, w: float, h: float,
		selected: bool, cell: Vector2i) -> void:
	## **「可发动」的邀请图标**（R658，店长口径）—— 这个游戏里唯一一个「催你按」的标记。
	## 它与状态图标的区别不是画法，是**含义**：
	##   · 右上角槽位答「它身上有什么」（冰封 / 眩晕 / 沉睡 / 倒数 / 字段）；
	##   · 这里答「**你现在能按它**」—— 是邀请，不是状态，所以不排队、不轮播、常亮。
	## 位置（未选中）= 卡框上沿**正中**，与右上角标志**同一条水平线**：
	##   视线扫过卡顶时，左中右一条带子；标志在角上，邀请在中间，不会互相抢。
	## 动态（店长点名「不要静态图标」）：
	##   ① 呼吸缩放（0.94~1.06）+ 上下轻浮 1.6px，两个频率故意不成整数比；
	##   ② 两圈错相位的**向外扩散涟漪**，自带「哒、哒」的节拍；
	##   ③ 选中后 240ms ease-out **放大到卡心**（约 2.6 倍），涟漪加快加粗 ——
	##      这一刻它就是个可按的按钮，不是一枚装饰章。
	## ⚠️ 选中后钉在卡心、停止上下漂（漂着的东西不像能点准的按钮）。
	## ⚠️ 不做逐个 Placement 的动画状态：只记「这次选中的是哪一格 + 什么时候」，
	##    换格才重置 —— 否则每帧重绘都会把弹入进度打回 0。
	var t := float(_now()) / 1000.0
	if selected:
		if _act_sel_cell != cell:
			_act_sel_cell = cell
			_act_sel_ms = _now()
	else:
		_act_sel_cell = Vector2i(-1, -1)
	var prog := 0.0
	if selected:
		prog = clampf(float(_now() - _act_sel_ms) / float(ACT_CALLOUT_POP_MS), 0.0, 1.0)
		prog = 1.0 - pow(1.0 - prog, 3.0)          # ease-out cubic：起步快、落定稳
	# 起点 = 卡框上沿正中；终点 = 卡心。半径从「与右上角标志同尺寸」长到卡高的 0.30
	var r_idle := maxf(8.0, h * 0.115)
	var r_sel := h * 0.30
	var pos := Vector2(center.x, center.y - h * 0.5).lerp(center, prog)
	var speed := lerpf(3.0, 5.6, prog)            # 选中后呼吸更快 = 更催
	var breathe := 1.0 + sin(t * speed) * lerpf(0.06, 0.045, prog)
	var bob := sin(t * 1.9) * lerpf(1.6, 0.0, prog)
	var c := pos + Vector2(0.0, bob)
	var r := lerpf(r_idle, r_sel, prog) * breathe
	# ① 向外扩散的涟漪（两圈错开半个周期）—— 「在等你按」的节拍感
	var wave_period := lerpf(1.5, 0.9, prog)
	var wave_a := lerpf(0.30, 0.46, prog)
	for i in 2:
		var ph := fposmod(t / wave_period + float(i) * 0.5, 1.0)
		var wr: float = r * (1.04 + ph * lerpf(0.85, 1.10, prog))
		draw_arc(c, wr, 0.0, TAU, 40,
				Color(COL_ACTIVATABLE.r, COL_ACTIVATABLE.g, COL_ACTIVATABLE.b,
						(1.0 - ph) * wave_a), lerpf(1.8, 2.6, prog))
	# ② 圆底 + 亮描边（按钮质感：底色压深，符号才立得住）
	draw_circle(c, r, Color(0.05, 0.14, 0.03, lerpf(0.86, 0.93, prog)))
	draw_arc(c, r * 0.92, 0.0, TAU, 36,
			Color(COL_ACTIVATABLE.r, COL_ACTIVATABLE.g, COL_ACTIVATABLE.b,
					lerpf(0.70, 0.95, prog)), maxf(1.4, r * 0.15))
	# ③ 键帽 + 上箭头（复用状态 glyph，语义不变：「这是个能按的东西」）
	preload("res://scripts/card_info_boxes.gd").draw_glyph(
			self, c, r * 0.62, "activate", Color(0.96, 1.0, 0.82))


func _draw_ready_aura(center: Vector2, w: float, h: float) -> void:""",
"new-func")

# ---------- (G) 演示段：三只熊（已发动 / 可发动 / 可发动且选中） ----------
rep(
"""		# 演示（R142）：场上「可主动发动」的**常驻**提示。两只熊并排 ——
		# 左边那只**已经发动过**（横置 → 环与图标都消失），右边那只**现在能发动**
		# （亮黄绿脉动环 + 四向指向卡面的内箭头 + 右上角槽位里的「键帽」图标）。
		# ⚠️ 判据是引擎的 `can_activate()` —— 所以左边那只连图标都不该有。
		# ⚠️ R656：顶部「可发动 F」文字徽标已取缔，改走卡面右上角槽位（CardFace.badge_slots）。""",
"""		# 演示（R142 / R658）：场上「可主动发动」的三种样子，同一列自上而下 ——
		# ① 已经发动过（横置 → 卡面发灰，环与图标全消失）
		# ② 现在能发动、但**没选中**（黄绿环 + 四向内箭头 + 卡框上沿正中一颗会呼吸的图标）
		# ③ 能发动且**已选中**（同一颗图标放大到卡心 + 更快的涟漪 = 「按这里」）
		# ⚠️ 判据是引擎的 `can_activate()` —— 所以①连图标都不该有。
		# ⚠️ R658：「可发动」图标**不在**右上角槽位（那是状态的位置），改走 `_draw_activate_callout()`。""",
"demo-doc")

rep(
"""		var ab_right := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_SELF)
		ab_right.health = 9
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		status_text = "R656：左熊已发动（环与图标都消失）；右熊可发动（黄绿环 + 内箭头 + 键帽图标）\"""",
"""		var ab_right := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_SELF)
		ab_right.health = 9
		var ab_sel := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		ab_sel.health = 9
		selection = ["board", Vector2i(4, 1)]       # ③ 选中：图标放大到卡心
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		status_text = "R658：上=已发动（全消失）；中=可发动（呼吸图标在上沿正中）；下=选中（放大到卡心）\"""",
"demo-body")

# 清空的 selection = null 那行要挪到摆完卡之后再设，否则被覆盖
rep(
"""		_clear_hover_state()
		selection = null
		RunState.player_class = PlayerClass.DRUID   # 左栏「角色：」也跟着演示走
		engine.self_relics = [GameEngine.WILD_FORM_RELIC_ID]""",
"""		_clear_hover_state()
		RunState.player_class = PlayerClass.DRUID   # 左栏「角色：」也跟着演示走
		engine.self_relics = [GameEngine.WILD_FORM_RELIC_ID]""",
"demo-null")

open(P, 'wb').write(b)
crlf = b.count(b'\r\n')
print('CRLF=%d LF_only=%d  delta=%d' % (crlf, b.count(b'\n') - crlf, len(b) - len(orig)))
