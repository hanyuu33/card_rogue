extends SceneTree
func _initialize() -> void:
	var rect := Rect2(Vector2(0, 0), Vector2(76.6, 92.4))
	print("[DBG] radius=", CardFace.badge_radius(rect))
	print("[DBG] slot=", CardFace.badge_slot_rect(true, rect))
	print("[DBG] center=", CardFace.affix_badge_center(rect))
	quit()
