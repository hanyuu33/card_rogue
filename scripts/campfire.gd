extends Control
## 篝火简笔（事件界面的内置装饰层）：暖色光晕 + 火焰 + 柴堆。
## 所有事件类别默认都会显示；若该事件在 assets/ui/ 提供了 event_<事件>.png，
## 则由 event_scene 隐藏本节点，改用自定义插图。
## 独立子节点绘制，避免被背景 ColorRect 盖住。

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()   # 火光摇曳需要逐帧重绘


func _draw() -> void:
	var c := Vector2(size.x / 2.0, 236.0)
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
