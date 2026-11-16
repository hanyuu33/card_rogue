class_name StatusBadge
extends RefCounted
## R770c：说明类飘字的**艺术字徽标**（图案 + 立体字），绘制与几何的唯一口。
##
## 店长口径：「还是不好看，能不能做成类似艺术字的样子最好带点图，比如冰封文字上带点冰」。
## R770b 那版只是「深色胶囊 + 描边字」—— 形状干净，但没有信息、没有性格，
## 看久了仍像一条提示条。这一版给每个常见状态配一个**矢量图案**（不依赖素材，
## 任意尺寸都清晰），字本身也做成三层立体（厚度 + 描边 + 顶高光）。
##
## 分工：
##   * 关键词 → 图案：`glyph_of()`，只做字符串匹配，纯函数、可测；
##   * 图案 → 图形：`_glyph()` 里全用 `draw_polygon / draw_line / draw_circle`，
##     半径 `r` 为唯一尺度，同一份代码画两次（深色放大 1.12 当描边 + 本色 0.94）。
##
## ⚠️ 所有绘制都发生在**调用方的 `_draw()` 内**（`ci` 是那个 CanvasItem）；
##    本类不许自己 queue_redraw，也不读时钟。

## 复用数字那边的标签几何 / 配色：字面留色相压饱和、细边同色相暗一档。
const DmgNumber = preload("res://scripts/dmg_number.gd")

const GLYPH_NONE := 0
const GLYPH_ICE := 1        ## 冰封 / 冻结
const GLYPH_FLAME := 2      ## 燃烧 / 灼烧
const GLYPH_POISON := 3     ## 中毒 / 剧毒
const GLYPH_BOLT := 4       ## 感电 / 雷
const GLYPH_SHIELD := 5     ## 屏障 / 护甲 / 格挡
const GLYPH_HEAL := 6       ## 治疗 / 回复 / 自我修复
const GLYPH_SWORD := 7      ## 锻造 / 精进 / 攻击 / 力量
const GLYPH_ENERGY := 8     ## 能源 / 能量 / 费用
const GLYPH_SKULL := 9      ## 击破 / 死亡 / 消灭
const GLYPH_STAR := 10      ## 眩晕 / 睡眠
const GLYPH_TAUNT := 11     ## 嘲讽

## 关键词表：**按顺序**匹配，先中先得 —— 所以特例（「超负荷死亡」）要排在泛词（「死亡」）前面。
## ⚠️ 只放**短状态名 / 短提示**能用上的词；长句里撞上「费」「火」这类单字会误配，
##    但风险很低（单字只在没有更长匹配时才轮到），而且配错也只是图案不对，不影响读数。
const RULES := [
	["冰封", GLYPH_ICE], ["冻结", GLYPH_ICE], ["冰冻", GLYPH_ICE], ["寒霜", GLYPH_ICE],
	["中毒", GLYPH_POISON], ["剧毒", GLYPH_POISON], ["毒", GLYPH_POISON],
	["燃烧", GLYPH_FLAME], ["灼烧", GLYPH_FLAME], ["烈焰", GLYPH_FLAME], ["着火", GLYPH_FLAME],
	["感电", GLYPH_BOLT], ["雷", GLYPH_BOLT], ["闪电", GLYPH_BOLT],
	["屏障", GLYPH_SHIELD], ["护甲", GLYPH_SHIELD], ["护盾", GLYPH_SHIELD], ["格挡", GLYPH_SHIELD],
	["治疗", GLYPH_HEAL], ["回复", GLYPH_HEAL], ["回血", GLYPH_HEAL],
	["自我修复", GLYPH_HEAL], ["生命", GLYPH_HEAL],
	["锻造", GLYPH_SWORD], ["精进", GLYPH_SWORD], ["攻击", GLYPH_SWORD], ["力量", GLYPH_SWORD],
	["超负荷死亡", GLYPH_SKULL], ["击破", GLYPH_SKULL], ["死亡", GLYPH_SKULL],
	["消灭", GLYPH_SKULL],
	["能源", GLYPH_ENERGY], ["能量", GLYPH_ENERGY], ["费用", GLYPH_ENERGY], ["费", GLYPH_ENERGY],
	["眩晕", GLYPH_STAR], ["睡眠", GLYPH_STAR], ["沉睡", GLYPH_STAR],
	["嘲讽", GLYPH_TAUNT],
]


static func glyph_of(text: String) -> int:
	## 关键词 → 图案。**没有匹配就返回 NONE**（不画徽章圆盘，退回纯文字胶囊）——
	## 乱配一个图案比没有图案更糟：玩家会以为它有机制含义。
	for rule: Array in RULES:
		if text.find(str(rule[0])) >= 0:
			return int(rule[1])
	return GLYPH_NONE


static func glyph_name(g: int) -> String:
	match g:
		GLYPH_ICE: return "ice"
		GLYPH_FLAME: return "flame"
		GLYPH_POISON: return "poison"
		GLYPH_BOLT: return "bolt"
		GLYPH_SHIELD: return "shield"
		GLYPH_HEAL: return "heal"
		GLYPH_SWORD: return "sword"
		GLYPH_ENERGY: return "energy"
		GLYPH_SKULL: return "skull"
		GLYPH_STAR: return "star"
		GLYPH_TAUNT: return "taunt"
		_: return "none"


static func emblem_radius(px: int) -> float:
	## 徽章圆盘半径：跟着字号走，但要**装得进胶囊内高**（内高 ≈ 字高 + 上下留白）。
	return maxf(6.0, float(maxi(7, px)) * 0.62)


static func emblem_gap(px: int) -> float:
	## 圆盘与文字之间留的气。太小会挤，太大会让胶囊变长。
	return maxf(3.0, float(maxi(7, px)) * 0.26)


static func layout(font: Font, text: String, px: int) -> Dictionary:
	## 只算尺寸、不画。出图与回归都靠它核对「胶囊装不装得下徽章」。
	var p := maxi(7, px)
	var g := glyph_of(text)
	var met := DmgNumber.label_metrics(p)
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, p)
	var h := font.get_height(p)
	var er := 0.0
	var gap := 0.0
	if g != GLYPH_NONE:
		er = emblem_radius(p)
		gap = emblem_gap(p)
	var pad_x := float(met["pad_x"])
	var pad_y := float(met["pad_y"])
	# 有徽章时左留白压到 60%：圆盘自己有弧度，再留满会显得右边空。
	var left_pad := pad_x if g == GLYPH_NONE else pad_x * 0.42
	var content_w := sz.x + (er * 2.0 + gap if g != GLYPH_NONE else 0.0)
	return {
		"glyph": g,
		"text_w": sz.x,
		"emblem_r": er,
		"gap": gap,
		"size": Vector2(content_w + left_pad + pad_x, h + pad_y * 2.0),
		"left_pad": left_pad,
		"pad_y": pad_y,
		"inner_h": h + pad_y * 2.0,
	}


static func paint(ci: CanvasItem, font: Font, center: Vector2, text: String,
		tint: Color, alpha: float, px: int) -> void:
	## 画一枚徽标。`center` 是**屏幕空间**的中心；不改变换（与 `_paint_dmg_number` 同规矩）。
	if alpha <= 0.004:
		return
	var p := maxi(7, px)
	var lay := layout(font, text, p)
	var g := int(lay["glyph"])
	var size: Vector2 = lay["size"]
	var rect := Rect2(center - size * 0.5, size)
	var rad := int(round(rect.size.y * 0.5))
	var er := float(lay["emblem_r"])
	var gap := float(lay["gap"])
	var left_pad := float(lay["left_pad"])
	var edge := DmgNumber.label_edge(tint)
	var ink := DmgNumber.label_ink(tint)

	# ⓪ 外圈微光：水面 / 木纹这类高频底图上，胶囊边会和背景咬在一起
	_plate(ci, rect.grow(2.0),
			Color(edge.r, edge.g, edge.b, DmgNumber.LABEL_GLOW_ALPHA * alpha), rad + 2)
	# ① 落地阴影（下错 2px）→ ② 深底
	_plate(ci, Rect2(rect.position + Vector2(0.0, 2.0), rect.size),
			Color(0.0, 0.0, 0.0, DmgNumber.LABEL_SHADOW_ALPHA * alpha), rad)
	# 底板渗一点自己的色相：全黑底会把「冰封」和「燃烧」压成同一个灰块，
	# 压一点点饱和度（v<0.10）就够让四种属性在余光里分开，又不至于变彩色糖果。
	var plate_tint := Color.from_hsv(tint.h, 0.40, 0.10)
	_plate(ci, rect, Color(plate_tint.r, plate_tint.g, plate_tint.b,
			DmgNumber.LABEL_PLATE_ALPHA * alpha), rad)
	# ③ 上半弧面高光
	var arc := Rect2(rect.position + Vector2(0.0, 1.0),
			Vector2(rect.size.x, rect.size.y * 0.46))
	_plate(ci, arc, Color(1.0, 1.0, 1.0, DmgNumber.LABEL_ARC_ALPHA * alpha),
			mini(rad, int(arc.size.y * 0.5)))
	# ④ 1px 色相细边
	_edge(ci, rect, Color(edge.r, edge.g, edge.b, DmgNumber.LABEL_EDGE_ALPHA * alpha), rad)

	# ⑤ 徽章圆盘 + 图案（圆盘自己带一圈细亮环，字才不会被图案压住）
	var tx := rect.position.x + left_pad
	if g != GLYPH_NONE:
		var ec := Vector2(tx + er, center.y)
		ci.draw_circle(ec, er, Color(0.0, 0.0, 0.0, 0.62 * alpha))
		ci.draw_circle(ec, er - 1.0,
				Color(Color.from_hsv(tint.h, 0.55, 0.20), 0.94 * alpha))
		ci.draw_arc(ec, er - 0.6, 0.0, TAU, 22,
				Color(edge.r, edge.g, edge.b, 0.95 * alpha), 1.4, true)
		# 图案分两遍：放大 12% 的深色当描边，再压 94% 的本色 —— 小尺寸也立得住
		var dark := Color(0.03, 0.025, 0.02, 0.92 * alpha)
		_glyph(ci, g, ec, er * 0.86 * 1.06, dark)
		_glyph(ci, g, ec, er * 0.86 * 0.98, Color(ink.r, ink.g, ink.b, alpha))
		tx += er * 2.0 + gap

	# ⑥ 文字：厚度 → 描边 → 字面 → 顶高光（四层叠成「印上去」的立体字）
	var pos := Vector2(tx, center.y + float(p) * 0.36)
	# 字背后的同色相光晕：GBF 那种「字在发光」的底子。用一次超粗描边做，
	# 比画一团圆形辉光省，也不会在方字上漏出圆斑。
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, p,
			int(round(float(p) * 0.32)), Color(tint.r, tint.g, tint.b, 0.30 * alpha))
	ci.draw_string(font, pos + Vector2(0.0, 1.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, p,
			Color(edge.r, edge.g, edge.b, 0.95 * alpha))
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, p,
			int(DmgNumber.label_metrics(p)["outline"]), Color(0.03, 0.025, 0.02, 0.9 * alpha))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, p,
			Color(ink.r, ink.g, ink.b, alpha))
	ci.draw_string(font, pos - Vector2(0.0, 1.2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, p,
			Color(1.0, 1.0, 1.0, 0.34 * alpha))

	# ⑦ 点缀：冰晶 / 火星 / 毒泡 —— 「文字上带点冰」就是这一层
	_accent(ci, g, rect, tx, Color(ink.r, ink.g, ink.b, alpha), alpha, p)


# ------------------------------------------------------------------ 底板
## 底板 / 细边共用的两个 StyleBoxFlat。徽标一帧要画 3~4 层，逐层 new 属于白给的分配
## （同 `_dmg_plate_box` 的教训）。静态实例只改颜色与圆角。
static var _plate_box: StyleBoxFlat = null
static var _edge_box: StyleBoxFlat = null


static func _plate(ci: CanvasItem, rect: Rect2, col: Color, rad: int) -> void:
	if _plate_box == null:
		_plate_box = StyleBoxFlat.new()
		_plate_box.anti_aliasing = true
	_plate_box.bg_color = col
	_plate_box.set_corner_radius_all(rad)
	ci.draw_style_box(_plate_box, rect)


static func _edge(ci: CanvasItem, rect: Rect2, col: Color, rad: int) -> void:
	if _edge_box == null:
		_edge_box = StyleBoxFlat.new()
		_edge_box.anti_aliasing = true
		_edge_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		_edge_box.set_border_width_all(1)
	_edge_box.border_color = col
	_edge_box.set_corner_radius_all(rad)
	ci.draw_style_box(_edge_box, rect)


# ------------------------------------------------------------------ 图案
static func _poly(ci: CanvasItem, c: Vector2, r: float, pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for pt: Array in pts:
		out.append(c + Vector2(float(pt[0]), float(pt[1])) * r)
	ci.draw_colored_polygon(out, col)


static func _glyph(ci: CanvasItem, g: int, c: Vector2, r: float, col: Color) -> void:
	## 所有图案都以 `r` 为「半径」，坐标系相对中心 `c`。y 向下为正。
	match g:
		GLYPH_ICE:
			# 六枝雪晶：**六条独立枝**从内圈射出去 + 每枝一对小刺。
			# ⚠️ 别画成三条线穿心 —— 那样中心糊成一块，一眼看是齿轮不是雪。
			var w := maxf(1.0, r * 0.14)
			var inner := r * 0.20
			for i in 6:
				var a := float(i) * PI / 3.0
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				ci.draw_line(c + d * inner, c + d * r * 0.96, col, w, true)
				if r < 7.5:
					continue    # 小尺寸：光秃秃六枝最清楚，加刺必糊
				var base := c + d * r * 0.62
				ci.draw_line(base, base + (d * 0.55 + n * 0.8) * r * 0.30, col, w, true)
				ci.draw_line(base, base + (d * 0.55 - n * 0.8) * r * 0.30, col, w, true)
			ci.draw_circle(c, maxf(0.9, r * 0.13), col)
		GLYPH_FLAME:
			_poly(ci, c, r, [[0.0, -1.0], [0.34, -0.42], [0.56, 0.06], [0.44, 0.56],
					[0.0, 0.92], [-0.44, 0.56], [-0.56, 0.06], [-0.34, -0.42]], col)
			# 内焰：往下压一点、缩一圈，做出「焰心更亮」的层次
			_poly(ci, c + Vector2(0, r * 0.30), r * 0.46,
					[[0.0, -1.0], [0.5, -0.1], [0.34, 0.7], [0.0, 1.0],
					[-0.34, 0.7], [-0.5, -0.1]], Color(col.r, col.g, col.b, col.a * 0.55))
		GLYPH_POISON:
			# 一滴毒液 + 一颗浮泡
			_poly(ci, c, r, [[0.0, -1.0], [0.42, -0.12], [0.56, 0.34], [0.30, 0.80],
					[0.0, 0.92], [-0.30, 0.80], [-0.56, 0.34], [-0.42, -0.12]], col)
			ci.draw_circle(c + Vector2(-r * 0.22, r * 0.30), r * 0.20,
					Color(col.r, col.g, col.b, col.a * 0.55))
		GLYPH_BOLT:
			_poly(ci, c, r, [[0.24, -1.0], [-0.52, 0.06], [-0.08, 0.06], [0.10, 0.06],
					[-0.18, 1.0], [0.56, -0.10], [0.10, -0.10], [0.02, -0.10]], col)
		GLYPH_SHIELD:
			_poly(ci, c, r, [[-0.72, -0.82], [0.72, -0.82], [0.72, 0.06], [0.0, 0.94],
					[-0.72, 0.06]], col)
			_poly(ci, c + Vector2(0, -r * 0.04), r * 0.62,
					[[-0.72, -0.82], [0.72, -0.82], [0.72, 0.06], [0.0, 0.94],
					[-0.72, 0.06]], Color(col.r, col.g, col.b, col.a * 0.30))
		GLYPH_HEAL:
			var t := maxf(1.4, r * 0.30)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.78, -t * 0.5), Vector2(r * 1.56, t)), col)
			ci.draw_rect(Rect2(c + Vector2(-t * 0.5, -r * 0.78), Vector2(t, r * 1.56)), col)
		GLYPH_SWORD:
			_poly(ci, c, r, [[0.0, -1.0], [0.15, -0.82], [0.15, 0.28], [-0.15, 0.28],
					[-0.15, -0.82]], col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.62, r * 0.24),
					Vector2(r * 1.24, maxf(1.2, r * 0.16))), col)
			ci.draw_circle(c + Vector2(0.0, r * 0.58), maxf(1.0, r * 0.16), col)
		GLYPH_ENERGY:
			_poly(ci, c, r, [[0.0, -0.96], [0.62, 0.0], [0.0, 0.96], [-0.62, 0.0]], col)
			_poly(ci, c, r * 0.52, [[0.0, -0.96], [0.62, 0.0], [0.0, 0.96], [-0.62, 0.0]],
					Color(0.06, 0.05, 0.04, col.a))
		GLYPH_SKULL:
			ci.draw_circle(c + Vector2(0.0, -r * 0.12), r * 0.62, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.34, r * 0.34),
					Vector2(r * 0.68, r * 0.34)), col)
			var eye := Color(0.05, 0.04, 0.03, col.a)
			ci.draw_circle(c + Vector2(-r * 0.24, -r * 0.18), r * 0.17, eye)
			ci.draw_circle(c + Vector2(r * 0.24, -r * 0.18), r * 0.17, eye)
		GLYPH_STAR:
			_poly(ci, c, r, [[0.0, -1.0], [0.15, -0.15], [1.0, 0.0], [0.15, 0.15],
					[0.0, 1.0], [-0.15, 0.15], [-1.0, 0.0], [-0.15, -0.15]], col)
		GLYPH_TAUNT:
			# 感叹号：两根尖刺在小尺寸上认不出是「挑衅」，感叹号一眼就是
			var bw := maxf(1.6, r * 0.34)
			_poly(ci, c + Vector2(0.0, -r * 0.18), r * 0.62,
					[[bw / r, -0.9], [bw / r, 0.55], [-bw / r, 0.55], [-bw / r, -0.9]], col)
			ci.draw_circle(c + Vector2(0.0, r * 0.72), maxf(1.0, bw * 0.62), col)
		_:
			pass


# ------------------------------------------------------------------ 点缀
static func _accent(ci: CanvasItem, g: int, rect: Rect2, text_x: float,
		col: Color, alpha: float, px: int) -> void:
	## 只给「有画面感」的几种加点缀（冰晶 / 火星 / 毒泡 / 电花）。
	## 点缀一律**小、淡、压在字的上沿**，作用是「这行字有属性」，不是第二张图。
	if g == GLYPH_NONE:
		return
	var a := alpha * 0.72
	var s := maxf(1.6, float(px) * 0.16)
	var top := rect.position.y + rect.size.y * 0.26
	match g:
		GLYPH_ICE:
			# 三片碎冰：上沿两片、下沿一片，方向各自不同
			_shard(ci, Vector2(rect.end.x - s * 2.2, top), s, col, a, -0.5)
			_shard(ci, Vector2(rect.end.x - s * 4.4, top - s * 1.4), s * 0.7, col, a * 0.8, 0.7)
			_shard(ci, Vector2(text_x - s * 0.8, rect.end.y - s * 1.2), s * 0.8, col, a * 0.7, 2.2)
		GLYPH_FLAME:
			ci.draw_circle(Vector2(rect.end.x - s * 2.0, top), s * 0.42, Color(col.r, col.g, col.b, a))
			ci.draw_circle(Vector2(rect.end.x - s * 3.6, top - s * 1.2), s * 0.30,
					Color(col.r, col.g, col.b, a * 0.8))
		GLYPH_POISON:
			ci.draw_circle(Vector2(rect.end.x - s * 2.0, top), s * 0.40, Color(col.r, col.g, col.b, a * 0.9))
			ci.draw_arc(Vector2(rect.end.x - s * 2.0, top), s * 0.72, 0.0, TAU, 14,
					Color(col.r, col.g, col.b, a * 0.55), 1.0, true)
		GLYPH_BOLT:
			ci.draw_line(Vector2(rect.end.x - s * 1.4, top - s),
					Vector2(rect.end.x - s * 2.4, top + s * 0.6),
					Color(col.r, col.g, col.b, a), 1.2, true)
			ci.draw_line(Vector2(rect.end.x - s * 3.2, top - s * 0.4),
					Vector2(rect.end.x - s * 4.2, top + s * 1.2),
					Color(col.r, col.g, col.b, a * 0.7), 1.0, true)
		_:
			pass


static func _shard(ci: CanvasItem, c: Vector2, s: float, col: Color, a: float, rot: float) -> void:
	## 一枚三棱碎冰：尖端朝上，按 `rot` 旋转。
	var pts := PackedVector2Array()
	for v: Array in [[0.0, -1.3], [0.62, 0.55], [-0.62, 0.55]]:
		var p := Vector2(float(v[0]), float(v[1])) * s
		var cs := cos(rot)
		var sn := sin(rot)
		pts.append(c + Vector2(p.x * cs - p.y * sn, p.x * sn + p.y * cs))
	ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, a))
