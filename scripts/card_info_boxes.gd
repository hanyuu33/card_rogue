extends RefCounted
## ⚠️ 刻意**不用 class_name**：本项目里 UiTheme / BattleScene 这些界面脚本都走
##    const X = preload(...)，--check-only 单文件检查与导出包都稳（全局类要靠编辑器
##    扫项目才注册，命令行下会报「Identifier not declared」）。用方：BattleScene 顶部 preload。

const UiTheme = preload("res://scripts/ui_theme.gd")
## 卡牌详情的「框体流」排版（R297）。
##
## 用户口径（R297）：「卡牌带有的字段解释和获得的 buff 只是纯文本」→ 改成**一块一块的框**：
##   ① **原始效果文本**单独一个框，**高度随文字量变**（先折行数出行数，再按行数算框高）；
##   ② 效果框后面接**字段解释框**，每个字段一个，框内「图标 名字：解释」
##      （名字 / 解释 / 图标全部来自 `CardData.AFFIX_DEFS`，别在这里写死文案）；
##   ③ 字段框下面接 **buff 框**，每种一个（**附魔也算 buff**，走 `CardData.ENCHANT_DEFS`）。
##   ④ 数值不拆行：「力量 + 生命」同一个框、「攻击距离 + 移动速度」同一个框，
##      框内一律**图标 + 数字**（图标复用卡面徽章素材 `UiAssets.badge_icon`）。
##
## ⚠️ **测量与绘制必须共用同一套判断**（`box_h()` 只有一份）：框高算错的结果是
##    「字戳出框外」或「框里空半截」，而且只有出图才看得出来。所以高度计算是
##    `static` 纯函数，单测可以直接调它比对（字数多了框必须变高）。
##
## 块字典（由 `BattleScene._info_blocks()` 组装，本模块只管测量与画）：
##   type   "text"（富文本正文）/ "stats"（图标+数字）/ 其余按「带图标的一行块」处理
##   segs   富文本片段（`CardText.parse` 的产物）；名字用 bold 段放最前面
##   glyph  自绘符号名（字段 / buff 用，见 `draw_glyph`）
##   icon   素材图标（Texture2D，数值 / 附魔用；与 glyph 二选一）
##   items  stats 专用：[{icon, text, col}]
##   col    类别色（左边竖条 + 图标 + 边框）
##   bg     框底色（不传 → 纸张上压一层半透明白）

const PAD_X := 6.0
const PAD_Y := 5.0
const GAP := 4.0            # 框与框之间的缝
const ICON := 15.0          # 图标列宽（自绘符号 / 素材图标都按这个方框居中）
const LINE_H := 14.0
const FS := 10              # 正文10（左栏原来就是 FS_MICRO，字号不变）
const STATS_H := 15.0       # 数值框里「图标 + 数字」那行的净高
const STATS_PAD_Y := 3.0    # 数值框的上下内边距（比正文块小：里面只有一行图标）
const EDGE := 0.55          # 边框 / 竖条的不透明度


# ------------------------------------------------------------ 测量（纯函数，单测直接调）

static func rows_of(segs: Array, w: float, size: int = FS) -> int:
	## 这段富文本在 `w` 宽里要占几行（空内容 → 0 行，调用方据此决定要不要出框）。
	if segs.is_empty() or w <= 4.0:
		return 0
	var lines := CardText.wrap_segments(UiTheme.font(), UiTheme.font_bold(), segs, w, size)
	return lines.size()


static func has_icon(b: Dictionary) -> bool:
	return str(b.get("glyph", "")) != "" or b.get("icon") is Texture2D


static func text_width(w: float, b: Dictionary) -> float:
	## 块内正文可用宽度（扣掉左右内边距与左侧图标列）。
	var iw := ICON + 3.0 if has_icon(b) else 0.0
	return maxf(8.0, w - PAD_X * 2.0 - iw)


static func box_h(b: Dictionary, w: float, size: int = FS) -> float:
	## 单块高度：**文字行数决定**（这正是「框随文字量变」的实现处）。
	var t := str(b.get("type", "text"))
	if t == "stats":
		return STATS_PAD_Y * 2.0 + STATS_H
	if t == "caption":
		return PAD_Y * 0.6 + LINE_H          # 小标题（不画框，只占一行）
	var rows := rows_of(b.get("segs", []), text_width(w, b), size)
	if rows <= 0:
		return 0.0
	var body := float(rows) * LINE_H
	if has_icon(b):
		body = maxf(body, ICON)
	return PAD_Y * 2.0 + body


static func measure(blocks: Array, w: float, size: int = FS) -> float:
	## 整串块的总高（含块间缝，末块不加缝）—— 左栏据此判断「还画得下几块」。
	var h := 0.0
	var n := 0
	for b: Dictionary in blocks:
		var bh := box_h(b, w, size)
		if bh <= 0.0:
			continue
		h += bh
		n += 1
	if n <= 1:
		return h
	return h + GAP * float(n - 1)


# ------------------------------------------------------------ 绘制

static func draw_all(cv: CanvasItem, blocks: Array, x: float, y: float, w: float,
		size: int = FS, max_y := -1.0) -> float:
	## 逐块画；**放不下就整块不画**（不做半块截断 —— 半块框比没有更难看），
	## 并在原地画一行「……」告诉玩家下面还有内容。返回画完后的 y。
	var font := UiTheme.font()
	var font_bold := UiTheme.font_bold()
	for b: Dictionary in blocks:
		var h := box_h(b, w, size)
		if h <= 0.0:
			continue
		if max_y >= 0.0 and y + h > max_y:
			cv.draw_string(font, Vector2(x + PAD_X, y + font.get_ascent(size)),
					"……", HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiTheme.INK_600)
			return y
		if str(b.get("type", "text")) == "caption":
			# 小标题：不画框（框只给「块」，标题只是分隔用），左侧不留竖条
			cv.draw_string(font_bold, Vector2(x, y + float(font_bold.get_ascent(size))),
					str(b.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, size,
					b.get("col", UiTheme.INK_600))
			y += h + GAP
			continue
		_draw_box(cv, font, font_bold, b, Rect2(x, y, w, h), size)
		y += h + GAP
	return y


static func _draw_box(cv: CanvasItem, font: Font, font_bold: Font, b: Dictionary,
		rect: Rect2, size: int) -> void:
	var col: Color = b.get("col", UiTheme.INK_600)
	var bg: Color = b.get("bg", Color(1.0, 1.0, 1.0, 0.42))
	cv.draw_rect(rect, bg, true)
	cv.draw_rect(rect, Color(col.r, col.g, col.b, EDGE), false, 1.0)
	# 左侧竖条：类别色。字段 / buff 一眼分得开（框都一样时很难扫读）。
	cv.draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)),
			Color(col.r, col.g, col.b, 0.8), true)
	if str(b.get("type", "text")) == "stats":
		_draw_stats(cv, font_bold, b, rect, size)
		return
	var cx := rect.position.x + PAD_X + ICON * 0.5
	var cy := rect.position.y + PAD_Y + LINE_H * 0.5
	var tex: Variant = b.get("icon")
	if tex is Texture2D:
		var ir := ICON * 0.42
		cv.draw_texture_rect(tex as Texture2D,
				Rect2(Vector2(cx - ir, cy - ir), Vector2(ir, ir) * 2.0), false)
	elif str(b.get("glyph", "")) != "":
		draw_glyph(cv, Vector2(cx, cy), ICON * 0.42, str(b["glyph"]), col)
	var tx := rect.position.x + PAD_X + (ICON + 3.0 if has_icon(b) else 0.0)
	var tw := rect.size.x - (tx - rect.position.x) - PAD_X
	var base := rect.position.y + PAD_Y + float(font.get_ascent(size))
	CardText.draw_wrapped(cv, font, font_bold, b.get("segs", []), tx, base, tw, size,
			LINE_H, UiTheme.INK_600)


static func _draw_stats(cv: CanvasItem, font_bold: Font, b: Dictionary, rect: Rect2,
		size: int) -> void:
	## 数值框：图标 + 数字横排（力量 / 生命 一组，攻击距离 / 移动速度 一组）。
	var items: Array = b.get("items", [])
	var cy := rect.position.y + rect.size.y * 0.5
	var x := rect.position.x + PAD_X + 2.0
	var ir := 6.0
	var asc := float(font_bold.get_ascent(size))
	for it: Dictionary in items:
		var col: Color = it.get("col", UiTheme.INK_600)
		var cx := x + ir
		var tex: Variant = it.get("icon")
		if tex is Texture2D:
			cv.draw_texture_rect(tex as Texture2D,
					Rect2(Vector2(cx - ir, cy - ir), Vector2(ir, ir) * 2.0), false)
		else:
			cv.draw_circle(Vector2(cx, cy), ir * 0.82, col)
		var txt := str(it.get("text", ""))
		var tx := cx + ir + 3.0
		cv.draw_string(font_bold, Vector2(tx, cy + asc * 0.42), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x = tx + font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12.0


# ------------------------------------------------------------ 自绘图标
# 字段 / buff 没有美术素材（`assets/ui/icon_*` 只有费用 / 力量 / 生命 / 箭 / 鞋），
# 所以这里用**几何图形**画：不依赖素材、不会出现「缺图空白」，颜色跟随类别色。

static func draw_glyph(cv: CanvasItem, c: Vector2, r: float, glyph: String, col: Color) -> void:
	match glyph:
		"run":                     # 疾行：两个向右的箭头
			for i in 2:
				var x := c.x - r * 0.42 + float(i) * r * 0.74
				cv.draw_polyline(PackedVector2Array([
					Vector2(x - r * 0.30, c.y - r * 0.52),
					Vector2(x + r * 0.22, c.y),
					Vector2(x - r * 0.30, c.y + r * 0.52)]), col, 1.6)
		"taunt":                   # 嘲讽：靶心 + 四向短刺（「都冲我来」）
			cv.draw_arc(c, r * 0.70, 0.0, TAU, 20, col, 1.6)
			cv.draw_circle(c, r * 0.24, col)
			for i in 4:
				var a: float = TAU * float(i) / 4.0 + PI * 0.25
				cv.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.88,
						c + Vector2(cos(a), sin(a)) * r * 1.06, col, 1.4)
		"death":                   # 死亡：圆头 + 两个眼洞
			cv.draw_circle(c, r * 0.72, Color(col.r, col.g, col.b, 0.22))
			cv.draw_arc(c, r * 0.72, 0.0, TAU, 20, col, 1.5)
			cv.draw_circle(c + Vector2(-r * 0.26, -r * 0.12), r * 0.17, col)
			cv.draw_circle(c + Vector2(r * 0.26, -r * 0.12), r * 0.17, col)
			cv.draw_line(c + Vector2(-r * 0.24, r * 0.40), c + Vector2(r * 0.24, r * 0.40),
					col, 1.3)
		"ghost":                   # 幻影：两个错位方框
			cv.draw_rect(Rect2(c - Vector2(r * 0.78, r * 0.74), Vector2(r * 1.0, r * 1.0)),
					col, false, 1.4)
			cv.draw_rect(Rect2(c - Vector2(r * 0.26, r * 0.22), Vector2(r * 1.0, r * 1.0)),
					Color(col.r, col.g, col.b, 0.55), false, 1.4)
		"shield", "share":         # 护盾 / 共享护盾：盾形（共享多一个十字）
			var pts := PackedVector2Array([
				c + Vector2(-r * 0.60, -r * 0.68), c + Vector2(r * 0.60, -r * 0.68),
				c + Vector2(r * 0.60, r * 0.04), c + Vector2(0.0, r * 0.78),
				c + Vector2(-r * 0.60, r * 0.04)])
			cv.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.26))
			var edge := pts.duplicate()
			edge.append(pts[0])
			cv.draw_polyline(edge, col, 1.4)
			if glyph == "share":
				cv.draw_line(c + Vector2(-r * 0.24, 0.0), c + Vector2(r * 0.24, 0.0), col, 1.4)
				cv.draw_line(c + Vector2(0.0, -r * 0.24), c + Vector2(0.0, r * 0.24), col, 1.4)
		"portal":                  # 次元：两个同心菱形
			for k in 2:
				var s := r * (0.80 - 0.38 * float(k))
				cv.draw_polyline(PackedVector2Array([
					c + Vector2(0.0, -s), c + Vector2(s, 0.0), c + Vector2(0.0, s),
					c + Vector2(-s, 0.0), c + Vector2(0.0, -s)]),
					Color(col.r, col.g, col.b, 1.0 - 0.40 * float(k)), 1.4)
		"overload":                # 超负荷：圆 + 闪电
			cv.draw_arc(c, r * 0.72, 0.0, TAU, 20, col, 1.4)
			cv.draw_polyline(PackedVector2Array([
				c + Vector2(r * 0.16, -r * 0.62), c + Vector2(-r * 0.30, r * 0.05),
				c + Vector2(r * 0.02, r * 0.05), c + Vector2(-r * 0.16, r * 0.64)]), col, 1.8)
		"swap":                    # 交换：一上一下两支反向箭头
			cv.draw_line(c + Vector2(-r * 0.66, -r * 0.34), c + Vector2(r * 0.44, -r * 0.34),
					col, 1.4)
			cv.draw_colored_polygon(PackedVector2Array([
				c + Vector2(r * 0.74, -r * 0.34), c + Vector2(r * 0.30, -r * 0.62),
				c + Vector2(r * 0.30, -r * 0.06)]), col)
			cv.draw_line(c + Vector2(r * 0.66, r * 0.34), c + Vector2(-r * 0.44, r * 0.34),
					col, 1.4)
			cv.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.74, r * 0.34), c + Vector2(-r * 0.30, r * 0.06),
				c + Vector2(-r * 0.30, r * 0.62)]), col)
		"save":                    # 保存：书签
			var bm := PackedVector2Array([
				c + Vector2(-r * 0.52, -r * 0.70), c + Vector2(r * 0.52, -r * 0.70),
				c + Vector2(r * 0.52, r * 0.72), c + Vector2(0.0, r * 0.28),
				c + Vector2(-r * 0.52, r * 0.72)])
			cv.draw_colored_polygon(bm, Color(col.r, col.g, col.b, 0.28))
			var bm_e := bm.duplicate()
			bm_e.append(bm[0])
			cv.draw_polyline(bm_e, col, 1.4)
		"up", "down":              # buff 增益 / 减益：粗箭头
			var sgn: float = -1.0 if glyph == "up" else 1.0
			cv.draw_line(c + Vector2(0.0, sgn * -r * 0.58), c + Vector2(0.0, sgn * r * 0.56),
					col, 1.6)
			cv.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, sgn * -r * 0.82), c + Vector2(-r * 0.44, sgn * -r * 0.20),
				c + Vector2(r * 0.44, sgn * -r * 0.20)]), col)
		_:                         # 中性 / 未知：小菱形
			cv.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -r * 0.52), c + Vector2(r * 0.52, 0.0),
				c + Vector2(0.0, r * 0.52), c + Vector2(-r * 0.52, 0.0)]), col)
