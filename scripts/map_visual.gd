extends RefCounted
## Shared map material and fog geometry. Room visibility is decided by RunState.
const UiAssets = preload("res://scripts/ui_assets.gd")
const PanelMaterial = preload("res://scripts/battle_hud_material.gd")

static func fog_rect(room: Rect2) -> Rect2:
	return Rect2(room.get_center() - room.size * 0.30, room.size * 0.60)

static func draw_fog(canvas: CanvasItem, room: Rect2) -> void:
	var tex := UiAssets.map_fog()
	var box := fog_rect(room)
	if tex != null:
		canvas.draw_texture_rect(tex, box, false)
	else:
		canvas.draw_circle(box.get_center(), box.size.x * 0.42, Color("c5d7d4"))

static func draw_room(canvas: CanvasItem, room: Rect2, known: bool, visited: bool) -> void:
	var box := room.grow(-3)
	if known:
		PanelMaterial.draw(canvas, box)
		if visited:
			canvas.draw_rect(box.grow(-10), Color(0.36, 0.49, 0.31, 0.15))
	else:
		canvas.draw_rect(box.grow(-3), Color("344d37"))
		PanelMaterial.draw_frame(canvas, box)
