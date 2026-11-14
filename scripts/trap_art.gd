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
