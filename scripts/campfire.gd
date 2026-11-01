extends Control
## 篝火简笔（事件界面的内置装饰层）：暖色光晕 + 火焰 + 柴堆。
## R478：**只在休息处（kind == "rest"）显示**。此前 24 种事件全都烧一堆篝火，
## 「卡牌商人」「占卜」里也有火，一眼就是没做完的占位；篝火的本义是「可以休息」。
## 其余事件改由 event_scene `_draw_fallback_bg` 的类别光晕 + 纹章水印兜底。
## 若某事件在 assets/ui/ 提供了 event_<事件>.png，仍由 event_scene 隐藏本节点。

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()   # 火光摇曳需要逐帧重绘


func _draw() -> void:
	var c := Vector2(size.x / 2.0, 168.0)
	var flick := 1.0 + 0.08 * sin(_t * 6.0)
	draw_circle(c + Vector2(0, 10), 90.0 * flick, Color(1.0, 0.72, 0.35, 0.18))
	draw_circle(c + Vector2(0, 10), 56.0 * flick, Color(1.0, 0.6, 0.25, 0.22))
	# 柴堆
	var brown := Color("7a4a24")
	draw_line(c + Vector2(-42, 46), c + Vector2(42, 30), brown, 7.0)
	draw_line(c + Vector2(-42, 30), c + Vector2(42, 46), brown, 7.0)
	# 火焰（两层三角）
	draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -58 * flick), c + Vector2(-26, 34), c + Vector2(26, 34)]),
			Color("e8722a"))
	draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -26 * flick), c + Vector2(-14, 34), c + Vector2(14, 34)]),
			Color("ffc23a"))
