extends RefCounted
## Presentation only. Battle owns the rolled energy value, max energy, status and feedback.
const UiTheme = preload("res://scripts/ui_theme.gd")
const UiAssets = preload("res://scripts/ui_assets.gd")

static func value_layout(font: Font, current: int, maximum: int, rect: Rect2) -> Dictionary:
	var main := str(current)
	var suffix := "/%d" % maximum
	var fs := 30
	var small := 15
	var width := 0.0
	while fs >= 14:
		width = font.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3 + font.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		if width <= rect.size.x - 14:
			break
		fs -= 1
	return {"font_size": fs, "width": width, "x": rect.get_center().x - width / 2.0}

static func draw(canvas: CanvasItem, font: Font, current: int, maximum: int, rect: Rect2, charge: int, dodge: bool) -> void:
	var tex: Texture2D = UiAssets.get_tex("adventure_shared/battle_mana_meter")
	if tex != null:
		canvas.draw_texture_rect(tex, rect, false)
	else:
		UiTheme.draw_info_card(canvas, rect)
	var layout := value_layout(font, current, maximum, rect)
	var fs: int = layout["font_size"]
	var x: float = layout["x"]
	var baseline := rect.position.y + 78.0
	var ink := UiTheme.PAGE_INK
	if current <= 0:
		ink = UiTheme.STAT_HEALTH
	elif current > maximum:
		ink = UiTheme.SIDE_SELF_TEXT
	var main := str(current)
	canvas.draw_string(font, Vector2(x, baseline), main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	x += font.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3
	canvas.draw_string(font, Vector2(x, baseline), "/%d" % maximum, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.PAGE_MUTED)
	var available := GameI18n.ui("battle", "BATTLE_ENERGY_AVAILABLE", "可用费用")
	var available_fs := 12
	while available_fs > 8 and font.get_string_size(available, HORIZONTAL_ALIGNMENT_LEFT, -1, available_fs).x > rect.size.x - 8:
		available_fs -= 1
	canvas.draw_string(font, rect.position + Vector2(0, 96), available, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, available_fs, UiTheme.PAGE_INK)
	if charge > 0:
		var text := GameI18n.ui("battle", "BATTLE_ENERGY_CHARGE", "蓄力%d · 技能×%d") % [charge, charge + 1]
		var status_fs := 10
		while status_fs > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, status_fs).x > rect.size.x - 12:
			status_fs -= 1
		canvas.draw_string(font, rect.position + Vector2(0, 111), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, status_fs, UiTheme.PAGE_INK)
	if dodge:
		canvas.draw_string(font, rect.position + Vector2(0, 124), GameI18n.ui("battle", "BATTLE_ENERGY_DODGE", "闪躲：友军嘲讽"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, UiTheme.PAGE_INK)
