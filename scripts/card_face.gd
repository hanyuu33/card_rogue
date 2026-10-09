class_name CardFace
## 卡面绘制共享工具 —— battle_scene（小卡）与图鉴（大卡）共用同一套视觉。
##
## 全部为静态方法：接收 CanvasItem 与两套字体，无实例状态。
## 卡面结构（与 tkinter 版 draw_card_face 一致）：
##   白底黑边 + 左上费用圆 + 插图 + 名字 + 种类（着色）+ 数值行。

const UiTheme = preload("res://scripts/ui_theme.gd")

const CARD_H_DESIGN := 70.0   # 缩放基准高（battle 版小卡高）

## 力量 / 生命数值色改读 UiTheme（R113 顺带修掉 #b8860b 只有 3.25:1 的对比度问题）。

static var _art_cache := {}   # id -> Texture2D / null（找不到图也缓存，避免反复查盘）


static func art_for(id: int) -> Texture2D:
	if not _art_cache.has(id):
		var path := "res://assets/pics/%d.png" % id
		_art_cache[id] = load(path) if FileAccess.file_exists(path) else null
	return _art_cache[id]


static func fit_rect(src: Vector2, box: Rect2) -> Rect2:
	## 等比缩放放进 box，居中。
	if src == Vector2.ZERO:
		return box
	var s: float = minf(box.size.x / src.x, box.size.y / src.y)
	var sz := src * s
	return Rect2(box.position + (box.size - sz) / 2.0, sz)


static func draw(canvas: CanvasItem, card: CardData, rect: Rect2, hp: int,
		selected: bool, is_tapped: bool, font: Font, font_bold: Font,
		power_override := -1) -> void:
	## 卡面一律按 rect **完整排版**，与图鉴/战场小卡同一套比例，没有「按可见高度重锚」
	## 之类的特例 —— 手牌卡底沉出窗口下沿时，被挡住的那截就让它挡住
	## （作者口径：卡片是一个整体，排版要与正常状态完全一致，别为了躲裁剪挪数值）。
	var k := rect.size.y / CARD_H_DESIGN
	var bottom: float = rect.end.y
	# ① 卡面纸底：素材槽 assets/ui/card_paper.png 优先，缺图回退纯色（R113 起可换皮）
	var paper: Texture2D = UiAssets.card_paper()
	if paper != null:
		canvas.draw_texture_rect(paper, rect, false)
	else:
		canvas.draw_rect(rect, UiTheme.SURFACE)
	# ② 选中态：**外发光**，不占用边框颜色（边框是稀有度的唯一通道，见 UI设计规范 §规则 5）
	if selected:
		for gi in 3:
			var glow := UiTheme.SELECT_RING
			glow.a = 0.42 - 0.11 * gi
			canvas.draw_rect(rect.grow(1.0 + gi), glow, false, 1.0)
	# ③ 边框：素材槽 assets/ui/frame_<稀有度>.png 优先，缺图回退色描边
	var frame_tex: Texture2D = UiAssets.card_frame(card.rarity)
	if frame_tex != null:
		canvas.draw_texture_rect(frame_tex, rect, false)
	else:
		canvas.draw_rect(rect, card.rarity_color(), false, 2.0 if selected else 1.5)
	# 费用圆
	var cost_r := 7.0 * k
	var cost_c := rect.position + Vector2(cost_r + 3, cost_r + 3)
	canvas.draw_circle(cost_c, cost_r, UiTheme.COST_BG)
	# X 费卡（流星雨 9083）：费用不是定值 → 费用圆直接画「X」
	var cost_txt: String = "X" if card.x_cost else str(card.cost)
	_draw_center(canvas, font_bold, roundi(UiTheme.CARD_FS_TEXT * k), cost_txt, cost_c,
			UiTheme.SURFACE)
	# 种类 + 数值：力量在左下（黄）、生命在右下（红），射程/速度收成中间一行
	var kind_col: Color = UiTheme.kind_color(card.kind)
	var is_unit: bool = card.kind == "盟友" or card.kind == "工事"
	# 插图区（横置的卡放不下）
	if not is_tapped:
		var art_box := Rect2(rect.position.x + 4 * k, rect.position.y + 16 * k,
				rect.size.x - 8 * k, rect.size.y - 48.0 * k)
		if art_box.size.y >= 12:
			var tex := art_for(card.id)
			if tex != null:
				canvas.draw_texture_rect(tex, fit_rect(tex.get_size(), art_box), false)
			else:
				# 无图回退（R113 批 3）：卡库 198 张只有 15 张有图，绝大多数卡原本是**一片白**。
				# 改成「按卡种着色的淡底纹 + 首字水印」——留下信息（这是什么卡）而不是留白。
				var plate := kind_col
				plate.a = 0.13
				canvas.draw_rect(art_box, plate)
				var mark := card.card_name.substr(0, 1)
				var glyph := kind_col
				glyph.a = 0.34
				_draw_center(canvas, font_bold, int(art_box.size.y * 0.86), mark,
						art_box.get_center(), glyph)
	# 名字
	var nm := card.card_name if card.card_name.length() <= 6 else card.card_name.substr(0, 5) + "…"
	_draw_center(canvas, font_bold, roundi(UiTheme.CARD_FS_TEXT * k), nm,
			rect.position + Vector2(rect.size.x / 2, 12 * k), UiTheme.INK_900)
	var cx := rect.position.x + rect.size.x / 2
	if is_unit:
		_draw_center(canvas, font, roundi(UiTheme.CARD_FS_TEXT * k), card.kind,
				Vector2(cx, bottom - 28 * k), kind_col)
		var sub: String = "程%d 速%d" % [card.attack_range, card.move_speed] \
				if card.kind == "盟友" else "程%d" % card.attack_range
		_draw_center(canvas, font, roundi(UiTheme.CARD_FS_TEXT * k), sub,
				Vector2(cx, bottom - 19 * k), UiTheme.INK_500)
		var shown_power: int = power_override if power_override >= 0 else card.power
		_draw_corner_stats(canvas, font, font_bold, k, rect, shown_power, hp)
	else:
		_draw_center(canvas, font, roundi(UiTheme.CARD_FS_TEXT * k), card.kind,
				Vector2(cx, bottom - 28 * k), kind_col)
		_draw_center(canvas, font, roundi(UiTheme.CARD_FS_TEXT * k), "直接使用",
				Vector2(cx, bottom - 12 * k), UiTheme.INK_600)
	# 【字段系统 R91】在插图区底与「kind」之间的空隙里追加一行字段提示。
	# ⚠️ **不硬编码任何字段**：画的就是 `card.affixes`（引擎赋给它的、或卡面自带的），
	# 所以「过载给某张牌加了疾行」「能量屏障给了护盾」这类**后续赋予**的字段
	# 也会自动出现在卡面上 —— 不需要在这里为每个字段写一行 if。
	# 战场单位另有更醒目的**上方徽标**（battle_scene 的 `_draw_affix_badges`）。
	if not card.affixes.is_empty():
		var line: String = card.affix_line()
		# 太长就截断并补「+N」（字段最多 5 个，但名字长短不一）
		var maxw: float = rect.size.x - 8.0 * k
		while line.length() > 2 and font.get_string_size(line + "…",
				HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(UiTheme.CARD_FS_TEXT * k)).x > maxw:
			line = line.substr(0, line.length() - 1)
		if card.affix_line() != line:
			line += "…"
		_draw_center(canvas, font, roundi(UiTheme.CARD_FS_TEXT * k), line,
				Vector2(cx, bottom - 37 * k), UiTheme.STAT_POWER)


static func _draw_corner_stats(canvas: CanvasItem, font: Font, font_bold: Font,
		k: float, rect: Rect2, power: int, hp: int) -> void:
	## 单位数值角标：左下「力N」金黄、右下「生N」红 —— 大号加粗，一眼可分。
	var base_y := rect.end.y - 5.0 * k
	_stat_corner(canvas, font, font_bold, k, rect, "力", power, UiTheme.STAT_POWER, base_y, false)
	_stat_corner(canvas, font, font_bold, k, rect, "生", hp, UiTheme.STAT_HEALTH, base_y, true)


static func _stat_corner(canvas: CanvasItem, font: Font, font_bold: Font, k: float,
		rect: Rect2, label: String, value: int, col: Color, base_y: float, right: bool) -> void:
	## 角标绘制：小号「力/生」标签 + 大号加粗数值，同基线排布（右下角右对齐）。
	var sz_l := roundi(UiTheme.CARD_FS_TEXT * k)
	var sz_v := roundi(UiTheme.CARD_FS_VALUE * k)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz_l).x
	var vw := font_bold.get_string_size(str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, sz_v).x
	var x0 := rect.end.x - 5.0 * k - lw - vw if right else rect.position.x + 5.0 * k
	canvas.draw_string(font, Vector2(x0, base_y), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, sz_l, col)
	canvas.draw_string(font_bold, Vector2(x0 + lw, base_y), str(value),
			HORIZONTAL_ALIGNMENT_LEFT, -1, sz_v, col)


static func stats_line(card: CardData, hp := -1) -> String:
	## 详情面板用的一行数值描述（hp<0 时用卡面生命）。
	var shown := hp if hp >= 0 else card.health
	match card.kind:
		"盟友":
			return "力量 %d   生命 %d   射程 %d   速度 %d" % [
				card.power, shown, card.attack_range, card.move_speed]
		"工事":
			return "力量 %d   生命 %d   射程 %d" % [card.power, shown, card.attack_range]
		"技能":
			return "直接使用"
		"效果":
			return "在效果区持续生效"
	return ""


static func wrap_text(font: Font, text: String, max_w: float, size: int) -> Array[String]:
	## 中文友好的字符级换行（draw_string 不自动折行）——按逐字累加测量宽度。
	## ⚠️ 折行点上的空格**留在上一行、不要带到新行首**：否则续行会比首行缩进一格，
	## 看上去就是「说明文字错位」。典型例子（道具「叠加态的鸭」）：
	##   `…概率永久降低 25%（100 → 75 → 50`
	##   ` → 25 → 0），降到 0 后不再复活。`   ← 这行原来行首多一个空格
	var out: Array[String] = []
	for para in text.split("\n"):
		var cur := ""
		for ch in para:
			if cur == "" and ch == " ":
				continue          # 行首不留空格（折行处吃掉那个空格）
			if font.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w \
					and cur != "":
				out.append(cur)
				cur = "" if ch == " " else ch
			else:
				cur += ch
		out.append(cur)
	return out


static func _draw_center(canvas: CanvasItem, font: Font, size: int, text: String,
		center: Vector2, col: Color) -> void:
	# width=-1 时 draw_string 的居中参数不生效（文字从 pos 向右排），
	# 必须给定显式宽度并以 center 为中点。
	var w := maxf(size * text.length() * 1.2, 40.0)
	canvas.draw_string(font, center + Vector2(-w / 2.0, size * 0.36), text,
			HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
