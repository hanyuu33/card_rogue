# -*- coding: utf-8 -*-
"""R592d：字段标志槽位从「让开缎带」改为「贴卡框右上角」。

用户口径（2026-11-12）：
  「位置不太好，感觉可以放在下面中间，和属性放在一行。」
  → 底部数值徽章圆心全压在卡框线上、彼此相切，中间只剩 2.8k 的缝，放不下。
  → 用户二次口径：「没有位置的话，放到右上角吧，略微遮挡旗子也无所谓。」
所以：圆心向卡框右上角内收 `AFFIX_BADGE_CORNER * d`，不再减缎带宽 ——
标志与稀有度缎带相压，压在**缎带上层**（绘制顺序本来就在缎带之后）。
"""
import io
import sys

LF = chr(10)

def patch(path, pairs, crlf):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        src = f.read()
    for old, new in pairs:
        o = old.replace("\n", "\r\n") if crlf else old
        n = new.replace("\n", "\r\n") if crlf else new
        c = src.count(o)
        assert c == 1, "anchor count=%d for %r" % (c, o[:60])
        src = src.replace(o, n)
    if crlf:
        src = src.replace("\r\n", "\n").replace("\n", "\r\n")
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    # 换行自检
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        raw = f.read()
    bare = raw.replace("\r\n", "").count("\n") if crlf else raw.count("\r\n")
    assert bare == 0, "line-ending broken in %s (%d)" % (path, bare)
    print("[ok]", path)


# ── ① card_face.gd：注释 + 常量 + 槽位口径 ────────────────────────────────
CF = "scripts/card_face.gd"
cf_pairs = []

cf_pairs.append((
"""##   · 位置：让开右上角的**稀有度缎带**（占最右沿 ~8.1k 宽 / 27k 高）——
##     槽位右沿 = 卡右沿 - pad - 缎带宽 - 2k，两者并排，谁也不压谁。""",
"""##   · 位置（R592d）：**贴卡框右上角**，圆心向角内收 `AFFIX_BADGE_CORNER * d`。
##     第一版为了不压稀有度缎带（占最右沿 ~8.6k 宽 / 27k 高）把槽位往卡图里推，
##     结果落在卡图中段、既不属于角标也不属于文字区 —— 用户口径「位置不太好」。
##     试过「底部正中、与数值徽章同一行」：四枚数值徽章圆心全压在卡框线上、
##     彼此相切，中间只剩 2.8k 的缝，放不进可读的标志。
##     用户二次口径「放右上角，略微遮挡旗子也无所谓」→ 恢复角标语义，
##     与缎带相压（本函数之后才画旗子，标志在上层，燕尾仍露出来可辨稀有度）。""")) 

cf_pairs.append((
"""const AFFIX_BADGE_D := 20.0            # 圆形槽位直径（× k，与卡高同比）""",
"""const AFFIX_BADGE_D := 20.0            # 圆形槽位直径（× k，与卡高同比）
# R592d：圆心离卡框右上角两条边的距离（× d）。0.45 = 略探出内距、像压在角上的角标；
# 调大 = 往卡图里退（会重新变成「卡图中段」），调小 = 探出卡框。
const AFFIX_BADGE_CORNER := 0.45""")) 

cf_pairs.append((
"""	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
	# 缎带素材 w/h 约 0.29~0.32（ribbon_0..5），绘制高 27k → 宽约 8.1k；再留 2k 呼吸。
	var ribbon_w: float = 27.0 * k * 0.32 + 1.0 * k
	var d: float = AFFIX_BADGE_D * kc
	return Rect2(rect.end.x - pad - ribbon_w - 2.0 * k - d, rect.position.y + pad, d, d)""",
"""	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
	var d: float = AFFIX_BADGE_D * kc
	# R592d：角标语义 —— 圆心从**卡框右上角**向内收 0.45d（不是从缎带左边线起算）。
	var c := Vector2(rect.end.x - pad - AFFIX_BADGE_CORNER * d,
			rect.position.y + pad + AFFIX_BADGE_CORNER * d)
	return Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d))""")) 

cf_pairs.append((
"""	## **圆形槽位的唯一口**（绘制与回归共用，别各算一遍）。
	## 没有字段 → 空 Rect2（`size == Vector2.ZERO`）。""",
"""	## **圆形槽位的唯一口**（绘制与回归共用，别各算一遍）。
	## 没有字段 → 空 Rect2（`size == Vector2.ZERO`）。
	## R592d：贴卡框右上角（圆心向内收 `AFFIX_BADGE_CORNER * d`），**允许压住稀有度缎带**。""")) 

cf_pairs.append((
"""	## 右上角圆形槽位：先画下一张（淡入），再画当前张（淡出），交叉过渡不闪。""",
"""	## 右上角圆形槽位（R592d：压在稀有度缎带上层）：先画下一张（淡入），
	## 再画当前张（淡出），交叉过渡不闪。""")) 

patch(CF, cf_pairs, crlf=False)

# ── ② test_engine.gd：槽位位置锁改口径 ─────────────────────────────────
TE = "scripts/test_engine.gd"
te_pairs = []
te_pairs.append((
"""	# ② 有字段 → 正方形槽位、整个在卡内、右沿让开稀有度缎带""",
"""	# ② 有字段 → 正方形槽位、贴卡框右上角、允许压住稀有度缎带（R592d）""")) 

te_pairs.append((
"""	var ribbon_left: float = box_rect.end.x - UiTheme.CARD_PAD * k - (27.0 * k * 0.32 + 1.0 * k)
	check(slot.end.x <= ribbon_left + 0.01,
			"R592b：槽位右沿不越过缎带左沿（槽右 %.2f / 缎带左 %.2f）"
			% [slot.end.x, ribbon_left])""",
"""	# R592d：**不再是「让开缎带」**（用户口径「放右上角，略微遮挡旗子也无所谓」）——
	# 槽位改成角标：圆心离卡框右上角 0.45d，右沿落在缎带左沿**右边**（压上去）。
	var ribbon_left: float = box_rect.end.x - UiTheme.CARD_PAD * k - (27.0 * k * 0.32 + 1.0 * k)
	check(slot.end.x > ribbon_left,
			"R592d：槽位压在稀有度缎带上（槽右 %.2f / 缎带左 %.2f）"
			% [slot.end.x, ribbon_left])
	var want_c := Vector2(box_rect.end.x - UiTheme.CARD_PAD * k - CardFace.AFFIX_BADGE_CORNER * slot.size.x,
			box_rect.position.y + UiTheme.CARD_PAD * k + CardFace.AFFIX_BADGE_CORNER * slot.size.x)
	check(slot.get_center().distance_to(want_c) < 0.01,
			"R592d：槽位圆心贴卡框右上角（实际 %s / 期望 %s）"
			% [str(slot.get_center()), str(want_c)])""")) 

patch(TE, te_pairs, crlf=True)
print("done")
