class_name TrapArt
extends RefCounted
## R663：陷阱图标的**唯一绘制口**。
## 美术定稿权在店长：现在没有 trap_icon_<id>.png，所以先走程序化图案兜底；
## 一旦 assets/ui/trap_icon_<id>.png 落盘，这里自动改用贴图，界面代码一行都不用动。
## 战斗槽 / 地图槽 / 商店格 / 战场格标记都调这里，四处的样子永远一致。
## R667：栏位底板的贴图口（trap_slot / trap_bar_battle / trap_group_tag）收在这里，
## 战斗与地图共用同一张竖栏底，不再按场景分版。
## R669：触发瞬间的发光特效图也收在这里（assets/fx/trap_fx_<id>.png）。
## 一律「有图贴图、缺图返回 false 让调用方继续程序化绘制」。


static func color_of(id: int) -> Color:
	match id:
		7001: return Color(0.93, 0.44, 0.20)   # 炼金炸弹 · 橙红
		7002: return Color(0.42, 0.79, 0.96)   # 冰冻陷阱 · 冰蓝
		7003: return Color(0.52, 0.83, 0.35)   # 毒瓶 · 毒绿
		7004: return Color(0.74, 0.59, 0.94)   # 穿刺陷阱 · 钢紫
		7005: return Color(0.92, 0.36, 0.44)   # 小血瓶 · 血红
		7006: return Color(0.36, 0.62, 0.95)   # 法力药剂 · 费用蓝
		7007: return Color(0.88, 0.53, 0.24)   # 烤肉 · 焦糖橙
		7008: return Color(0.76, 0.55, 0.30)   # 野性图腾 · 木赭
		7009: return Color(0.74, 0.53, 0.96)   # 万能牌 · 幻紫
		7010: return Color(0.96, 0.72, 0.28)   # 快送鸭 · 快递黄
		7011: return Color(0.42, 0.82, 0.78)   # 神秘牌 · 谜青
		7012: return Color(0.68, 0.66, 0.62)   # 石头 · 石灰
		7013: return Color(0.86, 0.68, 0.42)   # 卡牌包 · 牛皮纸
		7014: return Color(0.58, 0.72, 0.98)   # 智慧药剂 · 智慧蓝
	return Color(0.80, 0.76, 0.66)


static func draw_bar_bg(ci: CanvasItem, rect: Rect2) -> bool:
	var tex: Texture2D = UiAssets.trap_bar_bg()
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect, false, Color(1, 1, 1, 0.92))
	return true


static func draw_slot_frame(ci: CanvasItem, rect: Rect2) -> bool:
	var tex: Texture2D = UiAssets.trap_slot_frame()
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect, false)
	return true


static func draw_group_tag(ci: CanvasItem, rect: Rect2) -> bool:
	var tex: Texture2D = UiAssets.trap_group_tag()
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect, false)
	return true


static func draw_trigger_fx(ci: CanvasItem, rect: Rect2, id: int, alpha: float) -> bool:
	## R669：触发瞬间的素材图演出（店长口径「不要文字特效，用素材图做」）。
	## 有图贴图、缺图返回 false，让调用方退回程序化的纯色扩散光环。
	var tex: Texture2D = UiAssets.trap_fx(id)
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect, false, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))
	return true


static func draw(ci: CanvasItem, rect: Rect2, id: int, dim := false) -> void:
	var tex: Texture2D = UiAssets.trap_icon(id)
	if tex != null:
		ci.draw_texture_rect(tex, rect, false,
				Color(0.55, 0.55, 0.58, 0.90) if dim else Color.WHITE)
		return
	var base := color_of(id)
	if dim:
		base = Color(0.42, 0.42, 0.45, 0.85)
	var ink := Color(minf(1.0, base.r * 0.42 + 0.10), minf(1.0, base.g * 0.42 + 0.10),
			minf(1.0, base.b * 0.42 + 0.10), 1.0)
	ci.draw_rect(rect, Color(0.07, 0.08, 0.11, 0.90), true)
	ci.draw_rect(rect.grow(-maxf(2.0, rect.size.x * 0.045)), base, false,
			maxf(2.0, rect.size.x * 0.045))
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	match id:
		7001: _bomb(ci, c, s, ink)
		7002: _frost(ci, c, s, ink)
		7003: _poison(ci, c, s, ink)
		7004: _spike(ci, c, s, ink)
		7005: _potion(ci, c, s, ink, false)
		7006: _potion(ci, c, s, ink, true)
		7007: _meat(ci, c, s, ink)
		7008: _totem(ci, c, s, ink)
		7009: _wildcard(ci, c, s, ink)
		7010: _deliver(ci, c, s, ink)
		7011: _mystery(ci, c, s, ink)
		7012: _stone(ci, c, s, ink)
		7013: _cardpack(ci, c, s, ink)
		7014: _wisdom(ci, c, s, ink)
		_: ci.draw_circle(c, s * 0.22, ink)


static func _bomb(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.035)
	ci.draw_circle(c, s * 0.19, col)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * s * 0.25, c + d * s * 0.37, col, w, true)
	ci.draw_line(c + Vector2(s * 0.11, -s * 0.16), c + Vector2(s * 0.24, -s * 0.31), col, w, true)
	ci.draw_circle(c + Vector2(s * 0.25, -s * 0.32), s * 0.045, col)


static func _frost(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.030)
	for k in 3:
		var a := PI * float(k) / 3.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c - d * s * 0.32, c + d * s * 0.32, col, w, true)
		for sgn in [-1.0, 1.0]:
			var p: Vector2 = c + d * s * 0.21 * sgn
			var side := Vector2(-d.y, d.x)
			ci.draw_line(p, p + (d - side) * s * 0.10 * sgn, col, w * 0.8, true)
			ci.draw_line(p, p + (d + side) * s * 0.10 * sgn, col, w * 0.8, true)


static func _poison(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var drop := PackedVector2Array([
		c + Vector2(-s * 0.10, -s * 0.10), c + Vector2(s * 0.10, -s * 0.10),
		c + Vector2(0.0, -s * 0.37)])
	ci.draw_colored_polygon(drop, col)
	ci.draw_circle(c + Vector2(0.0, s * 0.07), s * 0.21, col)
	ci.draw_circle(c + Vector2(-s * 0.10, s * 0.02), s * 0.045, Color(0.10, 0.12, 0.10, 0.85))
	ci.draw_circle(c + Vector2(s * 0.11, s * 0.13), s * 0.035, Color(0.10, 0.12, 0.10, 0.85))


static func _spike(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.035)
	for k in [-1, 0, 1]:
		var x := c.x + float(k) * s * 0.19
		var tri := PackedVector2Array([
			Vector2(x - s * 0.075, c.y + s * 0.27),
			Vector2(x + s * 0.075, c.y + s * 0.27),
			Vector2(x, c.y - s * 0.30)])
		ci.draw_colored_polygon(tri, col)
	ci.draw_line(Vector2(c.x - s * 0.32, c.y + s * 0.29),
			Vector2(c.x + s * 0.32, c.y + s * 0.29), col, w, true)


static func _meat(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R743：烤肉（使用型）—— 一只**带骨的肉腿**：圆肉球 + 斜伸出去的米白骨头。
	## 前两版是「梯形肉块 + 横骨头」，缩到 40px 的槽位里分别读成「托盘」和「箱子」——
	## 方块形状在这么小的尺寸上撑不住。肉腿的轮廓（圆 + 一根斜骨）是这个尺寸下
	## 最稳的「肉」符号，也和小血瓶 / 法力药剂的瓶子语汇同属「画实物」那一类。
	var w := maxf(1.5, s * 0.032)
	var bone_col := col.lightened(0.58)
	# 骨头：从肉球右下角斜伸出去，末端一个骨节
	var b1 := c + Vector2(s * 0.36, s * 0.32)
	ci.draw_line(c + Vector2(s * 0.10, s * 0.08), b1, bone_col, w * 2.8, true)
	ci.draw_circle(b1, s * 0.078, bone_col)
	# 肉：圆球（略偏左上），下沿盖住骨头根部
	ci.draw_circle(c + Vector2(-s * 0.07, -s * 0.06), s * 0.28, col)
	# 高光（一点暖白，给出「烤出油光」的质感）
	ci.draw_circle(c + Vector2(-s * 0.16, -s * 0.16), s * 0.075, col.lightened(0.38))


static func _totem(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R745：野性图腾（使用型）—— 一根立着的图腾柱：柱身 + 顶部两片张开的羽毛 + 一对兽眼。
	## 与药瓶 / 烤肉同一套语汇（画「是什么东西」）。小尺寸下靠「竖条 + 顶部张开的翼形」
	## 读成图腾柱；柱身走**描边**、羽毛与基座走填充，才有层次，不然缩到 40px 是个黑方块。
	var w := maxf(1.5, s * 0.032)
	var dark := Color(0.10, 0.09, 0.11, 0.78)
	# 顶部羽毛：左右各一片斜出去的三角
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.07, -s * 0.31), c + Vector2(-s * 0.37, -s * 0.15),
		c + Vector2(-s * 0.09, -s * 0.13)]), col)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(s * 0.07, -s * 0.31), c + Vector2(s * 0.37, -s * 0.15),
		c + Vector2(s * 0.09, -s * 0.13)]), col)
	# 柱身（描边，露出里面的「雕刻」）
	ci.draw_rect(Rect2(c.x - s * 0.11, c.y - s * 0.30, s * 0.22, s * 0.57), col, false, w)
	# 基座（略宽，填充满）
	ci.draw_rect(Rect2(c.x - s * 0.17, c.y + s * 0.22, s * 0.34, s * 0.09), col, true)
	# 兽眼
	ci.draw_circle(c + Vector2(-s * 0.048, -s * 0.02), s * 0.030, col)
	ci.draw_circle(c + Vector2(s * 0.048, -s * 0.02), s * 0.030, col)
	# 刻线（柱身横向纹路）
	ci.draw_line(c + Vector2(-s * 0.11, s * 0.10), c + Vector2(s * 0.11, s * 0.10),
			dark, maxf(1.2, w * 0.8), true)


static func _wildcard(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R752：万能牌（使用型）—— 一张立着的牌 + 中央八角星芒。
	## 「万能」在卡牌语汇里就是这颗星标（王牌 / 百搭），比画一个「W」之类的字更跨语言。
	## 与药瓶 / 烤肉同一套「画实物」的路子；有 `trap_icon_7009.png` 时整段都不走。
	var w := maxf(1.5, s * 0.032)
	ci.draw_rect(Rect2(c.x - s * 0.20, c.y - s * 0.29, s * 0.40, s * 0.58), col, false, w)
	var d := s * 0.115
	var star := PackedVector2Array([
		c + Vector2(0.0, -d * 1.75), c + Vector2(d * 0.38, -d * 0.38),
		c + Vector2(d * 1.75, 0.0), c + Vector2(d * 0.38, d * 0.38),
		c + Vector2(0.0, d * 1.75), c + Vector2(-d * 0.38, d * 0.38),
		c + Vector2(-d * 1.75, 0.0), c + Vector2(-d * 0.38, -d * 0.38)])
	ci.draw_colored_polygon(star, col)


static func _deliver(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R752：快送鸭（使用型）—— 一只快递纸箱 + 上方向上的箭头。
	## 鸭子本身在 45px 里画不成形（R745 图腾那一轮的教训：小尺寸只留得住**结构**），
	## 所以缺图兜底走「箱子 + 箭头」这个更稳的「送到你手上」符号；正式素材仍然是鸭子。
	var w := maxf(1.5, s * 0.032)
	# 箱身
	ci.draw_rect(Rect2(c.x - s * 0.23, c.y - s * 0.06, s * 0.46, s * 0.31), col, false, w)
	# 箱盖（一条横线 + 中间竖缝）
	ci.draw_line(Vector2(c.x - s * 0.23, c.y + s * 0.05),
			Vector2(c.x + s * 0.23, c.y + s * 0.05), col, w, true)
	ci.draw_line(Vector2(c.x, c.y - s * 0.06), Vector2(c.x, c.y + s * 0.05), col, w, true)
	# 向上的箭头（「送上去 / 送到」）
	ci.draw_line(Vector2(c.x, c.y - s * 0.14), Vector2(c.x, c.y - s * 0.34), col, w, true)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - s * 0.40), Vector2(c.x - s * 0.10, c.y - s * 0.26),
		Vector2(c.x + s * 0.10, c.y - s * 0.26)]), col)


static func _mystery(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R752：神秘牌（使用型）—— 一张立着的牌 + 中央问号（「不知道会来哪张」）。
	## 问号由「上半弧 + 短竖线 + 一点」三笔拼出来：这个尺寸下三段圆弧是能读出来的最小写法。
	var w := maxf(1.5, s * 0.032)
	ci.draw_rect(Rect2(c.x - s * 0.20, c.y - s * 0.29, s * 0.40, s * 0.58), col, false, w)
	var hc := c + Vector2(0.0, -s * 0.08)
	ci.draw_arc(hc, s * 0.115, PI * 0.92, PI * 2.28, 18, col, w, true)
	ci.draw_line(hc + Vector2(s * 0.075, s * 0.075), c + Vector2(0.0, s * 0.09),
			col, w, true)
	ci.draw_circle(c + Vector2(0.0, s * 0.175), s * 0.035, col)


static func _potion(ci: CanvasItem, c: Vector2, s: float, col: Color, mana: bool) -> void:
	## R690：使用型工具（7005 小血瓶 / 7006 法力药剂）—— 同一只药瓶，只换中央标记：
	## 血瓶画「+」十字，法力药剂画菱形（费用的形状语汇）。其余完全一致，
	## 让人一眼看出这两个是同一套东西（与 9154/9185 共用路牌外框同一条原则）。
	var w := maxf(1.5, s * 0.032)
	var dark := Color(0.07, 0.08, 0.11, 0.92)
	# 瓶塞
	ci.draw_rect(Rect2(c.x - s * 0.085, c.y - s * 0.35, s * 0.17, s * 0.085), col, true)
	# 瓶颈（描边）
	ci.draw_rect(Rect2(c.x - s * 0.065, c.y - s * 0.27, s * 0.13, s * 0.21), col, false, w)
	# 瓶身（描边 + 圆底用圆补）
	var body := Rect2(c.x - s * 0.165, c.y - s * 0.07, s * 0.33, s * 0.30)
	ci.draw_rect(body, col, false, w)
	ci.draw_arc(Vector2(c.x, c.y + s * 0.23), s * 0.165, 0.0, PI, 16, col, w, true)
	# 液体（瓶身下半）
	var liq := Rect2(c.x - s * 0.125, c.y + s * 0.03, s * 0.25, s * 0.19)
	ci.draw_rect(liq, col, true)
	# 中央标记（镂空感：液体上挖深色）
	if mana:
		var d := s * 0.072
		var dia := PackedVector2Array([
			Vector2(c.x, c.y - d), Vector2(c.x + d * 0.8, c.y),
			Vector2(c.x, c.y + d), Vector2(c.x - d * 0.8, c.y)])
		ci.draw_colored_polygon(dia, dark)
	else:
		var arm := s * 0.085
		var th := maxf(1.8, s * 0.032)
		ci.draw_line(Vector2(c.x - arm, c.y + s * 0.125),
				Vector2(c.x + arm, c.y + s * 0.125), dark, th * 1.6, true)
		ci.draw_line(Vector2(c.x, c.y + s * 0.125 - arm),
				Vector2(c.x, c.y + s * 0.125 + arm), dark, th * 1.6, true)
	# 高光
	ci.draw_line(Vector2(c.x - s * 0.10, c.y - s * 0.02),
			Vector2(c.x - s * 0.10, c.y + s * 0.09), Color(1, 1, 1, 0.45), w * 0.9, true)

static func _cardpack(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R796 卡牌包 7013：三张叠起来的卡 + 一道系带（程序化兜底；有 png 时整段不走）。
	var w := maxf(1.5, s * 0.028)
	var card := Rect2(c + Vector2(-s * 0.22, -s * 0.15), Vector2(s * 0.40, s * 0.30))
	ci.draw_rect(Rect2(card.position + Vector2(-s * 0.05, s * 0.03), card.size), col, true)
	ci.draw_rect(card, col.lightened(0.35), true)
	ci.draw_rect(card, col, false, w)
	var band := Rect2(card.position + Vector2(card.size.x * 0.42, 0),
			Vector2(card.size.x * 0.16, card.size.y))
	ci.draw_rect(band, col.darkened(0.25), true)


static func _wisdom(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R796 智慧药剂 7014：蓝药瓶 + 瓶口一颗星（「智慧」靠星点区分法力药剂）。
	var w := maxf(1.5, s * 0.032)
	var body := PackedVector2Array([
		c + Vector2(-s * 0.15, -s * 0.04),
		c + Vector2(s * 0.15, -s * 0.04),
		c + Vector2(s * 0.11, s * 0.20),
		c + Vector2(-s * 0.11, s * 0.20)])
	ci.draw_colored_polygon(body, col)
	var outline := PackedVector2Array([body[0], body[1], body[2], body[3], body[0]])
	ci.draw_polyline(outline, col.darkened(0.35), w)
	ci.draw_line(c + Vector2(0, -s * 0.04), c + Vector2(0, -s * 0.13), col, w * 1.6)
	var star := c + Vector2(s * 0.17, -s * 0.19)
	for k in 4:
		var a := TAU * float(k) / 4.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(star - d * s * 0.055, star + d * s * 0.055, col.lightened(0.45), maxf(1.2, w * 0.8))


static func _stone(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R754 石头（7012）：一块带棱角的碎石，右下角一小撮碎屑。
	## 不画成圆球 —— 圆的是「炸弹」（7001），石头要有**折线边**才认得出。
	var w := maxf(1.5, s * 0.032)
	var pts := PackedVector2Array([
		Vector2(c.x - s * 0.26, c.y + s * 0.10),
		Vector2(c.x - s * 0.17, c.y - s * 0.16),
		Vector2(c.x + s * 0.04, c.y - s * 0.25),
		Vector2(c.x + s * 0.24, c.y - s * 0.08),
		Vector2(c.x + s * 0.20, c.y + s * 0.16),
		Vector2(c.x - s * 0.06, c.y + s * 0.24)])
	ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.28))
	# 受光面（左上那一片）先铺一层更亮的底，折面才有厚度感
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - s * 0.26, c.y + s * 0.10),
		Vector2(c.x - s * 0.17, c.y - s * 0.16),
		Vector2(c.x + s * 0.04, c.y - s * 0.25),
		Vector2(c.x - s * 0.02, c.y + s * 0.06)]),
		Color(1, 1, 1, 0.10))
	# 描边（首尾闭合，逐段画才吃得到线宽）
	for i in pts.size():
		ci.draw_line(pts[i], pts[(i + 1) % pts.size()], col, w, true)
	# 内部折面：**Y 形**（一竖两撇），把平面切成三片。
	# ⚠️ 别写成「左上角 → 右下角」一条直线 —— 那样整块石头读起来像「禁止」符号
	#    （R754 实测：截图里第一眼就是禁行标志）。
	ci.draw_line(Vector2(c.x + s * 0.04, c.y - s * 0.25),
			Vector2(c.x - s * 0.02, c.y + s * 0.06), col, w * 0.8, true)
	ci.draw_line(Vector2(c.x - s * 0.02, c.y + s * 0.06),
			Vector2(c.x - s * 0.26, c.y + s * 0.10), col, w * 0.8, true)
	ci.draw_line(Vector2(c.x - s * 0.02, c.y + s * 0.06),
			Vector2(c.x + s * 0.20, c.y + s * 0.16), col, w * 0.8, true)
	# 碎屑两粒
	ci.draw_circle(Vector2(c.x + s * 0.26, c.y + s * 0.30), s * 0.038, col)
	ci.draw_circle(Vector2(c.x + s * 0.13, c.y + s * 0.34), s * 0.026, col)

