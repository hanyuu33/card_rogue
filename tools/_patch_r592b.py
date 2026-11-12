# -*- coding: utf-8 -*-
"""R592：字段标志化（卡面）。

三件事：
  ① `UiAssets.affix_badge(glyph)` —— 标志素材唯一取图口（缺图 null，回退矢量符号）；
  ② `CardFace` 右上角**圆形槽位** + 多字段**轮播**（交叉淡化），
     槽位让开稀有度缎带（那东西占最右沿 ~8.1k 宽）；
  ③ 文字区**不再写字段**（`种类 · 字段` 只留种类）；卡面**不再画成长角标**
     （+力/+生命 只在 `CardDetailOverlay` 的「本局永久成长」段显示）。

⚠️ card_face.gd / ui_assets.gd 都是 **LF** 文件。
"""
import io
import sys

CHECK_ONLY = '--check-only' in sys.argv
CF = 'scripts/card_face.gd'
UA = 'scripts/ui_assets.gd'

UIASSETS_FUNCS = '''

static func affix_badge_path(glyph: String) -> String:
	## R592：字段标志文件名（128x128 无背景 PNG）。文件名即契约 —— 换图只覆盖
	## assets/ui/affix_<glyph>.png；`<glyph>` 由 `CardData.affix_glyph(字段名)` 给出。
	return path_for("affix_%s" % glyph)


static func affix_badge(glyph: String) -> Texture2D:
	## R592：字段标志**唯一取图口**。缺图返回 null → 卡面回退
	## `CardInfoBoxes.draw_glyph()` 的矢量符号（没导入 / 导出包读不到 png 时照常可玩）。
	if glyph == "":
		return null
	return get_tex("affix_%s" % glyph)
'''

CF_BLOCK = '''# ------------------------------------------------------------ 字段标志（R592）
## **字段不再走文字**（用户口径 R592：「所有贴在卡上的 buff 都不再用纯文字」）。
## 卡面右上角有一个**圆形槽位**，同一时刻只显示一个字段标志；卡上有多个字段时
## 按 `AFFIX_BADGE_CYCLE_MS` 轮流切换（收尾交叉淡化 `AFFIX_BADGE_FADE_MS`）。
##   · 素材：`assets/ui/affix_<glyph>.png`（`CardData.affix_glyph()` 给名字），
##     缺图回退 `CardInfoBoxes.draw_glyph()` 的矢量符号 + 语义色圆底。
##   · 位置：让开右上角的**稀有度缎带**（占最右沿 ~8.1k 宽 / 27k 高）——
##     槽位右沿 = 卡右沿 - pad - 缎带宽 - 2k，两者并排，谁也不压谁。
##   · 战场卡面（`on_board`）沿用 `affix_on_board()` 过滤：交换 / 幻影上场后不再显示。
const AFFIX_BADGE_D := 20.0            # 圆形槽位直径（× k，与卡高同比）
const AFFIX_BADGE_CYCLE_MS := 1800     # 单个标志停留时长
const AFFIX_BADGE_FADE_MS := 240       # 收尾交叉淡化时长


static func affix_badge_queue(card: CardData, on_board := false) -> Array[String]:
	## 这张卡**要轮流显示**的字段（中文名，按 `affixes` 顺序）。
	## 战场卡面滤掉「上场之后已无作用」的（交换 / 幻影），与旧文字行同一口径。
	var out: Array[String] = []
	if card == null:
		return out
	for a: String in card.affixes:
		if on_board and not CardData.affix_on_board(a):
			continue
		out.append(a)
	return out


static func affix_badge_rect(card: CardData, rect: Rect2, on_board := false) -> Rect2:
	## **圆形槽位的唯一口**（绘制与回归共用，别各算一遍）。
	## 没有字段 → 空 Rect2（`size == Vector2.ZERO`）。
	if card == null or affix_badge_queue(card, on_board).is_empty():
		return Rect2()
	var k := rect.size.y / CARD_H_DESIGN
	var pad: float = UiTheme.CARD_PAD * k
	# 缎带素材 w/h 约 0.29~0.32（ribbon_0..5），绘制高 27k → 宽约 8.1k；再留 2k 呼吸。
	var ribbon_w: float = 27.0 * k * 0.32 + 1.0 * k
	var d: float = AFFIX_BADGE_D * k
	return Rect2(rect.end.x - pad - ribbon_w - 2.0 * k - d, rect.position.y + pad, d, d)


static func affix_badge_state(card: CardData, on_board: bool, now_ms: int) -> Dictionary:
	## 轮播状态**唯一口**：`{count, index, next, fade}`。
	## `fade` = 0 全然是 `index`，= 1 全然是 `next`（`next == -1` 表示没有下一张）。
	## 只有一张时不轮播（fade 恒 0）；多张按环形推进 —— 到末尾自然接回第 0 张。
	var n := affix_badge_queue(card, on_board).size()
	if n <= 0:
		return {"count": 0, "index": 0, "next": -1, "fade": 0.0}
	if n == 1:
		return {"count": 1, "index": 0, "next": -1, "fade": 0.0}
	var cycle := AFFIX_BADGE_CYCLE_MS
	var t: int = now_ms % (cycle * n)
	var idx: int = int(t / cycle)
	var phase: int = t % cycle
	var fade := 0.0
	var nxt := -1
	if phase > cycle - AFFIX_BADGE_FADE_MS:
		fade = float(phase - (cycle - AFFIX_BADGE_FADE_MS)) / float(AFFIX_BADGE_FADE_MS)
		nxt = (idx + 1) % n
	return {"count": n, "index": idx, "next": nxt, "fade": clampf(fade, 0.0, 1.0)}


static func affix_badge_text(card: CardData, on_board: bool, now_ms: int) -> String:
	## 此刻**正在显示**的字段名（测试与悬停提示共用；不进绘制路径）。
	var q := affix_badge_queue(card, on_board)
	if q.is_empty():
		return ""
	var st := affix_badge_state(card, on_board, now_ms)
	return q[int(st["index"])]


static func _draw_affix_badges(canvas: CanvasItem, card: CardData, rect: Rect2,
		k: float, on_board: bool) -> void:
	## 右上角圆形槽位：先画下一张（淡入），再画当前张（淡出），交叉过渡不闪。
	if card == null:
		return
	var q := affix_badge_queue(card, on_board)
	if q.is_empty():
		return
	var box := affix_badge_rect(card, rect, on_board)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var st := affix_badge_state(card, on_board, Time.get_ticks_msec())
	var fade: float = float(st["fade"])
	var nxt: int = int(st["next"])
	if nxt >= 0 and fade > 0.0:
		_draw_one_affix_badge(canvas, q[nxt], box, k, fade)
	_draw_one_affix_badge(canvas, q[int(st["index"])], box, k, 1.0 - fade)


static func _draw_one_affix_badge(canvas: CanvasItem, name: String, box: Rect2,
		k: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var glyph := CardData.affix_glyph(name)
	var tex: Texture2D = UiAssets.affix_badge(glyph)
	if tex != null:
		canvas.draw_texture_rect(tex, box, false, Color(1.0, 1.0, 1.0, alpha))
		return
	# 回退：语义色圆底 + 矢量符号（素材缺图时照常可玩，只是没那么精致）
	var cols: Array = CardData.affix_colors(name)
	var bg: Color = cols[0]
	var fg: Color = cols[1]
	bg.a *= alpha
	fg.a *= alpha
	var c := box.get_center()
	canvas.draw_circle(c, box.size.y * 0.5, bg)
	canvas.draw_arc(c, box.size.y * 0.46, 0.0, TAU, 28,
			Color(fg.r, fg.g, fg.b, 0.9 * alpha), maxf(1.0, 1.2 * k))
	preload("res://scripts/card_info_boxes.gd").draw_glyph(
			canvas, c, box.size.y * 0.30, glyph, fg)


'''


def main():
    ua = io.open(UA, encoding='utf-8', newline='').read()
    cf = io.open(CF, encoding='utf-8', newline='').read()
    ok = True

    # ---- ① UiAssets：插在 div_orb_glass 之前 ----
    anchor_ua = '\n\nstatic func div_orb_glass() -> Texture2D:'
    if ua.count(anchor_ua) != 1:
        print('[FAIL] ui_assets 锚点 %d 次' % ua.count(anchor_ua))
        ok = False
    else:
        ua = ua.replace(anchor_ua, UIASSETS_FUNCS + '\n\nstatic func div_orb_glass() -> Texture2D:', 1)

    # ---- ② CardFace：新增函数块（插在稀有度缎带之前）----
    anchor_cf = 'static func _draw_rarity_ribbon(canvas: CanvasItem, card: CardData, rect: Rect2,'
    if cf.count(anchor_cf) != 1:
        print('[FAIL] card_face 缎带锚点 %d 次' % cf.count(anchor_cf))
        ok = False
    else:
        cf = cf.replace(anchor_cf, CF_BLOCK + anchor_cf, 1)

    # ---- ③ draw()：缎带之后画标志 ----
    a1 = ('\t_draw_rarity_ribbon(canvas, card, rect, k, pad)\n'
          '\t# ⑤ 卡图与文字区的分隔线\n')
    b1 = ('\t_draw_rarity_ribbon(canvas, card, rect, k, pad)\n'
          '\t# ④c R592：字段标志（右上圆形槽位，多字段轮播；让开缎带）\n'
          '\t_draw_affix_badges(canvas, card, rect, k, on_board)\n'
          '\t# ⑤ 卡图与文字区的分隔线\n')
    if cf.count(a1) != 1:
        print('[FAIL] draw() 插标志锚点 %d 次' % cf.count(a1))
        ok = False
    else:
        cf = cf.replace(a1, b1, 1)

    # ---- ④ draw_pick()：同上（字段不过滤）----
    a2 = ('\t_draw_rarity_ribbon(canvas, card, rect, k, pad)\n'
          '\t_draw_name_zone(canvas, card, rect, kt, k, pad, font_bold)')
    b2 = ('\t_draw_rarity_ribbon(canvas, card, rect, k, pad)\n'
          '\t_draw_affix_badges(canvas, card, rect, k, false)   # R592：字段标志\n'
          '\t_draw_name_zone(canvas, card, rect, kt, k, pad, font_bold)')
    if cf.count(a2) != 1:
        print('[FAIL] draw_pick() 插标志锚点 %d 次' % cf.count(a2))
        ok = False
    else:
        cf = cf.replace(a2, b2, 1)

    # ---- ⑤ 文字行只留卡种 ----
    a3 = ('\t# ⑥ R118：战场卡面（`on_board`）只写**上场之后仍然有用**的字段 —— 交换 / 幻影是\n'
          '\t# 「打出那一刻」的规则，卡一落到格子上就再无作用，继续写在这里只会误导玩家。\n'
          '\t# ⚠️ 判空不能用 `card.affixes.is_empty()`：过滤之后**可能整段为空**（只剩种类的卡）。\n'
          '\tvar affix_txt: String = card.field_affix_line() if on_board else card.affix_line()\n')
    # 原文没有「⑥ 」前缀，用真实文本
    a3 = ('\t# R118：战场卡面（`on_board`）只写**上场之后仍然有用**的字段 —— 交换 / 幻影是\n'
          '\t# 「打出那一刻」的规则，卡一落到格子上就再无作用，继续写在这里只会误导玩家。\n'
          '\t# ⚠️ 判空不能用 `card.affixes.is_empty()`：过滤之后**可能整段为空**（只剩种类的卡）。\n'
          '\tvar affix_txt: String = card.field_affix_line() if on_board else card.affix_line()\n')
    b3 = ('\t# R592：**字段改走右上角标志**（`_draw_affix_badges`），这一行只剩卡种。\n'
          '\t# 字段名不再出现在文字里 —— 用户口径「所有贴在卡上的 buff 都不再用纯文字」。\n'
          '\t# `card.affix_line()` / `field_affix_line()` 保留：它们是数据层口径\n'
          '\t# （悬停浮层 / 战场徽标 / 测试仍在用），只是卡面不再画。\n'
          '\tvar affix_txt: String = ""\n')
    if cf.count(a3) != 1:
        print('[FAIL] 文字行锚点 %d 次' % cf.count(a3))
        ok = False
    else:
        cf = cf.replace(a3, b3, 1)

    # ---- ⑥ 删 draw() 的成长角标 ----
    a4 = ('\t# ⑨ 本局成长角标（R393b）—— 卡图左下角，写明「哪几个数字是长出来的」\n'
          '\t_draw_growth_mark(canvas, card, rect, font_bold)\n')
    b4 = ('\t# ⑨ R592：**卡面不再画成长角标**（用户口径「+力/+生命 直接不在卡面上显示」）。\n'
          '\t#    数值照旧按「比原型高」染色，具体加了多少去详细描述看 ——\n'
          '\t#    `CardDetailOverlay` 的「本局永久成长　力+1 生+6」那一段就是它的新家。\n')
    if cf.count(a4) != 1:
        print('[FAIL] draw() 成长角标锚点 %d 次' % cf.count(a4))
        ok = False
    else:
        cf = cf.replace(a4, b4, 1)

    # ---- ⑦ 删 draw_pick() 的成长角标 ----
    a5 = '\t_draw_growth_mark(canvas, card, rect, font_bold)            # R393b：本局成长角标\n'
    b5 = '\t# R592：选卡页同样不画成长角标（+力/+生命 只在详细描述里）\n'
    if cf.count(a5) != 1:
        print('[FAIL] draw_pick() 成长角标锚点 %d 次' % cf.count(a5))
        ok = False
    else:
        cf = cf.replace(a5, b5, 1)

    if not ok:
        print('补丁未写入')
        return 1

    for name, text in ((UA, ua), (CF, cf)):
        bare = text.count('\n') - text.count('\r\n')
        if bare != text.count('\n'):
            print('[FAIL] %s 混进 CRLF' % name)
            return 1
    print('ui_assets：affix_badge 已加（LF）')
    print('card_face：圆形槽位 + 轮播 + 文字行/成长角标已改（LF）')
    if CHECK_ONLY:
        print('--check-only：未写盘')
        return 0
    io.open(UA, 'w', encoding='utf-8', newline='').write(ua)
    io.open(CF, 'w', encoding='utf-8', newline='').write(cf)
    print('已写入')
    return 0


if __name__ == '__main__':
    sys.exit(main())
