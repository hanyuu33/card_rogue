# -*- coding: utf-8 -*-
"""R592e：字段标志 = 费用徽章的**右上角镜像**（同尺寸、圆心压在卡框右上角）。

店长口径（2026-11-12）：
  「不是，我是希望放到和费用对应的位置，并且和费用差不多大小。」
  · 位置：费用圆心 = `cost_badge_center()` = 卡片**左上角**；
          字段标志圆心 = 卡片**右上角**（关于卡面竖直中轴镜像）。
  · 尺寸：不再自定 `AFFIX_BADGE_D`，直接 `badge_radius(rect)` —— 与费用同一口径，
          也自动继承 `CARD_BADGE_SCALE_CAP` 封顶（大卡上不会变巨球）。
  · 圆心压在框线上 = 一半露在卡外，与费用徽章完全一样的「挂在框上」手感；
    容器本来就为数值徽章让了 `CARD_BLEED`，不必另加。
"""
import io


def patch(path, pairs, crlf):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        src = f.read()
    for old, new in pairs:
        o = old.replace("\n", "\r\n") if crlf else old
        n = new.replace("\n", "\r\n") if crlf else new
        assert src.count(o) == 1, "anchor count=%d %r" % (src.count(o), o[:70])
        src = src.replace(o, n)
    if crlf:
        src = src.replace("\r\n", "\n").replace("\n", "\r\n")
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        raw = f.read()
    bare = raw.replace("\r\n", "").count("\n") if crlf else raw.count("\r\n")
    assert bare == 0, "line-ending broken in %s" % path
    print("[ok]", path)


CF = "scripts/card_face.gd"
patch(CF, [
# ① 头部注释
(
"""##   · 位置（R592d）：**贴卡框右上角**，圆心向角内收 `AFFIX_BADGE_CORNER * d`。
##     第一版为了不压稀有度缎带（占最右沿 ~8.6k 宽 / 27k 高）把槽位往卡图里推，
##     结果落在卡图中段、既不属于角标也不属于文字区 —— 用户口径「位置不太好」。
##     试过「底部正中、与数值徽章同一行」：四枚数值徽章圆心全压在卡框线上、
##     彼此相切，中间只剩 2.8k 的缝，放不进可读的标志。
##     用户二次口径「放右上角，略微遮挡旗子也无所谓」→ 恢复角标语义，
##     与缎带相压（本函数之后才画旗子，标志在上层，燕尾仍露出来可辨稀有度）。""",
"""##   · 位置（R592e）：**与费用徽章镜像对称** —— 费用圆心在卡片左上角（`cost_badge_center`），
##     字段标志圆心就在卡片**右上角**（`affix_badge_center`），两枚关于卡面竖直中轴对称。
##     半径也走同一个 `badge_radius()`（= `CARD_BADGE_R × min(k, CARD_BADGE_SCALE_CAP)`），
##     与费用**同尺寸**，圆心同样压在框线上、一半探出卡外。
##     于是玩家的眼睛只要记一对角：左上 = 费用，右上 = 字段。
##     ⚠️ 它必然压在稀有度缎带上（缎带挂在右上角），这是店长明确接受的：
##        「略微遮挡旗子也无所谓」。绘制顺序在缎带之后 → 标志在上层。
##     ⚠️ 试过「底部正中、与数值徽章同一行」：四枚数值徽章圆心全压在卡框线上、
##        彼此相切，中间只剩 2.8k 的缝，放不进可读的标志（要腾位得把徽章砍到 5k）。"""),
# ② 常量：删掉自定义尺寸 / 角标内收
(
"""const AFFIX_BADGE_D := 20.0            # 圆形槽位直径（× k，与卡高同比）
# R592d：圆心离卡框右上角两条边的距离（× d）。0.45 = 略探出内距、像压在角上的角标；
# 调大 = 往卡图里退（会重新变成「卡图中段」），调小 = 探出卡框。
const AFFIX_BADGE_CORNER := 0.45
const AFFIX_BADGE_CYCLE_MS := 1800     # 单个标志停留时长""",
"""## ⚠️ R592e：**没有独立的尺寸常量** —— 直径就是 `2 × badge_radius(rect)`，
## 与费用 / 力量 / 生命那几个数值徽章同一口径（改尺寸只改 `UiTheme.CARD_BADGE_R`）。
const AFFIX_BADGE_CYCLE_MS := 1800     # 单个标志停留时长"""),
# ③ 新增圆心口 + 重写 rect
(
"""static func affix_badge_rect(card: CardData, rect: Rect2, on_board := false) -> Rect2:
	## **圆形槽位的唯一口**（绘制与回归共用，别各算一遍）。
	## 没有字段 → 空 Rect2（`size == Vector2.ZERO`）。
	## R592d：贴卡框右上角（圆心向内收 `AFFIX_BADGE_CORNER * d`），**允许压住稀有度缎带**。
	if card == null or affix_badge_queue(card, on_board).is_empty():
		return Rect2()
	var k := rect.size.y / CARD_H_DESIGN
	# 尺寸跟**徽章**口径（`CARD_BADGE_SCALE_CAP`）：大卡上线性长会变成一颗巨球抢戏，
	# 与费用/力量/生命那几个数值徽章的缩放规则保持一致。
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
	var d: float = AFFIX_BADGE_D * kc
	# R592d：角标语义 —— 圆心从**卡框右上角**向内收 0.45d（不是从缎带左边线起算）。
	var c := Vector2(rect.end.x - pad - AFFIX_BADGE_CORNER * d,
			rect.position.y + pad + AFFIX_BADGE_CORNER * d)
	return Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d))""",
"""static func affix_badge_center(rect: Rect2) -> Vector2:
	## **字段标志的圆心**（R592e）= 卡片的**右上角**。
	## 与 `cost_badge_center()`（左上角）关于卡面竖直中轴对称 —— 店长口径
	## 「放到和费用对应的位置」：左上读费用、右上读字段，视线只用记住一对角。
	## 圆心压在框线上（一半露在卡外），与费用徽章完全一样的手感。
	return Vector2(rect.end.x, rect.position.y)


static func affix_badge_rect(card: CardData, rect: Rect2, on_board := false) -> Rect2:
	## **圆形槽位的唯一口**（绘制与回归共用，别各算一遍）。
	## 没有字段 → 空 Rect2（`size == Vector2.ZERO`）。
	## R592e：圆心 = `affix_badge_center()`（卡框右上角），半径 = `badge_radius()`
	## —— 与费用徽章**同尺寸、同「挂在框上」的位置关系**，允许压住稀有度缎带。
	if card == null or affix_badge_queue(card, on_board).is_empty():
		return Rect2()
	var r: float = badge_radius(rect)
	var c := affix_badge_center(rect)
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)"""),
# ④ 绘制处 kc 的用途说明
(
"""	var fade: float = float(st["fade"])
	var nxt: int = int(st["next"])
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)   # 描边宽度跟徽章口径走""",
"""	var fade: float = float(st["fade"])
	var nxt: int = int(st["next"])
	# 描边宽度跟徽章口径走（尺寸本身已由 `affix_badge_rect()` 决定，这里只管线宽）
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)"""),
], crlf=False)

TE = "scripts/test_engine.gd"
patch(TE, [
(
"""	# ② 有字段 → 正方形槽位、贴卡框右上角、允许压住稀有度缎带（R592d）
	var two_c := CardData.from_dict(base.to_dict())
	two_c.affixes = ["疾行", "嘲讽"]
	var slot := CardFace.affix_badge_rect(two_c, box_rect)
	check(is_equal_approx(slot.size.x, slot.size.y)
			and is_equal_approx(slot.size.x, CardFace.AFFIX_BADGE_D * kc),
			"R592b：槽位是正方形且按徽章口径缩放（实际 %s）" % str(slot.size))
	check(slot.position.x >= box_rect.position.x and slot.end.x <= box_rect.end.x
			and slot.position.y >= box_rect.position.y and slot.end.y <= box_rect.end.y,
			"R592b：槽位整个在卡框内（实际 %s）" % str(slot))
	# R592d：**不再是「让开缎带」**（用户口径「放右上角，略微遮挡旗子也无所谓」）——
	# 槽位改成角标：圆心离卡框右上角 0.45d，右沿落在缎带左沿**右边**（压上去）。
	var ribbon_left: float = box_rect.end.x - UiTheme.CARD_PAD * k - (27.0 * k * 0.32 + 1.0 * k)
	check(slot.end.x > ribbon_left,
			"R592d：槽位压在稀有度缎带上（槽右 %.2f / 缎带左 %.2f）"
			% [slot.end.x, ribbon_left])
	var want_c := Vector2(box_rect.end.x - UiTheme.CARD_PAD * k - CardFace.AFFIX_BADGE_CORNER * slot.size.x,
			box_rect.position.y + UiTheme.CARD_PAD * k + CardFace.AFFIX_BADGE_CORNER * slot.size.x)
	check(slot.get_center().distance_to(want_c) < 0.01,
			"R592d：槽位圆心贴卡框右上角（实际 %s / 期望 %s）"
			% [str(slot.get_center()), str(want_c)])""",
"""	# ② 有字段 → 圆形槽位 = **费用徽章的右上角镜像**（R592e：同尺寸、圆心压卡框右上角）
	var two_c := CardData.from_dict(base.to_dict())
	two_c.affixes = ["疾行", "嘲讽"]
	var slot := CardFace.affix_badge_rect(two_c, box_rect)
	var want_d: float = 2.0 * CardFace.badge_radius(box_rect)
	check(is_equal_approx(slot.size.x, slot.size.y)
			and is_equal_approx(slot.size.x, want_d)
			and is_equal_approx(slot.size.x, 2.0 * UiTheme.CARD_BADGE_R * kc),
			"R592e：槽位是正方形、直径 = 费用徽章（实际 %s / 期望 %.2f）"
			% [str(slot.size), want_d])
	# 位置：与费用圆心（卡左上角）关于卡面竖直中轴镜像 → 卡右上角
	var cost_c := CardFace.cost_badge_center(box_rect)
	var want_c := Vector2(box_rect.end.x - (cost_c.x - box_rect.position.x), cost_c.y)
	check(slot.get_center().distance_to(want_c) < 0.01,
			"R592e：槽位圆心 = 费用圆心的镜像（实际 %s / 期望 %s）"
			% [str(slot.get_center()), str(want_c)])
	check(is_equal_approx(slot.get_center().x, box_rect.end.x)
			and is_equal_approx(slot.get_center().y, box_rect.position.y),
			"R592e：槽位圆心压在卡框右上角（实际 %s）" % str(slot.get_center()))
	# 圆心压框线 → 一半探出卡外，与费用徽章同一手感（探出量 ≤ 一个半径）
	check(slot.end.x - box_rect.end.x <= CardFace.badge_radius(box_rect) + 0.01
			and box_rect.position.y - slot.position.y <= CardFace.badge_radius(box_rect) + 0.01,
			"R592e：槽位只探出一个半径（实际 %s）" % str(slot))
	# R592d：允许压在稀有度缎带上（店长口径「略微遮挡旗子也无所谓」）
	var ribbon_left: float = box_rect.end.x - UiTheme.CARD_PAD * k - (27.0 * k * 0.32 + 1.0 * k)
	check(slot.end.x > ribbon_left,
			"R592d：槽位压在稀有度缎带上（槽右 %.2f / 缎带左 %.2f）"
			% [slot.end.x, ribbon_left])"""),
], crlf=True)
print("done")
