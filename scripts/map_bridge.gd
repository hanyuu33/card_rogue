extends RefCounted
## 地图「通路」的唯一绘制口（R130）。**冒险地图页与战斗内地图总览共用**。
##
## 通路 = **两格之间的墙上盖一枚小桥图标**：
##   * 左右连通 → 桥的**侧视图** `map_bridge_h`（桥身横跨屏幕）
##   * 上下连通 → 桥的**俯视图** `map_bridge_v`（俯视桥面，桥身在屏幕上竖着）
##
## ⚠️ 为什么不是「画一块色块 / 门洞」来示意连接：
##    R130 的第一版就是横跨共用墙的一条宽色块 + 暗描边。出图后发现
##    ①一块块硬边色块压在格子上**量感过重**；②鹰哨全揭示时一堆色块彼此不相连，
##    读起来是「散落的按钮」而不是「通道」。
##    —— 通路必须是**一个能被认出来的物件**，才既轻又清楚。这就是「小桥」的由来。
##
## 三种语义（与视野规则一致，判定口 = `kind_for`）：
##   LIT    当前房 → 可走的相邻房：亮青（会呼吸）
##   DONE   走过的房 → 已知的相邻房：暖白
##   UNSEEN 只在鹰哨下出现的「已知但没走过」：灰蓝、更小

const UiTheme = preload("res://scripts/ui_theme.gd")
const UiAssets = preload("res://scripts/ui_assets.gd")

const LIT := 0
const DONE := 1
const UNSEEN := 2

## ⚠️ 素材长宽比与这个盒子越接近越好：`draw_bridge` 用 `fit_rect` **等比**缩放，
##   素材太瘦就会被「fit」成一根线（俯视图第一版 1:6.3 就是这么废掉的，
##   后来重生成成「短而宽」的 1:2.3 才落地）。
const ALONG := 0.72        ## 沿通行方向的长度（占格边长）：两端会掖到房间图标底下
const CROSS := 0.26        ## 垂直于通行方向的宽度（占格边长）
const SHRINK_UNSEEN := 0.82
const FALLBACK_W := 0.34   ## 缺图兜底：横条沿墙的宽度（占格边长）


static func kind_for(a_seen: bool, b_seen: bool, lit: bool) -> int:
	## 通路语义的唯一判定口。场景只负责把三个 bool 算出来：
	##   lit           = 一端是当前房、另一端是它真正能走过去的房（两个方向都算）
	##   a_seen/b_seen = 两端各自「走过没有」
	if lit:
		return LIT
	if a_seen or b_seen:
		return DONE
	return UNSEEN


static func is_vertical(ctr_a: Vector2, ctr_b: Vector2) -> bool:
	## 上下相邻（含斜向的理论情况）→ 用俯视图；左右相邻 → 用侧视图。
	return absf(ctr_b.y - ctr_a.y) > absf(ctr_b.x - ctr_a.x)


static func box_of(ctr_a: Vector2, ctr_b: Vector2, kind: int, cell: float) -> Rect2:
	## 桥要画在哪个矩形里：**中心 = 两格中心的中点（也就是那面墙的中点）**，
	## 长边沿通行方向。UNSEEN 档整体缩小一档（「小一号」比「换个颜色」更一眼可辨）。
	var k := SHRINK_UNSEEN if kind == UNSEEN else 1.0
	var along := cell * ALONG * k
	var cross := cell * CROSS * k
	var sz := Vector2(cross, along) if is_vertical(ctr_a, ctr_b) else Vector2(along, cross)
	var mid := (ctr_a + ctr_b) * 0.5
	return Rect2(mid - sz * 0.5, sz)


static func tint_of(kind: int) -> Color:
	match kind:
		LIT:
			return UiTheme.MAP_BRIDGE_LIT
		UNSEEN:
			return UiTheme.MAP_BRIDGE_UNSEEN
	return UiTheme.MAP_BRIDGE_DONE


static func draw_bridge(ci: CanvasItem, ctr_a: Vector2, ctr_b: Vector2, kind: int,
		cell: float, pulse: float = 0.0) -> void:
	## 在两格之间的墙上盖一枚小桥。画在**格子底之上、房间图标之下** ——
	## 两端因此会被图标盖住，可见部分正好是「两间房之间那一段」。
	## `pulse`（0..1）只作用于 LIT：当前房能走的出口会轻微呼吸。
	if ctr_a.is_equal_approx(ctr_b):
		return
	var vertical := is_vertical(ctr_a, ctr_b)
	var box := box_of(ctr_a, ctr_b, kind, cell)
	var col := tint_of(kind)
	if kind == LIT:
		col = col.lerp(Color.WHITE, 0.35 * clampf(pulse, 0.0, 1.0))
	var tex := UiAssets.bridge_icon(vertical)
	if tex == null:
		_fallback(ci, box, vertical, kind, col)
		return
	# 图本身是浅色的（便于染色），自带深色线稿描边 → 不需要再垫暗底。
	# ⚠️ 用 `fit_rect` **等比**缩放，绝不拉伸：拉伸会把侧视图的拱拉高成「拱门」、
	#    把俯视图的栏杆拉糊。素材比盒子瘦时宁可小一点，也不要变形。
	ci.draw_texture_rect(tex, CardFace.fit_rect(tex.get_size(), box), false, col)


static func _fallback(ci: CanvasItem, box: Rect2, vertical: bool, kind: int,
		col: Color) -> void:
	## 缺图兜底：一小段带暗描边的横条（规范要求「缺图不空白也不报错」）。
	var perp := Vector2(1, 0) if vertical else Vector2(0, 1)
	var w := box.size.y * FALLBACK_W if vertical else box.size.x * FALLBACK_W
	var half := perp * (box.size.x * 0.5 if vertical else box.size.y * 0.5)
	var mid := box.get_center()
	ci.draw_line(mid - half, mid + half, UiTheme.MAP_BRIDGE_DARK, w + 4.0, true)
	ci.draw_line(mid - half, mid + half, col, w, true)
