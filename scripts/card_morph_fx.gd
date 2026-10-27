extends RefCounted
## R390 源数之力 ·「卡片变化」演出（纯自绘 RefCounted，**不加 class_name** —— 统一 preload）。
##
## 谁持有：`deck_edit_scene`（一个 `_fx_layer` 自绘 Control + `_process` 驱动）。
## 为什么不直接做成 Control：卡面必须走 `CardFace.draw_pick()`（它要 CanvasItem 与字体），
## 演出本身只负责「时间轴 + 画法」，什么时候画、画在哪由场景说了算
## —— 与 `speech_bubble.gd` 同一套思路，不新造一层节点树。
##
## 时间轴（总 `TOTAL_MS` = 1300ms）：
##   0   ~ 260    旧卡炸开：白色闪光衰减 + 8 片碎片向外飞散
##   120 ~ 520    光环：两圈金环从中心扩到 1.7 倍并淡出（第二圈错开 60ms）
##   260 ~ 980    新卡浮现：从 0.55 倍长到 1.0 倍（ease-out-back，轻微过冲）
##   980 ~ 1300   定格：下方一行「旧名 → 新名」淡入
##
## ⚠️ 旧卡由**场景**负责在这段时间里不画（`deck_edit_scene._fx_hide_index`）：
##    本演出只画新卡与特效，不负责遮盖 —— 两边各管一件事，颜色不会打架。

const PH_SHARD := 260.0        # 旧卡炸开段
const PH_RING := 520.0         # 光环段（结束）
const PH_CARD := 980.0         # 新卡长满的时刻
const TOTAL_MS := 1300

const GOLD := Color("ffd27d")
const GOLD_SOFT := Color("ffb84a")
const SHARD_N := 8

var _on := false
var _t0 := 0
var _from := Rect2()          # 旧卡在屏幕上的矩形
var _final := Rect2()         # 新卡定格矩形
var _old_name := ""
var _new_name := ""
var _new_card: CardData = null


func restart(from_rect: Rect2, final_rect: Rect2,
		old_card: CardData, new_card: CardData, now_ms: int) -> void:
	## 开演。`from_rect` = 被改造那张卡此刻的屏幕矩形（碎片/光环的锚点）；
	## `final_rect` = 新卡定格的位置（一般取屏幕中心偏上，由场景算）。
	_on = true
	_t0 = now_ms
	_from = from_rect
	_final = final_rect
	_new_card = new_card
	_old_name = old_card.card_name if old_card != null else ""
	_new_name = new_card.card_name if new_card != null else ""


func playing(now_ms: int) -> bool:
	return _on and (now_ms - _t0) < TOTAL_MS


func elapsed(now_ms: int) -> int:
	return 0 if not _on else now_ms - _t0


func stop() -> void:
	_on = false


func draw(cv: CanvasItem, now_ms: int, font: Font, font_bold: Font) -> void:
	if not _on:
		return
	var t := float(now_ms - _t0)
	var c := _from.get_center()

	# ⓪ 背景压暗：卡组里其它卡还在，但退到背景。
	# 不压的话「中心的新卡 + 旁边的旧卡」会叠在一起，看着像改造没生效、卡反而多了一张。
	# 前 220ms 淡入，先让人看清「是从哪一张开始变的」。
	var dim := clampf(t / 220.0, 0.0, 1.0) * 0.66
	if dim > 0.0:
		cv.draw_rect(Rect2(Vector2.ZERO, cv.size), Color(0.03, 0.03, 0.05, dim), true)

	# ---- ① 旧卡炸开：闪光 + 碎片 ----
	if t < PH_SHARD:
		# 暖金闪白（不是纯白）：纯白压在暗底上会发灰，看着像「卡被挖空了一块」；
		# 金色更像卡牌被点着、烧成光 —— 与「源数之力」的调性一致。
		var k := clampf(t / 140.0, 0.0, 1.0)
		var flash := Color(1.0, 0.86, 0.52, 0.78 * (1.0 - k))
		cv.draw_rect(_from, flash, true)
		cv.draw_rect(_from.grow(5.0 * k), Color(GOLD.r, GOLD.g, GOLD.b, 0.95 * (1.0 - k)),
				false, 2.5)
	if t < PH_SHARD + 180.0:
		var k2 := clampf(t / (PH_SHARD + 180.0), 0.0, 1.0)
		var a := 1.0 - k2
		for i in SHARD_N:
			var ang := TAU * float(i) / float(SHARD_N) + 0.35
			var dir := Vector2(cos(ang), sin(ang))
			var d0 := 26.0 + 150.0 * k2
			var d1 := d0 + 34.0 * (1.0 - 0.4 * k2)
			cv.draw_line(c + dir * d0, c + dir * d1,
					Color(GOLD.r, GOLD.g, GOLD.b, 0.85 * a), 3.0)

	# ---- ② 光环：两圈金环（第二圈错 60ms）----
	for idx in 2:
		var t0 := 120.0 + 60.0 * float(idx)
		if t < t0:
			continue
		var k3 := clampf((t - t0) / 400.0, 0.0, 1.0)
		if k3 >= 1.0:
			continue
		var rad := 34.0 + 300.0 * (1.0 - pow(1.0 - k3, 2.0))
		var col := GOLD if idx == 0 else GOLD_SOFT
		cv.draw_arc(c, rad, 0.0, TAU, 56, Color(col.r, col.g, col.b, 0.7 * (1.0 - k3)),
				3.0 if idx == 0 else 2.0)

	# ---- ③ 新卡浮现：0.55 → 1.0（ease-out-back）----
	if _new_card != null and t >= PH_SHARD:
		var k4 := clampf((t - PH_SHARD) / (PH_CARD - PH_SHARD), 0.0, 1.0)
		var s := 0.55 + 0.45 * _ease_back(k4)
		var fc := _final.get_center()
		var half := _final.size * 0.5 * s
		var r := Rect2(fc - half, _final.size * s)
		# 底衬光：让新卡从暗底里"浮"出来，再收掉（不长期压着卡面）
		if k4 < 1.0:
			var g := 1.0 - k4
			cv.draw_rect(r.grow(18.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.10 * g), true)
		# 卡背后垫一层暗底：网格**不重排**（`_fx_hide` 只跳过绘制），新卡正下方还压着
		# 别的卡 —— 不垫的话旧卡的边框 / 书签会从新卡边缘「长出来」（实拍踩到过）。
		cv.draw_rect(r.grow(20.0), Color(0.12, 0.13, 0.17, 0.92), true)
		CardFace.draw_pick(cv, _new_card, r, font, font_bold, false)
		var edge := 1.0 - clampf(absf(1.0 - k4) * 2.0, 0.0, 1.0) * 0.5
		cv.draw_rect(r.grow(2.0), Color(GOLD.r, GOLD.g, GOLD.b, edge), false, 2.0)

	# ---- ④ 定格：旧名 → 新名 ----
	if t >= PH_CARD - 40.0:
		var k5 := clampf((t - (PH_CARD - 40.0)) / 240.0, 0.0, 1.0)
		var a5 := 0.92 * k5
		var base := _final.position + Vector2(_final.size.x * 0.5,
				_final.size.y + 30.0)
		var line := "%s  →  %s" % [_old_name, _new_name]
		var w := 460.0
		cv.draw_string(font_bold, Vector2(base.x - w * 0.5, base.y), line,
				HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(1.0, 0.95, 0.82, a5))
		cv.draw_string(font, Vector2(base.x - w * 0.5, base.y + 22.0),
				"源数之力 · 卡牌已被改写", HORIZONTAL_ALIGNMENT_CENTER, w, 13,
				Color(0.72, 0.70, 0.80, a5))


static func _ease_back(k: float) -> float:
	## 标准 ease-out-back：末段轻微过冲（新卡"弹"进位置），比线性有生命感。
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)
