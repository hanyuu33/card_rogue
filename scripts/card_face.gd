class_name CardFace
## 卡面绘制共享工具 —— battle_scene（小卡）与图鉴（大卡）共用同一套视觉。
##
## 全部为静态方法：接收 CanvasItem 与两套字体，无实例状态。
##
## ## 卡面版式（R114：上半卡图 / 下半文字 / 数值以徽章「挂在框上」）
##
##              ①
##     ┌─────────────────────────┐
##     │         ← 卡图 →         │  ① 卡图区 = 卡片高度的 CARD_ART_RATIO（0.50）
##     ├─────────────────────────┤  ← 卡图 / 文字 的分界线
##     │          卡名            │  ② 文字区：卡名 → 种类·字段 → 效果文字
##     │        种类 · 字段        │
##     │     效果文字（可折行）…   │
##     └─────────────────────────┘
##          ②   ③        ④   ⑤
##
## ①费用在**左上角**、②力 ③程 在**下边缘左侧**、④生 ⑤速 在**下边缘右侧**。
## ⚠️ 每个徽章的**圆心就落在卡框上** —— 一半在卡内、一半露在卡外。
##   这不是装饰偏好：**这样才能把卡片内部完整让给卡图与文字**。
##   代价是容器必须让出 UiTheme.CARD_BLEED，否则徽章会骑到邻卡身上。
##
## 徽章 = **图标为底 + 数字压在图标上**。图标素材走 `assets/ui/icon_*.png`：
##   剑=力量 / 弓=攻击距离 / 鞋=移动距离 / 血=生命 / 水晶=费用
## 缺图时回退成该数值的**语义色圆盘 + 数字**（永远不空白、不报错）。
## 位置固定：左上=费用、左下=力量·攻击距离、右下=生命·移动距离。

const UiTheme = preload("res://scripts/ui_theme.gd")

const CARD_H_DESIGN := 70.0   # 缩放基准高（battle 版小卡高）

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


# ──────────────────────────────────────────────────────────────────────
# 版式几何（对外暴露：调用方要往卡上叠自己的角标时，必须读这里，
# 否则改了版式那些叠加层就会错位 —— battle_scene 的动态减费就是这么接的）
# ──────────────────────────────────────────────────────────────────────

static func scale_of(rect: Rect2) -> float:
	## 卡片缩放比 k（1.0 = 战场小卡 58×70，1.7 = 手牌，3.7 = 奖励大卡）。
	return rect.size.y / CARD_H_DESIGN


static func ui_scale_of(rect: Rect2) -> float:
	## 徽章 / 装饰的缩放：等于 k 但**封顶**（`CARD_BADGE_SCALE_CAP`）。
	## 大卡上徽章若跟着 k 线性长，会变成几个巨球抢掉卡图的戏。
	return minf(scale_of(rect), UiTheme.CARD_BADGE_SCALE_CAP)


static func badge_radius(rect: Rect2) -> float:
	return UiTheme.CARD_BADGE_R * ui_scale_of(rect)


static func badge_font(rect: Rect2) -> int:
	return maxi(7, roundi(UiTheme.CARD_FS_BADGE * ui_scale_of(rect)))


static func cost_badge_center(rect: Rect2) -> Vector2:
	## 左上费用徽章的圆心 = **卡片的左上角**（圆心压在框线上，一半露在框外）。
	## battle_scene 的「动态减费」要在同位置重画绿色数字，所以这里对外暴露 ——
	## 它是费用徽章位置的**唯一口**。
	return rect.position


static func text_zone_bottom(rect: Rect2) -> float:
	## 文字区下界 = 底部徽章的**内半圈**上沿（圆心在卡框上，只侵入卡片一个半径）。
	## 徽章不再占用卡片内部空间，所以这一版比初版多了约 1.5R 的文字高度。
	return rect.end.y - badge_radius(rect)


# ──────────────────────────────────────────────────────────────────────

static func draw(canvas: CanvasItem, card: CardData, rect: Rect2, hp: int,
		selected: bool, is_tapped: bool, font: Font, font_bold: Font,
		power_override := -1) -> void:
	## 卡面一律按 rect **完整排版**，与图鉴/战场小卡同一套比例，没有「按可见高度重锚」
	## 之类的特例 —— 手牌卡底沉出窗口下沿时，被挡住的那截就让它挡住
	## （作者口径：卡片是一个整体，排版要与正常状态完全一致，别为了躲裁剪挪数值）。
	var k := rect.size.y / CARD_H_DESIGN
	var kc: float = minf(k, UiTheme.CARD_BADGE_SCALE_CAP)
	var kt: float = minf(k, UiTheme.CARD_TEXT_SCALE_CAP)
	var pad: float = UiTheme.CARD_PAD * k
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
	# ④ 卡图区（上半）
	_draw_art(canvas, card, rect, k, pad, is_tapped, font_bold)
	# ⑤ 卡图与文字区的分隔线
	var sep_y: float = rect.position.y + rect.size.y * UiTheme.CARD_ART_RATIO
	canvas.draw_line(Vector2(rect.position.x + pad * 0.5, sep_y),
			Vector2(rect.end.x - pad * 0.5, sep_y), UiTheme.INK_300, maxf(1.0, 0.6 * k))
	# ⑥ 文字区（下半）
	_draw_text_zone(canvas, card, rect, kt, k, pad, sep_y, hp, font, font_bold)
	# ⑦ 数值徽章 —— 最后画，压在卡图与文字之上（「额外挂载」的字面意思）
	_draw_badges(canvas, font_bold, card, rect, k, kc, hp, power_override)


static func _draw_art(canvas: CanvasItem, card: CardData, rect: Rect2, k: float, pad: float,
		is_tapped: bool, font_bold: Font) -> void:
	## 卡图区 = 卡片的**上半部分**（R114 起。此前是「顶部让出名字行、底部让出三行数值」，
	## 58×70 的小卡只剩 50×22 的窄条，卡图几乎是装饰）。
	var art_h: float = rect.size.y * UiTheme.CARD_ART_RATIO - pad
	var box := Rect2(rect.position + Vector2(pad, pad),
			Vector2(rect.size.x - pad * 2.0, art_h))
	if box.size.x < 6.0 or box.size.y < 6.0:
		return
	if is_tapped:
		# 横置（本回合已行动）：卡图**压暗保留**。此前是直接不画，上半张变成一片空白，
		# 玩家反而更难认出「躺在场上的是哪张卡」。
		var dim := Color(1, 1, 1, 0.26)
		var tapped_tex := art_for(card.id)
		if tapped_tex != null:
			canvas.draw_texture_rect(tapped_tex, fit_rect(tapped_tex.get_size(), box), false, dim)
		else:
			var tc: Color = UiTheme.kind_color(card.kind)
			tc.a = 0.05
			canvas.draw_rect(box, tc)
		return
	var tex := art_for(card.id)
	if tex != null:
		canvas.draw_texture_rect(tex, fit_rect(tex.get_size(), box), false)
	else:
		# 无图回退（R113 批 3）：卡库 198 张只有 15 张有图，绝大多数卡原本是**一片白**。
		# 改成「按卡种着色的淡底纹 + 首字水印」——留下信息（这是什么卡）而不是留白。
		var kind_col: Color = UiTheme.kind_color(card.kind)
		var plate := kind_col
		plate.a = 0.13
		canvas.draw_rect(box, plate)
		var glyph := kind_col
		glyph.a = 0.34
		_draw_center(canvas, font_bold, int(box.size.y * 0.86), card.card_name.substr(0, 1),
				box.get_center(), glyph)


static func _draw_text_zone(canvas: CanvasItem, card: CardData, rect: Rect2, kt: float,
		k: float, pad: float, sep_y: float, hp: int, font: Font, font_bold: Font) -> void:
	## 文字区（下半）：**卡名 → 种类 · 字段 → 效果文字**，按这个优先级往下排，
	## 排不下的整块省略。
	##
	## ⚠️ 「种类」与「字段」**合并成一行**（`盟友 · 迅捷`）—— 分成两行的话，
	## 58×70 / 98×119 这类尺寸上光是这两行就把文字区吃光，效果文字永远轮不到。
	## ⚠️ 效果文字**只在排得下完整一行时**才画 —— 小卡上排「半行字 + 省略号」比不排
	## 更难看，而且玩家根本读不到信息。
	var bottom: float = text_zone_bottom(rect)
	var top: float = sep_y + maxf(1.5, 1.2 * kt)
	if bottom - top < 6.0:
		return
	var sz: int = maxi(7, roundi(UiTheme.CARD_FS_TEXT * kt))
	var cx: float = rect.position.x + rect.size.x / 2.0
	var maxw: float = rect.size.x - pad * 2.0
	var kind_col: Color = UiTheme.kind_color(card.kind)
	# 卡名（粗体、墨色）
	var y: float = top + sz * 0.88
	_draw_center(canvas, font_bold, sz, _ellipsize(font_bold, card.card_name, maxw, sz),
			Vector2(cx, y), UiTheme.INK_900)
	# 种类 · 字段（一行两段，分别着色；整体居中）
	# ⚠️ 不硬编码任何字段：画的就是 `card.affix_line()`，所以「过载给某张牌加了疾行」
	# 这类**后续赋予**的字段也会自动出现在卡面上。
	y += sz * 1.12
	if y + sz * 0.25 > bottom:
		return
	var meta_a: String = card.kind
	var meta_b: String = (" · " + card.affix_line()) if not card.affixes.is_empty() else ""
	var wa: float = font.get_string_size(meta_a, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var wb: float = font.get_string_size(meta_b, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	# ⚠️⚠️ 这里踩过一个**让整个游戏未响应**的坑，改这一行前务必读完：
	#   起初写的是 `meta_b = meta_b.substr(0, meta_b.length() - 1) + "…"` ——
	#   去掉最后一个字符再补一个 `…`，**长度恒定不变**；而且末位一旦是 `…`，
	#   下一轮会得到**完全相同的字符串**（末位被换成 `…`，再砍一位又补回 `…`）。
	#   于是只要「种类 + 长字段」一开始就超宽，这个循环**永远退不出来**。
	#   它在 `_draw()` 里 → 整帧不返回 → 游戏直接未响应。图鉴会画全部 198 张卡
	#   （里面有带字段的），所以必中、必卡死，表现为「一打开就卡住」。
	#   两条保险：① 每次砍 **2** 个字符（长度严格递减）；② 再加一个硬上限兜底
	#   —— 绘制代码里的循环**绝不允许**只依赖「条件终将不成立」来退出。
	var meta_guard := 0
	while meta_b != "" and wa + wb > maxw and meta_b.length() > 2 and meta_guard < 64:
		meta_b = meta_b.substr(0, meta_b.length() - 2) + "…"
		wb = font.get_string_size(meta_b, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		meta_guard += 1
	var mx: float = cx - (wa + wb) / 2.0
	canvas.draw_string(font, Vector2(mx, y), meta_a,
			HORIZONTAL_ALIGNMENT_LEFT, -1, sz, kind_col)
	if meta_b != "":
		canvas.draw_string(font, Vector2(mx + wa, y), meta_b,
				HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UiTheme.STAT_POWER)
	# 效果文字（左对齐折行）。空文本 / 排不下则整块跳过。
	var eff: String = CardText.naturalize(card.effect_text).replace("\n", " ").strip_edges()
	if eff == "":
		return
	var line_h: float = sz * 1.16
	var eff_top: float = y + sz * 0.42
	var lines_fit: int = int(floor((bottom - eff_top) / line_h))
	if lines_fit < 1:
		return
	var lines := wrap_text(font, eff, maxw, sz)
	var draw_n: int = mini(lines.size(), lines_fit)
	var ly: float = eff_top + sz * 0.80
	for i in draw_n:
		var t: String = lines[i]
		if i == draw_n - 1 and lines.size() > draw_n:
			t = _ellipsize(font, t + "…", maxw, sz)
		canvas.draw_string(font, Vector2(rect.position.x + pad, ly), t,
				HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UiTheme.INK_600)
		ly += line_h


static func _draw_badges(canvas: CanvasItem, font_bold: Font, card: CardData, rect: Rect2,
		k: float, kc: float, hp: int, power_override: int) -> void:
	## 数值徽章（额外挂载）。位置固定，与卡片种类无关的部分永远在同一处 ——
	## 玩家的眼睛只需要记一次坐标。
	var r: float = UiTheme.CARD_BADGE_R * kc
	var gap: float = UiTheme.CARD_BADGE_GAP * kc
	var fs: int = maxi(7, roundi(UiTheme.CARD_FS_BADGE * kc))
	# ── 左上角：费用（水晶）—— 圆心压在卡框左上角上 ──
	# X 费卡（流星雨 9083）：费用不是定值 → 徽章上直接画「X」
	_badge(canvas, font_bold, cost_badge_center(rect), r, fs, "cost",
			"X" if card.x_cost else str(card.cost), UiTheme.BADGE_COST)
	# 技能 / 效果卡没有攻防数值，只有费用
	var is_unit: bool = card.kind == "盟友"
	if not is_unit and card.kind != "工事":
		return
	# ── 底部一排：圆心落在卡片**下边缘**上（一半挂在卡外）──
	# 最外侧两张贴住卡的左右边（圆心距边一个半径），四张都在卡宽范围内 →
	# 横向不外溢，只有纵向露出去一个半径。
	var bar_y: float = rect.end.y
	var power_x: float = rect.position.x + r
	var range_x: float = power_x + 2.0 * r + gap
	var speed_x: float = rect.end.x - r
	var health_x: float = speed_x - 2.0 * r - gap
	# ── 左下：力量（剑） + 攻击距离（弓）──
	var shown_power: int = power_override if power_override >= 0 else card.power
	_badge(canvas, font_bold, Vector2(power_x, bar_y), r, fs, "power",
			str(shown_power), UiTheme.BADGE_POWER)
	_badge(canvas, font_bold, Vector2(range_x, bar_y), r, fs, "range",
			str(card.attack_range), UiTheme.BADGE_RANGE)
	# ── 右下：生命（血） + 移动距离（鞋；工事不会移动，不画）──
	# ⚠️ 顺序与左下组保持**同一阅读方向**（力 程 → 生 速）。
	# 先前按「离卡角最近的是第一个」做成镜像（力 程 速 生），出图一看就读反了 ——
	# 两组之间「先读到的那个」忽左忽右，比单纯难看更糟：会读错数值。
	# 工事没有移速 → 生命直接占最外侧那张（贴右边）。
	if is_unit:
		_badge(canvas, font_bold, Vector2(health_x, bar_y), r, fs, "health",
				str(hp), UiTheme.BADGE_HEALTH)
		_badge(canvas, font_bold, Vector2(speed_x, bar_y), r, fs, "speed",
				str(card.move_speed), UiTheme.BADGE_SPEED)
	else:
		_badge(canvas, font_bold, Vector2(speed_x, bar_y), r, fs, "health",
				str(hp), UiTheme.BADGE_HEALTH)


static func _badge(canvas: CanvasItem, font_bold: Font, center: Vector2, r: float, fs: int,
		key: String, value: String, disc: Color) -> void:
	## 单个数值徽章：**图标为底、数字压在图标上**。
	## 缺图标素材 → 回退成该数值的语义色圆盘 + 数字（信息不丢、观感不塌）。
	##
	## 数字按宽度自适应缩号：三位数（如鸭之暗面的 150 血）在 58px 小卡的 12px 圆上
	## 必然顶出圆盘，缩到刚好放得下为止；缩到 6px 仍是极限就让它略微出格
	## （宁可略宽也不缩成看不出来的小点）。
	var icon: Texture2D = UiAssets.badge_icon(key)
	if icon != null:
		canvas.draw_circle(center, r, UiTheme.BADGE_BACK)
		canvas.draw_texture_rect(icon, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false)
	else:
		canvas.draw_circle(center, r, disc)
		canvas.draw_arc(center, r, 0.0, TAU, 20, disc.darkened(0.34),
				maxf(1.0, r * 0.16), true)
	var sz: int = fs
	while sz > 6 and font_bold.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x \
			> r * 1.75:
		sz -= 1
	# **数字一律描边**（不只是有图标时）：
	#   · 有图标：图标可能是花哨插画，不描边压不住；
	#   · 无图标：语义色圆盘只有 12k 直径，两位/三位数必然会溢出圆盘边缘
	#     （鸭之暗面 150 血、铁壁卫兵 30 血），溢出后白字落在白卡面上＝看不见。
	# 描边让「数字出格」从缺陷降级成可接受的排版。
	_draw_center_outlined(canvas, font_bold, sz, value, center, UiTheme.BADGE_VALUE)


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


static func _ellipsize(font: Font, text: String, max_w: float, size: int) -> String:
	## 超宽就截断并补「…」；**没超宽时原样返回**（别给短文本平白加省略号）。
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
		return text
	var t := text
	while t.length() > 1 and font.get_string_size(t + "…",
			HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		t = t.substr(0, t.length() - 1)
	return t + "…"


static func _draw_center(canvas: CanvasItem, font: Font, size: int, text: String,
		center: Vector2, col: Color) -> void:
	# width=-1 时 draw_string 的居中参数不生效（文字从 pos 向右排），
	# 必须给定显式宽度并以 center 为中点。
	var w := maxf(size * text.length() * 1.2, 40.0)
	canvas.draw_string(font, center + Vector2(-w / 2.0, size * 0.36), text,
			HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


static func _draw_center_outlined(canvas: CanvasItem, font: Font, size: int, text: String,
		center: Vector2, col: Color) -> void:
	## 有图标素材时数字压在图上，而图标可能是花哨的插画 → 先描一圈深色再填字，
	## 保证**任何素材**上数字都能读（素材是玩家往后自己换的，不能假设它够素）。
	var o: float = maxf(0.8, size * 0.18)
	for d: Vector2 in [Vector2(-o, 0), Vector2(o, 0), Vector2(0, -o), Vector2(0, o)]:
		_draw_center(canvas, font, size, text, center + d, UiTheme.BADGE_OUTLINE)
	_draw_center(canvas, font, size, text, center, col)
